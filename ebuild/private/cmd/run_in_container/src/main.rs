// Copyright 2023 The ChromiumOS Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
use anyhow::{bail, Context, Result};
use clap::Parser;
use makechroot::LayerType;
use nix::{
    mount::MntFlags,
    mount::{mount, umount2, MsFlags},
    sched::{unshare, CloneFlags},
    unistd::execvp,
    unistd::{execv, getgid, getuid, pivot_root},
};
use path_absolutize::Absolutize;
use run_in_container_lib::RunInContainerConfig;
use std::{
    ffi::CString,
    ffi::OsStr,
    fs::File,
    io::Read,
    os::unix::fs::DirBuilderExt,
    os::unix::fs::OpenOptionsExt,
    path::{Path, PathBuf},
    process::Command,
};
use tar::Archive;
use walkdir::WalkDir;

const BIND_REC: MsFlags = MsFlags::MS_BIND.union(MsFlags::MS_REC);
const NONE_STR: Option<&str> = None::<&str>;

#[derive(Parser, Debug)]
#[clap(trailing_var_arg = true)]
struct Cli {
    /// A path to a serialized RunInContainerConfig.
    #[arg(long, required = true)]
    cfg: PathBuf,

    /// Enters a privileged container. In order for this flag to work, the
    /// calling process must have privileges (e.g. root).
    #[arg(long)]
    privileged: bool,

    /// Whether we are already in the namespace. Never set this, as it's as internal flag.
    #[arg(long)]
    already_in_namespace: bool,

    /// The command to run on the command-line.
    #[arg(long, required=true, num_args=1.., allow_hyphen_values=true)]
    cmd: Vec<String>,
}

pub fn main() -> Result<()> {
    let args = Cli::parse();

    if !args.already_in_namespace {
        fix_runfiles_env()?;
        enter_namespace(args.privileged)?
    } else {
        continue_namespace(RunInContainerConfig::deserialize_from(&args.cfg)?, args.cmd)?
    }
    Ok(())
}

/// Translates a file system layer source path by possibly following symlinks.
///
/// The --layer inputs can be three types:
///  1. A path to a real file/directory.
///  2. A symlink to a file/directory.
///  3. A directory tree with symlinks pointing to real files.
///
/// This function undoes the case 3. Bazel should be giving us a symlink to
/// the directory, instead of creating a symlink tree. We don't want to use the
/// symlink tree because that would require bind mounting the whole execroot
/// inside the container. Otherwise we couldn't resolve the symlinks.
///
/// This method will find the first symlink in the symlink forest which will be
/// pointing to the real execroot. It then calculates the folder that should have
/// been passed in by bazel.
fn resolve_layer_source_path(input_path: &Path) -> Result<PathBuf> {
    // Resolve the symlink so we always return an absolute path.
    let info = std::fs::symlink_metadata(input_path)?;
    if info.is_symlink() {
        return Ok(std::fs::read_link(input_path)?);
    } else if !info.is_dir() {
        return Ok(PathBuf::from(input_path));
    }

    for res_entry in WalkDir::new(input_path).follow_links(false) {
        let entry = res_entry?;
        let info = entry.metadata()?;

        if info.is_symlink() {
            let target = std::fs::read_link(entry.path())?;
            let relative_symlink = entry.path().strip_prefix(input_path)?; // blah
            let mut resolved: &Path = &target;
            for _ in 0..relative_symlink.iter().count() {
                resolved = resolved
                    .parent()
                    .with_context(|| "Symlink target should have parent")?;
            }
            return Ok(PathBuf::from(resolved));
        } else if info.is_file() {
            return Ok(PathBuf::from(input_path));
        }
    }
    // In the case that the directory is empty, we still want the returned path to
    // be valid.
    Ok(PathBuf::from(input_path))
}

/// Fixes the RUNFILES_DIR environment variable to make it an absolute path so that runfiles can be
/// found even after changing the current directory.
fn fix_runfiles_env() -> Result<()> {
    let r = runfiles::Runfiles::create()?;
    let runfiles_dir = std::env::current_dir()?.join(r.rlocation(""));
    std::env::set_var("RUNFILES_DIR", runfiles_dir);
    Ok(())
}

