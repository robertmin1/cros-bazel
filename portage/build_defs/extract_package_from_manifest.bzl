# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("//bazel/build_defs:always_fail.bzl", "always_fail")
load(":extract_package_from_manifest/update_manifest.bzl", "update_manifest")

visibility("public")

def extract_package(name, pkg, manifest_file, ld_library_path_regexes = [], header_file_dir_regexes = [], manifest_content = None):
    """Extracts files from a tbz2 file to one usable by bazel.

    Args:
      name: (str) The name of the target.
      pkg: (Label) Binary package to extract the interface from.
      manifest_file: (File) A .bzl file generated by extract_interface.
        Create an empty file for the initial invocation.
      ld_library_path_regexes: (List[str]) Regexes for directories containing
        shared libraries.
      header_file_dir_regexes: (List[str]) Regexes for directories containing header files.
      manifest_content: (Autogenerated Dict) The content of the manifest.
    """
    manifest_regenerate_command = "bazel run %s" % native.package_relative_label(":%s_update" % name)

    update_manifest(
        name = "%s_update" % name,
        manifest_file = manifest_file,
        ld_library_path_regexes = ld_library_path_regexes,
        header_file_dir_regexes = header_file_dir_regexes,
        manifest_regenerate_command = manifest_regenerate_command,
        pkg = pkg,
    )

    if manifest_content == None:
        always_fail(
            name = name,
            message = "Run %s" % manifest_regenerate_command,
        )
    else:
        # TODO: Create a rule to extract the package
        pass
