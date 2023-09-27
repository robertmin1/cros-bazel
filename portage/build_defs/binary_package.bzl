# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("common.bzl", "BinaryPackageInfo", "single_binary_package_set_info")
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

    direct_runtime_deps = [
        target[BinaryPackageInfo]
        for target in ctx.attr.runtime_deps
    ]
    package_info = BinaryPackageInfo(
        file = src,
        contents = contents,
        package_name = ctx.attr.package_name or ctx.label.name,
        category = ctx.attr.category,
        version = ctx.attr.version,
        slot = slot,
        direct_runtime_deps = direct_runtime_deps,
        layer = None,
    )
    package_set_info = single_binary_package_set_info(package_info)
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
            providers = [BinaryPackageInfo],
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

def _add_runtime_deps(ctx):
    binpkg = ctx.attr.binpkg[BinaryPackageInfo]

    info = BinaryPackageInfo(
        file = binpkg.file,
        layer = binpkg.layer,
        contents = binpkg.contents,
        category = binpkg.category,
        package_name = binpkg.package_name,
        version = binpkg.version,
        slot = binpkg.slot,
        direct_runtime_deps = [
            dep[BinaryPackageInfo]
            for dep in ctx.attr.runtime_deps
        ] + list(binpkg.direct_runtime_deps),
    )
    return [
        DefaultInfo(
            files = depset([info.file]),
            runfiles = ctx.runfiles(info.all_files.to_list()),
        ),
        info,
    ]

add_runtime_deps = rule(
    implementation = _add_runtime_deps,
    attrs = dict(
        binpkg = attr.label(providers = [BinaryPackageInfo]),
        runtime_deps = attr.label_list(providers = [BinaryPackageInfo]),
    ),
    provides = [BinaryPackageInfo],
    doc = """
    Adds runtime dependencies to a binary package.
    Useful to add "provided" dependencies to a package (ones that are
    preinstalled in the SDK), so it can be used without the SDK.
    """,
)
