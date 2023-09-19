// Copyright 2023 The ChromiumOS Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use anyhow::Result;
use regex::Regex;
use std::collections::BTreeSet;
use std::ffi::OsStr;
use std::path::{Path, PathBuf};

/// Filters a list of files down to only specific shared libraries.
/// Outputs shared libraries in library search path ordering, removing duplicates.
///
/// # Arguments
/// * `paths` - A list of paths that may or may not be shared libraries.
/// * `directory_regexes` - A list of regexes, treated similarly to LD_LIBRARY_PATH.
///
/// # Examples
/// `filter_shared_libs(["/usr/lib/libfoo.so", "/lib/libfoo.so"], [r"/lib\d*", r"/usr/lib\d*"])`
/// The example above would return `["/lib/libfoo.so"]`, since, while they both match, according to
/// it prioritizes the first entry in regexes like it would LD_LIBRARY_PATH.
pub fn filter_shared_libs<'a>(
    paths: &[&'a Path],
    directory_regexes: &[Regex],
) -> Result<Vec<&'a Path>> {
    let ld_library_path = crate::library_path::generate_ld_library_path(paths, directory_regexes)?;
    Ok(
        crate::library_path::calculate_shared_libraries(paths, &ld_library_path)?
            .into_iter()
            .collect(),
    )
}

#[derive(Debug, PartialEq)]
pub struct HeaderFiles {
    /// The directories matched by the regexes in `filter_header_files`
    pub header_file_dirs: BTreeSet<PathBuf>,

    /// The header files contained transitively within the directories above.
    pub header_files: Vec<PathBuf>,
}

/// Filters down `paths` to only header files contained within directories specified by `regexes`.
/// Note that each regex is a regular expression for the directory containing header files, not the
/// the path to the header files themselves.
/// Just like header files searching, this includes files contained within a subdirectory.
///
/// # Examples
/// ```
/// filter_header_files(
///   ["/usr/include/a.h", "/usr/include/subdir/b.h", "/unrelated/c.h"],
///   [r"/usr/[^/]+"]
/// ) == HeaderFiles{
///     header_file_dirs: ["/usr/include"],
///     header_files: ["/usr/include/a.h", "/usr/include/subdir/b.h"],
/// }
/// ```
pub fn filter_header_files(paths: &[&Path], directory_regexes: &[Regex]) -> Result<HeaderFiles> {
    let mut header_files: Vec<PathBuf> = vec![];
    let mut header_file_dirs: BTreeSet<PathBuf> = BTreeSet::new();
    for p in paths
        .iter()
        .filter(|p| p.extension() == Some(OsStr::new("h")))
    {
        let p_str = p.to_string_lossy();
        for regex in directory_regexes {
            if let Some(m) = regex.find(&p_str) {
                if p_str.get(m.end()..m.end() + 1) == Some("/") {
                    header_file_dirs.insert(PathBuf::from(m.as_str()));
                    header_files.push(p.to_path_buf());
                    break;
                }
            }
        }
    }
    header_files.sort();
    Ok(HeaderFiles {
        header_files,
        header_file_dirs,
    })
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_invalid_headers() -> Result<()> {
        assert_eq!(
            filter_header_files(
                &[Path::new("/path/foo.h"), Path::new("/path/foo.cc"),],
                &[Regex::new("/path")?]
            )?,
            HeaderFiles {
                header_files: vec![PathBuf::from("/path/foo.h")],
                header_file_dirs: [PathBuf::from("/path")].into_iter().collect()
            }
        );
        Ok(())
    }

    #[test]
    fn test_subdirectories() -> Result<()> {
        assert_eq!(
            filter_header_files(&[Path::new("/path/subdir/foo.h"),], &[Regex::new("/path")?])?,
            HeaderFiles {
                header_files: vec![PathBuf::from("/path/subdir/foo.h")],
                header_file_dirs: [PathBuf::from("/path")].into_iter().collect()
            }
        );
        Ok(())
    }

    #[test]
    fn test_not_in_dir() -> Result<()> {
        assert_eq!(
            filter_header_files(&[Path::new("/path/foo.h"),], &[])?,
            HeaderFiles {
                header_files: vec![],
                header_file_dirs: [].into_iter().collect()
            }
        );
        Ok(())
    }

    #[test]
    fn test_unused_directories() -> Result<()> {
        assert_eq!(
            filter_header_files(
                &[Path::new("/path/foo.h"),],
                &[Regex::new("/path")?, Regex::new("/other")?]
            )?,
            HeaderFiles {
                header_files: vec![PathBuf::from("/path/foo.h")],
                header_file_dirs: [PathBuf::from("/path")].into_iter().collect()
            }
        );
        Ok(())
    }

    #[test]
    fn test_regex_matchers() -> Result<()> {
        assert_eq!(
            filter_header_files(
                &[
                    Path::new("/usr/lib/gcc/10.2.0/foo.h"),
                    Path::new("/usr/lib/gcc/10.2.1/bar.h"),
                ],
                &[Regex::new(r"/usr/lib/gcc/\d+\.\d+\.\d+")?]
            )?,
            HeaderFiles {
                header_files: vec![
                    PathBuf::from("/usr/lib/gcc/10.2.0/foo.h"),
                    PathBuf::from("/usr/lib/gcc/10.2.1/bar.h"),
                ],
                header_file_dirs: [
                    PathBuf::from("/usr/lib/gcc/10.2.0"),
                    PathBuf::from("/usr/lib/gcc/10.2.1"),
                ]
                .into_iter()
                .collect()
            }
        );
        Ok(())
    }
}