fn enter_namespace(privileged: bool) -> Result<()> {
    let r = runfiles::Runfiles::create()?;
    let dumb_init_path = r.rlocation("dumb_init/file/downloaded");

    // Enter a new namespace.
    const UNSHARE_FLAGS: CloneFlags = CloneFlags::CLONE_NEWNS
        .union(CloneFlags::CLONE_NEWPID)
        .union(CloneFlags::CLONE_NEWNET)
        .union(CloneFlags::CLONE_NEWIPC);
    if privileged {
        unshare(UNSHARE_FLAGS).with_context(|| "Failed to create a privileged container")?;
    } else {
        let uid = getuid();
        let gid = getgid();
        unshare(CloneFlags::CLONE_NEWUSER | UNSHARE_FLAGS)
            .with_context(|| "Failed to create an unprivileged container")?;
        std::fs::write("/proc/self/setgroups", "deny")
            .with_context(|| "Writing /proc/self/setgroups")?;
        std::fs::write("/proc/self/uid_map", format!("0 {} 1\n", uid))
            .with_context(|| "Writing /proc/self/uid_map")?;
        std::fs::write("/proc/self/gid_map", format!("0 {} 1\n", gid))
            .with_context(|| "Writing /proc/self/gid_map")?;
    }

    let dumb_init = CString::new(dumb_init_path.to_string_lossy().to_string())?;
    let argv = std::env::args()
        .map(CString::new)
        .collect::<Result<Vec<CString>, _>>()?;

    // --single-child tells dumb-init to not create a new SID. A new SID doesn't
    // have a controlling terminal, so running `bash` won't work correctly.
    // By omitting the new SID creation, the init processes will inherit the
    // current (outside) SID and PGID. This is desirable because then the parent
    // shell can correctly perform job control (Ctrl+Z) on all the processes.
    // It also tells dumb-init to only forward signals to the child, instead of
    // the child's PGID, this is undesirable, but not really a problem in
    // practice. The other processes we run are `squashfsfuse`, and these create
    // their own SID's, so we were never forwarding the signals to those processes
    // in the first place. Honestly, I'm not sure if we really even want signal
    // forwarding. Instead our `init` processes should only handle
    // `SIGINT`/`SIGTERM`, perform a `kill -TERM -1` to notify all the processes
    // in the PID namespace to shut down cleanly, then wait for all processes
    // to exit.
    let mut execv_init: Vec<CString> = vec![
        dumb_init,
        CString::new("--single-child")?,
        argv[0].clone(),
        CString::new("--already-in-namespace")?,
    ];
    execv_init.extend_from_slice(&argv[1..]);
    execv(&execv_init[0], &execv_init)?;
    unreachable!();
}

