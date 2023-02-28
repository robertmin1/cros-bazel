// Copyright 2022 The ChromiumOS Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use anyhow::{anyhow, bail, Context, Result};
use itertools::Itertools;
use std::{
    ffi::OsStr,
    io::{Read, Seek, SeekFrom, Write},
    path::{Path, PathBuf},
    process::Command,
};
use version::Version;

use crate::{
    bash::vars::{parse_set_output, BashVars},
    data::Vars,
};

fn run_ebuild(
    ebuild_path: &Path,
    env: &Vars,
    eclass_dirs: Vec<&Path>,
    tools_dir: &Path,
) -> Result<BashVars> {
    let mut script_file = tempfile::tempfile()?;
    script_file.write_all(include_bytes!("ebuild_prelude.sh"))?;
    script_file.seek(SeekFrom::Start(0))?;

    let mut set_output_file = tempfile::NamedTempFile::new()?;

    let output = Command::new("/bin/bash")
        .stdin(script_file)
        .current_dir("/")
        .env_clear()
        .envs(env)
        .env("PATH", tools_dir.to_string_lossy().as_ref())
        .env("__xbuild_in_ebuild", ebuild_path.to_string_lossy().as_ref())
        .env(
            "__xbuild_in_eclass_dirs",
            eclass_dirs
                .iter()
                .map(|path| format!("{}\n", path.to_string_lossy()))
                .join(""),
        )
        .env(
            "__xbuild_in_output_vars",
            set_output_file.as_ref().to_string_lossy().as_ref(),
        )
        .output()
        .context("Failed to spawn bash for ebuild metadata evaluation")?;

    if !output.status.success() {
        bail!("ebuild failed to evaluate: {}", &output.status);
    }
    if !output.stdout.is_empty() || !output.stderr.is_empty() {
        bail!(
            "ebuild printed errors to stdout/stderr\nstdout: {}\nstderr: {}",
            String::from_utf8_lossy(&output.stdout),
            String::from_utf8_lossy(&output.stderr)
        );
    }

    let mut set_output = String::new();
    set_output_file
        .as_file_mut()
        .read_to_string(&mut set_output)?;
    parse_set_output(&set_output)
}

#[derive(Debug)]
pub(super) struct EBuildEvaluator {
    tools_dir: PathBuf,
}

impl EBuildEvaluator {
    pub(super) fn new(tools_dir: &Path) -> Self {
        Self {
            tools_dir: tools_dir.to_owned(),
        }
    }

    pub(super) fn evaluate_metadata(
        &self,
        ebuild_path: &Path,
        eclass_dirs: Vec<&Path>,
    ) -> Result<EBuildMetadata> {
        // We don't need to provide profile variables to the ebuild environment
        // because PMS requires ebuild metadata to be defined independently of
        // profiles.
        // https://projects.gentoo.org/pms/8/pms.html#x1-600007.1
        let path_info = EBuildPathInfo::try_from(ebuild_path)?;
        let env = path_info.to_vars();
        let vars = run_ebuild(ebuild_path, &env, eclass_dirs, &self.tools_dir)?;
        Ok(EBuildMetadata { path_info, vars })
    }
}

pub(super) struct EBuildMetadata {
    pub path_info: EBuildPathInfo,
    pub vars: BashVars,
}

pub(super) struct EBuildPathInfo {
    pub package_short_name: String,
    pub category_name: String,
    pub version: Version,
}

impl EBuildPathInfo {
    fn to_vars(&self) -> Vars {
        Vars::from_iter(
            [
                (
                    "P",
                    format!(
                        "{}-{}",
                        &self.package_short_name,
                        self.version.without_revision()
                    ),
                ),
                (
                    "PF",
                    format!("{}-{}", &self.package_short_name, self.version),
                ),
                ("PN", self.package_short_name.to_owned()),
                ("CATEGORY", self.category_name.to_owned()),
                ("PV", self.version.without_revision().to_string()),
                ("PR", format!("r{}", self.version.revision())),
                ("PVR", self.version.to_string()),
            ]
            .into_iter()
            .map(|(key, value)| (key.to_owned(), value)),
        )
    }
}

impl TryFrom<&Path> for EBuildPathInfo {
    type Error = anyhow::Error;

    fn try_from(path: &Path) -> Result<Self> {
        if path.extension() != Some(OsStr::new("ebuild")) {
            bail!("{} is not an ebuild file", path.to_string_lossy());
        }

        let file_stem = path.file_stem().unwrap_or_default().to_string_lossy();
        let (package_short_name, version) = Version::from_str_suffix(file_stem.as_ref())
            .with_context(|| format!("{} has corrupted file name", path.to_string_lossy()))?;

        let (package_short_name_from_dir, category_name) = path
            .components()
            .rev()
            .skip(1)
            .next_tuple()
            .ok_or_else(|| {
                anyhow!(
                    "{} does not contain necessary directory part",
                    path.to_string_lossy()
                )
            })?;

        if package_short_name != package_short_name_from_dir.as_os_str().to_string_lossy() {
            bail!(
                "{} has inconsistent package names in directory name and file name",
                path.to_string_lossy()
            );
        }

        Ok(Self {
            package_short_name: package_short_name.to_owned(),
            category_name: category_name.as_os_str().to_string_lossy().to_string(),
            version,
        })
    }
}
