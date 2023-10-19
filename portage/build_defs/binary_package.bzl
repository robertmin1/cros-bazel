# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("common.bzl", "BinaryPackageInfo", "BinaryPackageSetInfo", "single_binary_package_set_info")
load("package_contents.bzl", "generate_contents")

def _binary_package_impl(ctx):
    src = ctx.file.src
    src_basename = src.basename.rsplit(".", 1)[0]

    slot = ctx.attr.slot

    contents = generate_contents(
        ctx = ctx,
        binary_package = src,
        output_prefix = src_basename,
        # Currently all usage of the binary_package rule is for host packages.
        board = "",
        executable_action_wrapper = ctx.executable._action_wrapper,
        executable_extract_package = ctx.executable._extract_package,
    )

    package_info = BinaryPackageInfo(
        file = src,
        contents = contents,
        package_name = ctx.attr.package_name or ctx.label.name,
        category = ctx.attr.category,
        version = ctx.attr.version,
        slot = slot,
        direct_runtime_deps = tuple([
            target[BinaryPackageInfo].file
            for target in ctx.attr.runtime_deps
        ]),
        layer = None,
    )
    package_set_info = single_binary_package_set_info(
        package_info,
        [
            target[BinaryPackageSetInfo]
            for target in ctx.attr.runtime_deps
        ],
    )
    return [
        DefaultInfo(files = depset([src])),
        package_info,
        package_set_info,
    ]

binary_package = rule(
    implementation = _binary_package_impl,
    attrs = {
        "category": attr.string(mandatory = True),
        "package_name": attr.string(mandatory = True),
        "runtime_deps": attr.label_list(
            providers = [BinaryPackageInfo, BinaryPackageSetInfo],
        ),
        "src": attr.label(
            mandatory = True,
            allow_single_file = [".tbz2"],
        ),
        "version": attr.string(mandatory = True),
        "slot": attr.string(default = "0/0"),
        "_action_wrapper": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/action_wrapper"),
        ),
        "_extract_package": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/extract_package"),
        ),
    },
)

def _replace_runtime_deps(ctx):
    original_package_info = ctx.attr.binpkg[BinaryPackageInfo]
    original_package_set_info = ctx.attr.binpkg[BinaryPackageSetInfo]

    package_info = BinaryPackageInfo(
        file = original_package_info.file,
        layer = original_package_info.layer,
        contents = original_package_info.contents,
        category = original_package_info.category,
        package_name = original_package_info.package_name,
        version = original_package_info.version,
        slot = original_package_info.slot,
        direct_runtime_deps = tuple([
            dep[BinaryPackageInfo].file
            for dep in ctx.attr.runtime_deps
        ]),
    )
    package_set_info = single_binary_package_set_info(
        package_info,
        [
            target[BinaryPackageSetInfo]
            for target in ctx.attr.runtime_deps
        ],
    )
    return [
        DefaultInfo(
            files = depset([package_info.file]),
            runfiles = ctx.runfiles(package_set_info.files.to_list()),
        ),
        package_info,
        package_set_info,
    ]

replace_runtime_deps = rule(
    implementation = _replace_runtime_deps,
    attrs = dict(
        binpkg = attr.label(providers = [BinaryPackageInfo, BinaryPackageSetInfo]),
        runtime_deps = attr.label_list(providers = [BinaryPackageInfo, BinaryPackageSetInfo]),
    ),
    provides = [BinaryPackageInfo, BinaryPackageSetInfo],
    doc = """
    Replaces runtime dependencies to a binary package.
    Useful to substitute "provided" dependencies to a package (ones that are
    preinstalled in the SDK), so it can be used without the SDK.
    """,
)
