// Copyright 2022 The ChromiumOS Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use anyhow::{anyhow, bail, ensure, Context, Result};
use clap::{command, Parser};
use cliutil::cli_main;
use container::{enter_mount_namespace, BindMount, CommonArgs, ContainerSettings};
use std::{
    collections::{HashMap, HashSet},
    fs::File,
    io::BufReader,
    os::unix::process::ExitStatusExt,
    path::{Path, PathBuf},
    process::ExitCode,
    str::FromStr,
};

const EBUILD_EXT: &str = ".ebuild";
const MAIN_SCRIPT: &str = "/mnt/host/.build_package/build_package.sh";
const JOB_SERVER: &str = "/mnt/host/.build_package/jobserver";

#[derive(Parser, Debug)]
#[clap(author, version, about, long_about=None)]
struct Cli {
    #[command(flatten)]
    common: CommonArgs,

    /// Name of board
    #[arg(long)]
    board: Option<String>,

    #[arg(long, required = true)]
    ebuild: EbuildMetadata,

    #[arg(long)]
    file: Vec<BindMount>,

    #[arg(long)]
    distfile: Vec<BindMount>,

    #[arg(long, help = "Git trees used by CROS_WORKON_TREE")]
    git_tree: Vec<PathBuf>,

    #[arg(
        long,
        help = "USE flags to set when building. \
                This must be the full set of all possible USE flags. i.e., IUSE_EFFECTIVE",
        value_delimiter = ','
    )]
    use_flags: Vec<String>,

    #[arg(
        long,
        help = "Points to a named pipe that is used for the GNU Make jobserver."
    )]
    jobserver: Option<PathBuf>,

    #[arg(long)]
    output: Option<PathBuf>,

    #[arg(
        long,
        help = "<inside path>=<outside path>: Copies the outside file into the sysroot"
    )]
    sysroot_file: Vec<SysrootFileSpec>,

    #[arg(long, help = "Allows network access during build")]
    allow_network_access: bool,

    #[arg(long, help = "Goma-related info encoded as JSON.")]
    goma_info: PathBuf,

    #[arg(long)]
    test: bool,
}

#[derive(Debug, Clone)]
struct SysrootFileSpec {
    sysroot_path: PathBuf,
    src_path: PathBuf,
}

impl FromStr for SysrootFileSpec {
    type Err = anyhow::Error;
    fn from_str(spec: &str) -> Result<Self> {
        let (sysroot_path, src_path) = cliutil::split_key_value(spec)?;
        let sysroot_path = PathBuf::from(sysroot_path);
        if !sysroot_path.is_absolute() {
            bail!(
                "Invalid sysroot spec: {:?}, {:?} must be absolute",
                spec,
                sysroot_path
            )
        }
        Ok(Self {
            sysroot_path,
            src_path: PathBuf::from(src_path),
        })
    }
}

impl SysrootFileSpec {
    pub fn install(&self, sysroot: &Path) -> Result<()> {
        // TODO: Maybe we can hard link or bindmount the files to save the copy cost?
        let dest = sysroot.join(&self.sysroot_path);
        let dest_dir = dest
            .parent()
            .with_context(|| format!("{dest:?} must have a parent"))?;
        std::fs::create_dir_all(dest_dir)?;
        std::fs::copy(&self.src_path, dest)?;
        Ok(())
    }
}

#[derive(Debug, Clone)]
struct EbuildMetadata {
    source: PathBuf,
    mount_path: PathBuf,
    category: String,
    package_name: String,
    file_name: String,
}

impl FromStr for EbuildMetadata {
    type Err = anyhow::Error;

