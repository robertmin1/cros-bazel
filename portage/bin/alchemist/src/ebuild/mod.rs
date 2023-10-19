// Copyright 2022 The ChromiumOS Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

pub mod metadata;

use anyhow::{Context, Result};
use once_cell::sync::OnceCell;
use std::{
    collections::{HashMap, HashSet},
    path::{Path, PathBuf},
    sync::{Arc, Mutex},
};
use version::Version;

use crate::{
    bash::vars::BashVars,
    config::bundle::{ConfigBundle, IsPackageAcceptedResult},
    data::{IUseMap, Slot, UseMap},
    dependency::{
        package::{PackageRef, ThinPackageRef},
        requse::RequiredUseDependency,
        ThreeValuedPredicate,
    },
};

use self::metadata::{CachedEBuildEvaluator, MaybeEBuildMetadata};

/// Parses IUSE defined by ebuild/eclasses and returns as an [IUseMap].
fn parse_iuse_map(vars: &BashVars) -> Result<IUseMap> {
    Ok(vars
        .get_scalar_or_default("IUSE")?
        .split_ascii_whitespace()
        .map(|token| {
            if let Some(name) = token.strip_prefix('+') {
                return (name, true);
            }
            if let Some(name) = token.strip_prefix('-') {
                return (name, false);
            }
            (token, false)
        })
        .map(|(name, value)| (name.to_owned(), value))
        .collect())
}

type PackageResult = Result<PackageDetails, PackageMetadataError>;

/// Holds the error that occurred when processing the ebuild.
#[derive(Clone, Debug)]
pub struct PackageMetadataError {
    pub repo_name: String,
    pub package_name: String,
    pub ebuild: PathBuf,
    pub version: Version,
    pub error: String,
}

#[derive(Clone, Debug)]
pub struct PackageDetails {
    pub repo_name: String,
    pub package_name: String,
    pub version: Version,
    pub vars: BashVars,
    pub slot: Slot,
    pub use_map: UseMap,
    pub accepted: bool,
    pub stable: bool,
    pub masked: bool,
    pub ebuild_path: PathBuf,
    pub inherited: HashSet<String>,
    pub inherit_paths: Vec<PathBuf>,
    pub direct_build_target: Option<String>,
}

impl PackageDetails {
    /// Converts this PackageDetails to a PackageRef that can be passed to
    /// dependency predicates.
    pub fn as_package_ref(&self) -> PackageRef {
        PackageRef {
            package_name: &self.package_name,
            version: &self.version,
            slot: Slot {
                main: self.slot.main.as_str(),
                sub: self.slot.sub.as_str(),
            },
            use_map: &self.use_map,
        }
    }

    pub fn as_thin_package_ref(&self) -> ThinPackageRef {
        ThinPackageRef {
            package_name: &self.package_name,
            version: &self.version,
            slot: Slot {
                main: self.slot.main.as_str(),
                sub: self.slot.sub.as_str(),
            },
        }
    }

    /// EAPI is technically a string, but working with an integer is easier.
    fn eapi(&self) -> Result<i32> {
        let eapi = self.vars.get_scalar("EAPI")?;
        eapi.parse::<i32>().with_context(|| format!("EAPI: {eapi}"))
    }

    pub fn supports_bdepend(&self) -> bool {
        let eapi = match self.eapi() {
            Ok(val) => val,
            Err(_) => return false,
        };

        eapi >= 7
    }
}

#[derive(Debug)]
pub struct PackageLoader {
    evaluator: Arc<CachedEBuildEvaluator>,
    config: Arc<ConfigBundle>,
    force_accept_9999_ebuilds: bool,
    version_9999: Version,
}

impl PackageLoader {
    pub fn new(
        evaluator: Arc<CachedEBuildEvaluator>,
        config: Arc<ConfigBundle>,
        force_accept_9999_ebuilds: bool,
    ) -> Self {
        Self {
            evaluator,
            config,
            force_accept_9999_ebuilds,
            version_9999: Version::try_new("9999").unwrap(),
        }
    }

