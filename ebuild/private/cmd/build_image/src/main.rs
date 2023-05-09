// Copyright 2022 The ChromiumOS Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use anyhow::Result;
use binarypackage::BinaryPackage;
use clap::Parser;
use cliutil::cli_main;
use makechroot::BindMount;
use mountsdk::MountedSDK;
use std::{
    path::{Path, PathBuf},
    process::ExitCode,
};

const MAIN_SCRIPT: &str = "/mnt/host/bazel-build/build_image.sh";

#[derive(Parser, Debug)]
#[clap()]
pub struct Cli {
    #[command(flatten)]
    mountsdk_config: mountsdk::ConfigArgs,

    /// Name of board
    #[arg(long, required = true)]
    board: String,

    /// Output file path.
    #[arg(long, required = true)]
    output: PathBuf,

    /// Image to build.
    #[arg(long, required = true)]
    image_to_build: String,

    /// The name of the image file generated by build_image script.
    #[arg(long, required = true)]
    image_file_name: String,

    /// File paths to binary packages to be installed on the output image.
    #[arg(long)]
    target_package: Vec<PathBuf>,

    /// File paths to host binary packages to be made available to the
    /// build_image script.
    #[arg(long)]
    host_package: Vec<PathBuf>,

    #[arg(long)]
    override_base_package: Vec<String>,
}

fn do_main() -> Result<()> {
    let args = Cli::parse();
    let r = runfiles::Runfiles::create()?;

    let mut cfg = mountsdk::Config::try_from(args.mountsdk_config)?;
    cfg.privileged = true;

    cfg.bind_mounts.push(BindMount {
        source: r
            .rlocation("cros/bazel/ebuild/private/cmd/build_image/container_files/edb_chromeos"),
        mount_path: Path::new("/build")
            .join(&args.board)
            .join("var/cache/edb/chromeos"),
        rw: false,
    });
    cfg.bind_mounts.push(BindMount {
        source: r.rlocation(
            "cros/bazel/ebuild/private/cmd/build_image/container_files/package.accept_keywords",
        ),
        mount_path: Path::new("/build")
            .join(&args.board)
            .join("etc/portage/package.accept_keywords/accept_all"),
        rw: false,
    });
    cfg.bind_mounts.push(BindMount {
        source: r.rlocation(
            "cros/bazel/ebuild/private/cmd/build_image/container_files/package.provided",
        ),
        mount_path: Path::new("/build")
            .join(&args.board)
            .join("etc/portage/profile/package.provided"),
        rw: false,
    });
    cfg.bind_mounts.push(BindMount {
        source: r
            .rlocation("cros/bazel/ebuild/private/cmd/build_image/container_files/build_image.sh"),
        mount_path: PathBuf::from(MAIN_SCRIPT),
        rw: false,
    });

    for path in args.target_package {
        let package = BinaryPackage::open(&path)?;
        let mount_path = Path::new("/build")
            .join(&args.board)
            .join("packages")
            .join(format!("{}.tbz2", package.category_pf()));
        cfg.bind_mounts.push(BindMount {
            mount_path,
            source: path,
            rw: false,
        });
    }

    for path in args.host_package {
        let package = BinaryPackage::open(&path)?;
        let mount_path =
            Path::new("/var/lib/portage/pkgs").join(format!("{}.tbz2", package.category_pf()));
        cfg.bind_mounts.push(BindMount {
            mount_path,
            source: path,
            rw: false,
        });
    }

    cfg.envs.insert(
        "BASE_PACKAGE".to_owned(),
        args.override_base_package.join(" "),
    );

    let mut sdk = MountedSDK::new(cfg, Some(&args.board))?;
    sdk.run_cmd(&[
        MAIN_SCRIPT,
        &format!("--board={}", &args.board),
        &args.image_to_build,
        // TODO: add unparsed command-line args.
    ])?;

    let path = Path::new("mnt/host/source/src/build/images")
        .join(&args.board)
        .join("latest")
        .join(args.image_file_name + ".bin");
    std::fs::copy(sdk.diff_dir().join(path), args.output)?;

    Ok(())
}

fn main() -> ExitCode {
    cli_main(do_main)
}
