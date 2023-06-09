// Copyright 2023 The ChromiumOS Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use anyhow::Result;
use serde::{Deserialize, Serialize};
use std::collections::BTreeMap;
use std::ffi::OsString;
use std::fs::File;
use std::io::BufReader;
use std::path::{Path, PathBuf};

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct BindMountConfig {
    pub mount_path: PathBuf,
    pub source: PathBuf,
    pub rw: bool,
}

#[derive(Clone, Debug, Serialize, Deserialize)]
pub struct RunInContainerConfig {
    /// The upper directory to be used by overlayfs.
    /// After run_in_container finishes, this directory contains files
    /// representing the difference to the lower directories.
    /// It is caller's responsibility to remove the directory after
    /// run_in_container finishes.
    pub upper_dir: PathBuf,

    /// The directory where run_in_container creates random files/directories.
    /// This directory must be on the same file system as that of the upper
    /// directory.
    /// It is caller's responsibility to remove the directory after
    /// run_in_container finishes.
    pub scratch_dir: PathBuf,

    /// The command to run in the container.
    pub args: Vec<OsString>,

    /// Environment variables for the process in the container.
    #[serde(with = "serde_os_string_map")]
    pub envs: BTreeMap<OsString, OsString>,

    /// Directory to use as the working directory while inside the namespace.
    pub chdir: PathBuf,

    /// Lower directories of the overlayfs.
    pub lower_dirs: Vec<PathBuf>,

    /// Bind-mounts to apply. Applies on top of file system layers, and can
    /// mount individual files as well as directories.
    pub bind_mounts: Vec<BindMountConfig>,

    /// Allows network access. This option should be used only when it's
    /// absolutely needed since it reduces hermeticity.
    pub allow_network_access: bool,

    /// Starts a privileged container. In order for this option to work, the
    /// run_in_container process must be run with privilege (e.g. as root).
    pub privileged: bool,

    /// If true, the contents of the host machine are mounted at /host.
    pub keep_host_mount: bool,
}

impl RunInContainerConfig {
    pub fn deserialize_from(path: &Path) -> Result<Self> {
        Ok(serde_json::from_reader(BufReader::new(File::open(path)?))?)
    }

    pub fn serialize_to(&self, path: &Path) -> Result<()> {
        serde_json::to_writer(File::create(path)?, self)?;
        Ok(())
    }
}

/// Implements serialization/deserialization of `BTreeMap<OsString, T>`.
///
/// By default, serde doesn't support maps with non-String keys. This module
/// supports [`OsString`] keys by converting them to [`String`] automatically.
mod serde_os_string_map {
    use std::{collections::BTreeMap, ffi::OsString};

    use serde::{ser::SerializeMap, Deserialize, Deserializer, Serialize, Serializer};

    pub fn serialize<S, T>(map: &BTreeMap<OsString, T>, serializer: S) -> Result<S::Ok, S::Error>
    where
        S: Serializer,
        T: Serialize,
    {
        let mut serializer_map = serializer.serialize_map(Some(map.len()))?;
        for (key, value) in map.iter() {
            // TODO: Handle serialization errors. I don't know how to construct
            // `S::Error` because it's a general type.
            let key_str = key.to_string_lossy();
            serializer_map.serialize_entry(&key_str, value)?;
        }
        serializer_map.end()
    }

    pub fn deserialize<'de, D, T>(deserializer: D) -> Result<BTreeMap<OsString, T>, D::Error>
    where
        D: Deserializer<'de>,
        T: Deserialize<'de>,
    {
        let map = BTreeMap::<String, T>::deserialize(deserializer)?;
        let map = map
            .into_iter()
            .map(|(key, value)| (OsString::from(key), value))
            .collect();
        Ok(map)
    }
}
