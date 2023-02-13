// Copyright 2023 The ChromiumOS Authors.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

pub(self) mod common;
pub mod internal;
pub(self) mod public;
pub(self) mod repositories;

use std::{
    fs::{create_dir_all, remove_dir_all, File},
    io::{ErrorKind, Write},
    path::Path,
    sync::{
        atomic::{AtomicUsize, Ordering},
        Arc,
    },
};

use alchemist::{
    analyze::{dependency::analyze_dependencies, source::analyze_sources},
    ebuild::{CachedPackageLoader, PackageDetails},
    fakechroot::PathTranslator,
    repository::RepositorySet,
    resolver::PackageResolver,
    toolchain::ToolchainConfig,
};
use anyhow::Result;
use rayon::prelude::*;

use self::{
    common::Package,
    internal::overlays::generate_internal_overlays,
    internal::{sdk::generate_sdk, sources::generate_internal_sources},
    public::generate_public_packages,
    repositories::generate_repositories_file,
};

fn evaluate_all_packages(
    repos: &RepositorySet,
    loader: &CachedPackageLoader,
) -> Result<Vec<Arc<PackageDetails>>> {
    let ebuild_paths = repos.find_all_ebuilds()?;
    let ebuild_count = ebuild_paths.len();

    let counter = Arc::new(AtomicUsize::new(0));

    // Evaluate packages in parallel.
    let packages = ebuild_paths
        .into_par_iter()
        .map(|ebuild_path| {
            let result = loader.load_package(&ebuild_path);
            let count = 1 + counter.fetch_add(1, Ordering::SeqCst);
            eprint!("Loading ebuilds... {}/{}\r", count, ebuild_count);
            result
        })
        .collect::<Result<Vec<_>>>()?;
    eprintln!();

    Ok(packages)
}

fn analyze_packages(
    all_details: Vec<Arc<PackageDetails>>,
    src_dir: &Path,
    resolver: &PackageResolver,
    verbose: bool,
) -> Vec<Package> {
    // Analyze packages in parallel.
    let fail_count = AtomicUsize::new(0);
    let all_packages: Vec<Package> = all_details
        .into_par_iter()
        .flat_map(|details| {
            let result = (|| -> Result<Package> {
                let dependencies = analyze_dependencies(&details, resolver)?;
                let sources = analyze_sources(&details, src_dir)?;
                Ok(Package {
                    details: details.clone(),
                    dependencies,
                    sources,
                })
            })();
            match result {
                Ok(package) => Some(package),
                Err(err) => {
                    fail_count.fetch_add(1, Ordering::SeqCst);
                    if verbose {
                        eprintln!(
                            "WARNING: {}: Analysis failed: {:#}",
                            details.ebuild_path.to_string_lossy(),
                            err
                        );
                    }
                    None
                }
            }
        })
        .collect();

    if !verbose {
        let fail_count = fail_count.load(Ordering::SeqCst);
        if fail_count > 0 {
            eprintln!(
                "WARNING: Analysis failed for {fail_count} packages; use --verbose to see details"
            );
        }
    }

    all_packages
}

/// The entry point of "generate-repo" subcommand.
pub fn generate_repo_main(
    board: &str,
    repos: &RepositorySet,
    loader: &CachedPackageLoader,
    resolver: &PackageResolver,
    translator: &PathTranslator,
    toolchain_config: &ToolchainConfig,
    src_dir: &Path,
    output_dir: &Path,
    verbose: bool,
) -> Result<()> {
    match remove_dir_all(output_dir) {
        Ok(_) => {}
        Err(err) if err.kind() == ErrorKind::NotFound => {}
        err => {
            err?;
        }
    };
    create_dir_all(output_dir)?;

    let all_details = evaluate_all_packages(repos, loader)?;

    eprintln!("Analyzing packages...");

    let all_packages = analyze_packages(all_details, src_dir, resolver, verbose);

    let all_local_sources = all_packages
        .iter()
        .flat_map(|package| package.sources.local_sources.clone())
        .collect();

    eprintln!("Generating @portage...");

    generate_internal_overlays(src_dir, repos, &all_packages, resolver, output_dir)?;
    generate_internal_sources(&all_local_sources, src_dir, output_dir)?;
    generate_public_packages(&all_packages, output_dir)?;
    generate_repositories_file(&all_packages, &output_dir.join("repositories.bzl"))?;
    generate_sdk(board, repos, toolchain_config, translator, output_dir)?;

    File::create(output_dir.join("BUILD.bazel"))?.write_all(&[])?;
    File::create(output_dir.join("WORKSPACE.bazel"))?.write_all(&[])?;

    eprintln!("Generated @portage.");

    Ok(())
}