    fn from_str(spec: &str) -> Result<Self> {
        let (path, source) = cliutil::split_key_value(spec)?;
        // We expect path to be in the following form:
        // <category>/<packageName>/<packageName>-<version>.ebuild
        // i.e., third_party/chromiumos-overlay/app-accessibility/brltty/brltty-6.3-r6.ebuild
        let parts: Vec<_> = path.split('/').collect();
        if parts.len() < 3 {
            bail!("unable to parse ebuild path: {:?}", path)
        }

        Ok(Self {
            source: source.into(),
            mount_path: path.into(),
            category: parts[parts.len() - 3].into(),
            package_name: parts[parts.len() - 2].into(),
            file_name: parts[parts.len() - 1].into(),
        })
    }
}

/// Writes a package.use for the specific package that sets the specified USE flags.
/// If there are no flags, nothing is written.
fn write_use_flags(
    sysroot: &Path,
    package: &EbuildMetadata,
    use_flags: &Vec<String>,
) -> Result<()> {
    if use_flags.is_empty() {
        return Ok(());
    }

    let profile_path = sysroot.join("etc").join("portage").join("profile");
    std::fs::create_dir_all(&profile_path)?;

    let package_use_path = profile_path.join("package.use");

    let content = format!(
        "{}/{} {}",
        package.category,
        package.package_name,
        use_flags.join(" ")
    );

    std::fs::write(&package_use_path, content)
        .with_context(|| format!("Error creating {package_use_path:?}"))?;

    Ok(())
}

#[derive(serde::Deserialize)]
struct GomaInfo {
    use_goma: bool,
    envs: HashMap<String, String>,
    luci_context: Option<PathBuf>,
    oauth2_config_file: Option<PathBuf>,
}