fn continue_namespace(cfg: RunInContainerConfig, cmd: Vec<String>) -> Result<()> {
    let stage_dir = cfg.staging_dir.absolutize()?;

    // Enable the loopback networking.
    if !Command::new("/usr/sbin/ifconfig")
        .args(["lo", "up"])
        .status()?
        .success()
    {
        bail!("Failed to run ifconfig in container");
    }

    // We keep all the directories in the stage dir to keep relative file paths short.
    let root_dir = stage_dir.join("root"); // Merged directory
    let base_dir = stage_dir.join("base"); // Directory containing mount targets
    let lowers_dir = stage_dir.join("lowers");
    let diff_dir = stage_dir.join("diff");
    let work_dir = stage_dir.join("work");
    let tar_dir = stage_dir.join("tar");

    let mut binding = std::fs::DirBuilder::new();
    let dir_builder = binding.recursive(true).mode(0o755);
    for dir in [
        &root_dir,
        &base_dir,
        &lowers_dir,
        &diff_dir,
        &work_dir,
        &tar_dir,
    ] {
        dir_builder.create(dir)?;
    }

    for dir in [&root_dir, &base_dir, &lowers_dir] {
        // Mount a tmpfs so that files are purged automatically on exit.
        mount(
            Some("tmpfs"),
            dir,
            Some("tmpfs"),
            MsFlags::empty(),
            NONE_STR,
        )?;
    }

    // Set up the base directory.
    for d in ["dev", "proc", "sys", "tmp", "host"] {
        dir_builder.create(base_dir.join(d))?;
    }

    // Set up lower directories.
    let mut lower_dirs: Vec<PathBuf> = Vec::new();
    for (i, layer_path) in cfg.layer_paths.iter().enumerate() {
        let layer_path = resolve_layer_source_path(layer_path)?;
        let mut lower_dir = lowers_dir.join(i.to_string());
        dir_builder.create(&lower_dir)?;

        match LayerType::detect(&layer_path)? {
            LayerType::Dir => mount(Some(&layer_path), &lower_dir, NONE_STR, BIND_REC, NONE_STR)
                .with_context(|| format!("Failed bind-mounting {layer_path:?}"))?,

            LayerType::Tar => {
                // We use a dedicated directory for the extracted artifacts instead of
                // putting them in the lower directory because the lower directory is a
                // tmpfs mount and we don't want to use up all the RAM.
                lower_dir = tar_dir.join(i.to_string());
                dir_builder.create(&lower_dir)?;
                let f = File::open(&layer_path)?;
                let decompressed: Box<dyn Read> =
                    if layer_path.extension() == Some(OsStr::new("zst")) {
                        Box::new(zstd::stream::read::Decoder::new(f)?)
                    } else {
                        Box::new(f)
                    };
                Archive::new(decompressed).unpack(&lower_dir)?;
            }
        }

        lower_dirs.push(lower_dir);
    }

    // Insert the base directory as the lowest layer.
    lower_dirs.push(base_dir);

    // Set up the store directories.
    dir_builder.create(&diff_dir)?;
    dir_builder.create(&work_dir)?;

    // Change the current directory to minimize the option string passed to
    // mount(2) as its length is constrained.
    let orig_wd = std::env::current_dir()?;
    std::env::set_current_dir(&lowers_dir)?;
    let relative_dir = |p| {
        pathdiff::diff_paths(&p, &lowers_dir)
            .with_context(|| format!("Unable to make {p:?} relative to {lowers_dir:?}"))
    };

    let short_diff_dir = relative_dir(&diff_dir)?;
    let short_work_dir = relative_dir(&work_dir)?;
    let short_lower_dirs = lower_dirs
        .iter()
        .map(|abs_lower_dir| {
            let rel_lower_dir: PathBuf = relative_dir(abs_lower_dir)?;
            let abs_lower_dir = abs_lower_dir.to_string_lossy();
            let rel_lower_dir = rel_lower_dir.to_string_lossy();
            let short_lower_dir = if rel_lower_dir.len() < abs_lower_dir.len() {
                rel_lower_dir
            } else {
                abs_lower_dir
            };
            Ok(short_lower_dir.to_string())
        })
        .collect::<Result<Vec<_>>>()?
        .join(":");

    // Mount overlayfs.
    let overlay_options = format!(
        "upperdir={},workdir={},lowerdir={}",
        short_diff_dir.display(),
        short_work_dir.display(),
        short_lower_dirs
    );
    mount(
        Some("none"),
        &root_dir,
        Some("overlay"),
        MsFlags::empty(),
        Some::<&str>(&overlay_options),
    )
    .with_context(|| "mounting overlayfs")?;

    // Mount misc file systems.
    mount(
        Some("/dev"),
        &root_dir.join("dev"),
        NONE_STR,
        BIND_REC,
        NONE_STR,
    )
    .with_context(|| "Bind-mounting /dev")?;
    mount(
        Some("/proc"),
        &root_dir.join("proc"),
        Some("proc"),
        MsFlags::empty(),
        NONE_STR,
    )
    .with_context(|| "Bind-mounting /proc")?;
    mount(
        Some("/sys"),
        &root_dir.join("sys"),
        NONE_STR,
        BIND_REC,
        NONE_STR,
    )
    .with_context(|| "Bind-mounting /sys")?;

    for spec in cfg.bind_mounts {
        let target = root_dir.join(spec.mount_path.strip_prefix("/")?);
        // Paths are sometimes provided as relative paths, but we changed directory earlier.
        // Thus, we need to join to the old working directory.
        let source = orig_wd.join(spec.source);
        dir_builder.create(
            target
                .parent()
                .with_context(|| "Can't bind-mount the root directory")?,
        )?;

        // When bind-mounting, the destination must exist.
        if !target.try_exists()? {
            let info = std::fs::metadata(&source)?;
            if info.is_dir() {
                dir_builder.create(&target)?;
            } else {
                std::fs::OpenOptions::new()
                    .create(true)
                    .write(true)
                    .mode(0o755)
                    .open(&target)?;
            }
        }

        // Unfortunately, the unix.MS_RDONLY flag is ignored for bind-mounts.
        // Thus, we mount a bind-mount, then remount it as readonly.
        mount(Some(&source), &target, NONE_STR, MsFlags::MS_BIND, NONE_STR)
            .with_context(|| format!("Failed bind-mounting {:?} to {:?}", source, target))?;
        mount(
            NONE_STR,
            &target,
            NONE_STR,
            MsFlags::MS_REMOUNT
                .union(MsFlags::MS_BIND)
                .union(MsFlags::MS_RDONLY),
            NONE_STR,
        )
        .with_context(|| format!("Failed remounting {target:?} as read-only"))?;
    }

    pivot_root(&root_dir, &root_dir.join("host")).with_context(|| "Failed to pivot root")?;

    if !cfg.keep_host_mount {
        // Do a lazy unmount with DETACH. Since the binary is dynamically linked, we still have some
        // file descriptors such as /host/usr/lib/x86_64-linux-gnu/libc.so.6 open.
        umount2("/host", MntFlags::MNT_DETACH).with_context(|| "unmounting host")?;
    }

    // These are absolute paths that are no longer valid after we pivot.
    std::env::remove_var("RUNFILES_DIR");
    std::env::remove_var("RUNFILES_MANIFEST_FILE");

    std::env::set_current_dir(&cfg.chdir).with_context(|| format!("chdir to {:?}", cfg.chdir))?;

    let cmd = cmd
        .into_iter()
        .map(CString::new)
        .collect::<Result<Vec<CString>, _>>()?;
    execvp(&cmd[0], &cmd)?;
    unreachable!();
}
