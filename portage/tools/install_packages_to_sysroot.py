#!/usr/bin/env python3
# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

"""A tool to build and install packages to the sysroot."""

import argparse
import json
import logging
import os
import subprocess


_SCRIPT_NAME = os.path.basename(__file__)
_BAZEL_PATH = "/mnt/host/source/chromite/bin/bazel"


def main():
    """The entry point of the program."""
    logging.basicConfig(level=logging.INFO)

    arg_parser = argparse.ArgumentParser(prog=_SCRIPT_NAME)
    arg_parser.add_argument(
        "--board", required=True, help="The target board name."
    )
    arg_parser.add_argument(
        "package_names", nargs="+", help="Names of the packages to install"
    )
    args = arg_parser.parse_args()

    os.environ["BOARD"] = args.board
    workspace_root = subprocess.check_output(
        [_BAZEL_PATH, "info", "workspace"], encoding="utf-8"
    ).strip()

    # Build packages and install lists.
    subprocess.check_call(
        [_BAZEL_PATH, "build"]
        + [
            "@portage//%s:install_list" % package_name
            for package_name in args.package_names
        ],
    )

    # Load install lists.
    # install_lists is a list of lists whose elements are dicts like this:
    # {
    #   "name": "foo/bar-0.0.1.tbz2",
    #   "path": "bazel-out/.../foo/bar/bar-0.0.1.tbz2",
    #   "deps": ["foo/baz-0.0.1.tbz2"],
    # }
    install_lists = []
    for package_name in args.package_names:
        install_list_path = os.path.join(
            workspace_root,
            subprocess.check_output(
                [
                    _BAZEL_PATH,
                    "cquery",
                    "--output=files",
                    "@portage//%s:install_list" % package_name,
                ],
                encoding="utf-8",
            ).strip(),
        )
        with open(install_list_path, encoding="utf-8") as f:
            install_lists.append(json.load(f))

    # Deduplicate dependencies.
    deduped_install_list = {}
    for l in install_lists:
        for package in l:
            deduped_install_list.setdefault(package["name"], package)

    # Calculate install groups.
    remaining_packages = list(deduped_install_list.values())
    seen = set()
    install_groups = []
    while len(remaining_packages) > 0:
        satisfied_list = []
        not_satisfied_list = []
        for package in remaining_packages:
            if all(dep in seen for dep in package["deps"]):
                satisfied_list.append(package)
            else:
                not_satisfied_list.append(package)

        assert len(satisfied_list) != 0
        for package in satisfied_list:
            seen.add(package["name"])

        install_groups.append(satisfied_list)
        remaining_packages = not_satisfied_list

    # Install binary packages.
    for group in install_groups:
        for package in group:
            src_path = os.path.join(workspace_root, package["path"])
            dest_path = os.path.join(
                "/build", args.board, "packages", package["name"]
            )
            dest_dir = os.path.dirname(dest_path)
            subprocess.check_call(["sudo", "mkdir", "-p", dest_dir])
            subprocess.check_call(["sudo", "cp", src_path, dest_path])
            subprocess.check_call(["sudo", "chmod", "644", dest_path])

        atoms = ["=%s" % package["name"].rsplit(".", 1)[0] for package in group]
        subprocess.check_call(
            ["emerge-%s" % args.board, "--usepkgonly", "--nodeps", "--jobs"]
            + atoms,
        )


if __name__ == "__main__":
    main()