    pub fn load_package(&self, ebuild_path: &Path) -> Result<PackageResult> {
        // Drive the ebuild to read its metadata.
        let metadata = self.evaluator.evaluate_metadata(ebuild_path)?;

        // Compute additional information needed to fill in PackageDetails.
        let package_name = format!("{}/{}", metadata.category_name, metadata.short_package_name);

        let metadata = match metadata {
            MaybeEBuildMetadata::Ok(metadata) => metadata,
            MaybeEBuildMetadata::Err(error) => {
                return Ok(PackageResult::Err(PackageMetadataError {
                    repo_name: error.repo_name.clone(),
                    package_name,
                    ebuild: ebuild_path.to_owned(),
                    version: error.version.clone(),
                    error: error.error.clone(),
                }))
            }
        };

        let slot = Slot::<String>::new(metadata.vars.get_scalar("SLOT")?);

        let package = ThinPackageRef {
            package_name: package_name.as_str(),
            version: &metadata.version,
            slot: Slot {
                main: &slot.main,
                sub: &slot.sub,
            },
        };

        let raw_inherited = metadata.vars.get_scalar_or_default("INHERITED")?;
        let inherited: HashSet<String> = raw_inherited
            .split_ascii_whitespace()
            .map(|s| s.to_owned())
            .collect();

        let raw_inherit_paths = metadata.vars.get_indexed_array("INHERIT_PATHS")?;
        let inherit_paths: Vec<PathBuf> = raw_inherit_paths.iter().map(PathBuf::from).collect();

        let (accepted, stable) = match self.config.is_package_accepted(&metadata.vars, &package)? {
            IsPackageAcceptedResult::Unaccepted => {
                if self.force_accept_9999_ebuilds {
                    let accepted = inherited.contains("cros-workon")
                        && metadata.version == self.version_9999
                        && match metadata.vars.get_scalar("CROS_WORKON_MANUAL_UPREV") {
                            Ok(value) => value != "1",
                            Err(_) => false,
                        };
                    (accepted, false)
                } else {
                    (false, false)
                }
            }
            IsPackageAcceptedResult::Accepted(stable) => (true, stable),
        };

        let iuse_map = parse_iuse_map(&metadata.vars)?;
        let use_map =
            self.config
                .compute_use_map(&package_name, &metadata.version, stable, &slot, &iuse_map);

        let required_use: RequiredUseDependency = metadata
            .vars
            .get_scalar_or_default("REQUIRED_USE")?
            .parse()?;

        let masked = !accepted
            || self.config.is_package_masked(&package)
            || required_use.matches(&use_map) == Some(false);

        let direct_build_target = metadata
            .vars
            .maybe_get_scalar("METALLURGY_TARGET")?
            .map(|s| {
                if s.starts_with('@') {
                    s.to_string()
                } else {
                    // eg. //bazel:foo -> @@//bazel:foo
                    format!("@@{s}")
                }
            });

        Ok(PackageResult::Ok(PackageDetails {
            repo_name: metadata.repo_name.clone(),
            package_name,
            version: metadata.version.clone(),
            vars: metadata.vars.clone(),
            slot,
            use_map,
            accepted,
            stable,
            masked,
            inherited,
            inherit_paths,
            ebuild_path: ebuild_path.to_owned(),
            direct_build_target,
        }))
    }
}

type CachedPackageResult = std::result::Result<Arc<PackageDetails>, Arc<PackageMetadataError>>;

/// Wraps PackageLoader to cache results.
#[derive(Debug)]
pub struct CachedPackageLoader {
    loader: PackageLoader,
    cache: Mutex<HashMap<PathBuf, Arc<OnceCell<CachedPackageResult>>>>,
}

impl CachedPackageLoader {
    pub fn new(loader: PackageLoader) -> Self {
        Self {
            loader,
            cache: Default::default(),
        }
    }

    pub fn load_package(&self, ebuild_path: &Path) -> Result<CachedPackageResult> {
        let once_cell = {
            let mut cache_guard = self.cache.lock().unwrap();
            cache_guard
                .entry(ebuild_path.to_owned())
                .or_default()
                .clone()
        };
        let details = once_cell.get_or_try_init(|| -> Result<CachedPackageResult> {
            match self.loader.load_package(ebuild_path)? {
                PackageResult::Ok(details) => {
                    Result::Ok(CachedPackageResult::Ok(Arc::new(details)))
                }
                PackageResult::Err(err) => Result::Ok(CachedPackageResult::Err(Arc::new(err))),
            }
        })?;
        Ok(details.clone())
    }
}
