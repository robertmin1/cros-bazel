// Copyright 2022 The ChromiumOS Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use anyhow::{anyhow, bail, ensure, Context, Result};
use clap::{command, Parser};
use cliutil::cli_main;
use container::{enter_mount_namespace, BindMount, CommonArgs, ContainerSettings};
use std::format;
use std::io::Write;
use std::{
    borrow::Cow,
    collections::{HashMap, HashSet},
    ffi::{OsStr, OsString},
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

    #[arg(long, help = "The bashrc files to execute. The path must be absolute.")]
    bashrc: Vec<PathBuf>,

    #[arg(
        long,
        help = "Points to a named pipe that is used for the GNU Make jobserver."
    )]
    jobserver: Option<PathBuf>,

    #[arg(long, help = "Directory to store incremental ebuild artifacts")]
    incremental_cache_dir: Option<PathBuf>,

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

    #[arg(long, help = "Remoteexec-related info encoded as JSON.")]
    remoteexec_info: PathBuf,

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

/// Writes a profile.bashrc for the specific package. It uses `source` to
/// execute the files so that when the script is executed `${BASH_SOURCE[0]}`
/// reports the correct path.
fn write_profile_bashrc(sysroot: &Path, bashrcs: &Vec<PathBuf>) -> Result<()> {
    if bashrcs.is_empty() {
        return Ok(());
    }

    let profile_path = sysroot.join("etc").join("portage").join("profile");
    std::fs::create_dir_all(&profile_path)?;

    let profile_bashrc = profile_path.join("profile.bashrc");
    let mut out =
        File::create(&profile_bashrc).with_context(|| format!("file {profile_bashrc:?}"))?;

    for bashrc in bashrcs {
        let bashrc = bashrc
            .to_str()
            .with_context(|| format!("Path conversion failed: {bashrc:?}"))?;

        writeln!(out, "source '{}' || exit 1", bashrc.replace('\'', "'\\''"))?;
    }

    Ok(())
}

/// Collects reclient log files.
fn collect_reclient_log_files(container_root: &Path) -> Result<()> {
    // The path must be in sync with the one in chromite/sdk/reclient_cfgs/reproxy.cfg.
    let reclient_log_dir = container_root.join("tmp/reclient-chromeos-chrome");
    if reclient_log_dir.try_exists()? {
        // Generate a unique destination directory path with the current date and a random number.
        // NOTE: On CI builders, chromite's remoteexec_lib.LogsArchiver will upload reclient log
        // files found under /tmp/reclient-* as build artifacts.
        let date = chrono::Utc::now()
            .naive_utc()
            .format("%Y%m%d%H%M%S")
            .to_string();
        let random_number = rand::random::<u32>();
        let dest_dir = PathBuf::from(format!(
            "/tmp/reclient-chromeos-chrome-alchemy-{date}-{random_number}"
        ));

        std::fs::create_dir(&dest_dir)?;
        // Copy all log files created by reclient. Skip symlinks as they're not interesting.
        // Reclient creates no directory in the log output directory.
        for entry in std::fs::read_dir(reclient_log_dir)? {
            let entry = entry?;
            if entry.file_type()?.is_file() {
                let from = entry.path();
                let to = dest_dir.join(from.file_name().expect("`from` should have a file name."));
                std::fs::copy(&from, &to).with_context(|| {
                    format!("Failed to copy a reclient log file {from:?} to {to:?}")
                })?;
            }
        }
    }
    Ok(())
}

#[derive(serde::Deserialize)]
struct GomaInfo {
    use_goma: bool,
    envs: HashMap<String, String>,
    luci_context: Option<PathBuf>,
    oauth2_config_file: Option<PathBuf>,
}

#[derive(serde::Deserialize)]
struct RemoteexecInfo {
    use_remoteexec: bool,
    envs: HashMap<String, String>,
    gcloud_config_dir: Option<PathBuf>,
    reclient_dir: Option<PathBuf>,
    reproxy_cfg: Option<PathBuf>,
    should_use_reproxy_cfg_file_for_ci: bool,
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

    if args.allow_network_access {
        for path in [Path::new("/etc/resolv.conf"), Path::new("/etc/hosts")] {
            if path.try_exists()? {
                settings.push_bind_mount(BindMount {
                    source: path.to_owned(),
                    mount_path: path.to_owned(),
                    rw: false,
                })
            }
        }
    }

    let (portage_tmp_dir, portage_pkg_dir, portage_cache_dir) = match &args.board {
        Some(board) => {
            let root_dir = Path::new("/build").join(board);
            (
                root_dir.join("tmp/portage"),
                root_dir.join("packages"),
                root_dir.join("var/cache/portage"),
            )
        }
        None => (
            PathBuf::from("/var/tmp/portage"),
            PathBuf::from("/var/lib/portage/pkgs"),
            PathBuf::from("/var/cache/portage"),
        ),
    };