fn do_main() -> Result<()> {
    let args = Cli::try_parse()?;

    let mut settings = ContainerSettings::new();
    settings.apply_common_args(&args.common)?;

    let runfiles = runfiles::Runfiles::create()?;

    settings.push_bind_mount(BindMount {
        source: runfiles.rlocation("cros/bazel/portage/bin/build_package/build_package.sh"),
        mount_path: PathBuf::from(MAIN_SCRIPT),
        rw: false,
    });

    settings.push_bind_mount(BindMount {
        source: args.ebuild.source.clone(),
        mount_path: args.ebuild.mount_path.clone(),
        rw: false,
    });

    let ebuild_mount_dir = args.ebuild.mount_path.parent().unwrap();

    for mount in args.file {
        settings.push_bind_mount(BindMount {
            source: mount.source,
            mount_path: ebuild_mount_dir.join(mount.mount_path),
            rw: false,
        })
    }

    for mount in args.distfile {
        settings.push_bind_mount(BindMount {
            source: mount.source,
            mount_path: PathBuf::from("/var/cache/distfiles").join(mount.mount_path),
            rw: false,
        })
    }

    let mut seen_git_trees = HashSet::with_capacity(args.git_tree.len());

    for file in &args.git_tree {
        // Either <SHA> or <SHA>.tar.xxx
        let tree_file = file.file_name();

        if !seen_git_trees.insert(tree_file) {
            bail!("Duplicate git tree {:?} specified.", tree_file);
        }

        settings.push_bind_mount(BindMount {
            source: file.to_path_buf(),
            mount_path: PathBuf::from("/var/cache/trees")
                .join(file.file_name().expect("path to contain file name")),
            rw: false,
        })
    }

    settings.set_allow_network_access(args.allow_network_access);

    let (portage_tmp_dir, portage_pkg_dir) = match &args.board {
        Some(board) => {
            let root_dir = Path::new("/build").join(board);
            (root_dir.join("tmp/portage"), root_dir.join("packages"))
        }
        None => (
            PathBuf::from("/var/tmp/portage"),
            PathBuf::from("/var/lib/portage/pkgs"),
        ),
    };

    let mut envs = if args.ebuild.category == "chromeos-base"
        && args.ebuild.package_name == "chromeos-chrome"
    {
        let goma_info: GomaInfo =
            serde_json::from_reader(BufReader::new(File::open(args.goma_info)?))?;
        if goma_info.use_goma {
            // TODO(b/300218625): Also set GLOG_log_dir to support uploading build logs.
            let mut goma_envs = vec![
                ("USE_GOMA".to_string(), "true".to_string()),
                ("GOMA_TMP_DIR".to_string(), "/tmp/goma".to_string()),
            ];
            settings.push_bind_mount(BindMount {
                source: runfiles.rlocation("files/goma-chromeos-modified-for-alchemy.tgz"),
                mount_path: PathBuf::from("/mnt/host/goma.tgz"),
                rw: false,
            });

            for (key, value) in goma_info.envs {
                goma_envs.push((key, value));
            }

            if let Some(oauth2_config_file) = goma_info.oauth2_config_file {
                settings.push_bind_mount(BindMount {
                    source: oauth2_config_file.clone(),
                    mount_path: oauth2_config_file.clone(),
                    rw: false,
                });
                goma_envs.push((
                    "GOMA_OAUTH2_CONFIG_FILE".to_string(),
                    oauth2_config_file.to_string_lossy().to_string(),
                ));
            }

            if let Some(luci_context) = goma_info.luci_context {
                settings.push_bind_mount(BindMount {
                    source: luci_context.clone(),
                    mount_path: luci_context.clone(),
                    rw: false,
                });
                goma_envs.push((
                    "LUCI_CONTEXT".to_string(),
                    luci_context.to_string_lossy().to_string(),
                ));
            }

            goma_envs
        } else {
            Vec::new()
        }
    } else {
        Vec::new()
    };

    if let Some(jobserver) = args.jobserver {
        // TODO(b/303061227): Should we check if we can open the FIFO?

        settings.push_bind_mount(BindMount {
            source: jobserver,
            mount_path: PathBuf::from(JOB_SERVER),
            rw: false,
        });

        envs.push((
            "MAKEFLAGS".to_string(),
            format!("--jobserver-auth=fifo:{}", JOB_SERVER),
        ));
    }

    let mut container = settings.prepare()?;

    let root_dir = container.root_dir().to_owned();

    // Ensure PORTAGE_TMPDIR exists
    std::fs::create_dir_all(root_dir.join(portage_tmp_dir.strip_prefix("/")?))?;

    let out_dir = root_dir.join(portage_pkg_dir.strip_prefix("/")?);
    std::fs::create_dir_all(out_dir)?;

    let sysroot = match &args.board {
        Some(board) => root_dir.join("build").join(board),
        None => root_dir,
    };
    for spec in args.sysroot_file {
        spec.install(&sysroot)?;
    }

    write_use_flags(&sysroot, &args.ebuild, &args.use_flags)?;

    let mut command = container.command(MAIN_SCRIPT);
    command
        .arg("ebuild")
        .arg("--skip-manifest")
        .arg(args.ebuild.mount_path)
        .arg("package")
        .envs(envs);
    if args.test {
        command.arg("test");
    }
    if let Some(board) = args.board {
        command.env("BOARD", board);
    }

    let status = command.status()?;
    ensure!(
        status.success(),
        "Command failed: status={:?}, code={:?}, signal={:?}",
        status,
        status.code(),
        status.signal()
    );

    let binary_out_path = portage_pkg_dir.join(args.ebuild.category).join(format!(
        "{}.tbz2",
        args.ebuild
            .file_name
            .strip_suffix(EBUILD_EXT)
            .with_context(|| anyhow!("Ebuild file must end with .ebuild"))?
    ));

    if let Some(output) = args.output {
        std::fs::copy(
            container
                .root_dir()
                .join(binary_out_path.strip_prefix("/")?),
            output,
        )
        .with_context(|| format!("{binary_out_path:?} wasn't produced by build_package"))?;
    }

    Ok(())
}

fn main() -> ExitCode {
    enter_mount_namespace().expect("Failed to enter a mount namespace");
    cli_main(do_main, Default::default())
}
