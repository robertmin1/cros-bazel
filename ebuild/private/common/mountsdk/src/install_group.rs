use anyhow::{Context, Error, Result};
use binarypackage::BinaryPackage;
use makechroot::BindMount;
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::str::{from_utf8, FromStr};

#[derive(Debug, Clone)]
pub struct InstallGroup {
    packages: Vec<PathBuf>,
}

impl FromStr for InstallGroup {
    type Err = Error;

    fn from_str(s: &str) -> Result<Self> {
        Ok(Self {
            packages: s.split(":").map(PathBuf::from).collect(),
        })
    }
}

impl InstallGroup {
    fn get_config(&self, dir: &Path) -> Result<(Vec<BindMount>, Vec<String>)> {
        let mut bind_mounts: Vec<BindMount> = Vec::new();
        let mut atoms: Vec<String> = Vec::new();
        for package in &self.packages {
            let xp = BinaryPackage::new(package)?.xpak()?;
            let category = from_utf8(
                xp.get("CATEGORY")
                    .with_context(|| "Ebuild must have category")?,
            )?
            .trim();
            let pf = from_utf8(xp.get("PF").with_context(|| "Ebuild must have PF")?)?.trim();
            bind_mounts.push(BindMount {
                source: package.into(),
                mount_path: dir.join(category).join(format!("{}.tbz2", pf)),
            });
            atoms.push(format!("={}/{}", category, pf));
        }
        Ok((bind_mounts, atoms))
    }

    pub fn get_mounts_and_env<P: AsRef<Path>>(
        install_groups: &[InstallGroup],
        dir: P,
    ) -> Result<(Vec<BindMount>, HashMap<String, String>)> {
        let mut bind_mounts: Vec<BindMount> = Vec::new();
        let mut env: HashMap<String, String> = HashMap::new();
        for (i, install_group) in install_groups.iter().enumerate() {
            let (mut group_mounts, atoms) = install_group.get_config(dir.as_ref())?;
            bind_mounts.append(&mut group_mounts);
            env.insert(format!("INSTALL_ATOMS_TARGET_{}", i), atoms.join(" "));
        }
        Ok((bind_mounts, env))
    }
}