    if let Some(dir) = args.incremental_cache_dir {
        std::fs::create_dir_all(&dir).with_context(|| {
            format!(
                "cannot create incremental cache directory {}",
                dir.display()
            )
        })?;
        settings.push_bind_mount(BindMount {
            mount_path: portage_cache_dir,
            source: dir,
            rw: true,
        });
    }

    let mut envs: Vec<(Cow<OsStr>, Cow<OsStr>)> = Vec::new();

    if args.ebuild.category == "chromeos-base" && args.ebuild.package_name == "chromeos-chrome" {
        let remoteexec_info: RemoteexecInfo =
            serde_json::from_reader(BufReader::new(File::open(args.remoteexec_info)?))?;
        if remoteexec_info.use_remoteexec {
            envs.push((
                OsStr::new("USE_REMOTEEXEC").into(),
                OsStr::new("true").into(),
            ));
        }
        for (key, value) in remoteexec_info.envs {
            envs.push((OsString::from(key).into(), OsString::from(value).into()));
        }
        if let Some(gcloud_config_dir) = remoteexec_info.gcloud_config_dir {
            settings.push_bind_mount(BindMount {
                source: gcloud_config_dir,
                mount_path: PathBuf::from("/home/root/.config/gcloud"),
                rw: false,
            });
        }
        if let Some(reclient_dir) = remoteexec_info.reclient_dir {
            settings.push_bind_mount(BindMount {
                source: reclient_dir.clone(),
                mount_path: reclient_dir.clone(),
                rw: false,
            });
            envs.push((
                OsStr::new("RECLIENT_DIR").into(),
                reclient_dir.into_os_string().into(),
            ))
        }
        if let Some(reproxy_cfg) = remoteexec_info.reproxy_cfg {
            settings.push_bind_mount(BindMount {
                source: reproxy_cfg.clone(),
                mount_path: reproxy_cfg.clone(),
                rw: false,
            });
            envs.push((
                OsStr::new("REPROXY_CFG").into(),
                reproxy_cfg.into_os_string().into(),
            ))
        }
        envs.push((
            OsStr::new("SHOULD_USE_REPROXY_CFG_FILE_FOR_CI").into(),
            OsStr::new(if remoteexec_info.should_use_reproxy_cfg_file_for_ci {
                "true"
            } else {
                "false"
            })
            .into(),
        ));

        let goma_info: GomaInfo =
            serde_json::from_reader(BufReader::new(File::open(args.goma_info)?))?;
        if goma_info.use_goma {
            // TODO(b/300218625): Also set GLOG_log_dir to support uploading build logs.
            envs.extend([
                (OsStr::new("USE_GOMA").into(), OsStr::new("true").into()),
                (
                    OsStr::new("GOMA_TMP_DIR").into(),
                    OsStr::new("/tmp/goma").into(),
                ),
            ]);
            settings.push_bind_mount(BindMount {
                source: runfiles.rlocation("files/goma-chromeos-modified-for-alchemy.tgz"),
                mount_path: PathBuf::from("/mnt/host/goma.tgz"),
                rw: false,
            });

            for (key, value) in goma_info.envs {
                envs.push((OsString::from(key).into(), OsString::from(value).into()));
            }

            if let Some(oauth2_config_file) = goma_info.oauth2_config_file {
                settings.push_bind_mount(BindMount {
                    source: oauth2_config_file.clone(),
                    mount_path: oauth2_config_file.clone(),
                    rw: false,
                });
                envs.push((
                    OsStr::new("GOMA_OAUTH2_CONFIG_FILE").into(),
                    oauth2_config_file.into_os_string().into(),
                ));
            }

            if let Some(luci_context) = goma_info.luci_context {
                settings.push_bind_mount(BindMount {
                    source: luci_context.clone(),
                    mount_path: luci_context.clone(),
                    rw: false,
                });
                envs.push((
                    OsStr::new("LUCI_CONTEXT").into(),
                    luci_context.into_os_string().into(),
                ));
            }
        }
    }

    if let Some(jobserver) = args.jobserver {
        // TODO(b/303061227): Should we check if we can open the FIFO?

        settings.push_bind_mount(BindMount {
            source: jobserver,
            mount_path: PathBuf::from(JOB_SERVER),
            rw: false,
        });

        envs.push((
            OsStr::new("MAKEFLAGS").into(),
            OsString::from(format!("--jobserver-auth=fifo:{}", JOB_SERVER)).into(),
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
    write_profile_bashrc(&sysroot, &args.bashrc)?;

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
    collect_reclient_log_files(container.root_dir())
        .context("Failed to collect reclient log files")?;
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
