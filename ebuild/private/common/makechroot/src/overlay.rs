// Copyright 2022 The ChromiumOS Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
use anyhow::{bail, Result};
use durabletree::DurableTree;
use path_absolutize::Absolutize;
use serde::{Deserialize, Serialize};
use std::{path::Path, path::PathBuf, str::FromStr};

fn from_str(spec: &str) -> Result<(PathBuf, PathBuf)> {
    let (first, second) = cliutil::split_key_value(spec)?;
    Ok((PathBuf::from(first), PathBuf::from(second)))
}

#[derive(Serialize, Deserialize, Debug, Clone)]
pub struct BindMount {
    pub mount_path: PathBuf,
    pub source: PathBuf,
}

impl FromStr for BindMount {
    type Err = anyhow::Error;
    fn from_str(spec: &str) -> Result<Self> {
        let (mount_path, source) = from_str(spec)?;
        Ok(Self { mount_path, source })
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum LayerType {
    Dir,
    Tar,
    DurableTree,
}

impl LayerType {
    pub fn detect<P: AsRef<Path>>(layer_path: P) -> Result<Self> {
        let layer_path = layer_path.as_ref().absolutize()?;

        let file_name = layer_path
            .file_name()
            .and_then(|x| x.to_str())
            .unwrap_or_default();
        if DurableTree::try_exists(&layer_path)? {
            Ok(LayerType::DurableTree)
        } else if std::fs::metadata(&layer_path)?.is_dir() {
            Ok(LayerType::Dir)
        } else if file_name.ends_with(".tar.zst") || file_name.ends_with(".tar") {
            Ok(LayerType::Tar)
        } else {
            bail!("unsupported file type: {:?}", layer_path)
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use runfiles::Runfiles;
    use tempfile::TempDir;

    #[test]
    fn detect_layer_type_works() -> Result<()> {
        let r = Runfiles::create()?;
        let testdata = PathBuf::from("cros/bazel/ebuild/private/common/makechroot/testdata/");

        assert_eq!(
            LayerType::detect(r.rlocation(testdata.join("example.tar.zst")))?,
            LayerType::Tar
        );
        assert_eq!(
            LayerType::detect(r.rlocation(testdata.join("example.tar")))?,
            LayerType::Tar
        );

        let temp_dir = TempDir::new()?;
        let temp_dir = temp_dir.path();

        assert_eq!(LayerType::detect(temp_dir)?, LayerType::Dir);

        DurableTree::convert(temp_dir)?;
        assert_eq!(LayerType::detect(temp_dir)?, LayerType::DurableTree);

        assert!(LayerType::detect(Path::new("/dev/null")).is_err());

        Ok(())
    }
}
