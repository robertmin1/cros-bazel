# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("//bazel/transitions:primordial.bzl", "primordial_transition")
load(":common.bzl", "BinaryPackageInfo", "BinaryPackageSetInfo", "OverlaySetInfo", "SDKInfo")
load(":install_deps.bzl", "install_deps")

def _sdk_from_archive_impl(ctx):
    output_prefix = ctx.attr.out or ctx.attr.name
    output_root = ctx.actions.declare_directory(output_prefix)
    output_log = ctx.actions.declare_file(output_prefix + ".log")
    output_profile = ctx.actions.declare_file(output_prefix + ".profile.json")

    args = ctx.actions.args()
    args.add_all([
        "--log=" + output_log.path,
        "--profile=" + output_profile.path,
        ctx.executable._sdk_from_archive,
        "--input=" + ctx.file.src.path,
        "--output=" + output_root.path,
    ])

    inputs = [ctx.executable._sdk_from_archive, ctx.file.src]
    outputs = [output_root, output_log, output_profile]

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = ctx.executable._action_wrapper,
        tools = [ctx.executable._sdk_from_archive],
        arguments = [args],
        mnemonic = "SdkFromArchive",
        progress_message = ctx.attr.progress_message,
    )

    return [
        DefaultInfo(files = depset(outputs)),
        SDKInfo(
            layers = [output_root],
        ),
    ]

sdk_from_archive = rule(
    implementation = _sdk_from_archive_impl,
    attrs = {
        "out": attr.string(
            doc = "Output directory name. Defaults to the target name.",
        ),
        "progress_message": attr.string(
            default = "Extracting SDK archive",
        ),
        "src": attr.label(
            mandatory = True,
            allow_single_file = True,
        ),
        "_action_wrapper": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/action_wrapper"),
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "_sdk_from_archive": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/sdk_from_archive"),
        ),
    },
    cfg = primordial_transition,
)

def _sdk_update_impl(ctx):
    output_prefix = ctx.attr.out or ctx.attr.name
    output_root = ctx.actions.declare_directory(output_prefix)
    output_log = ctx.actions.declare_file(output_prefix + ".log")
    output_profile = ctx.actions.declare_file(output_prefix + ".profile.json")

    args = ctx.actions.args()
    args.add_all([
        "--log=" + output_log.path,
        "--profile=" + output_profile.path,
        ctx.executable._sdk_update,
        "--output=" + output_root.path,
    ])

    base_sdk = ctx.attr.base[SDKInfo]
    layer_inputs = base_sdk.layers
    args.add_all(layer_inputs, format_each = "--layer=%s", expand_directories = False)

    args.add_all(ctx.files.extra_tarballs, format_each = "--install-tarball=%s")

    inputs = depset(
        [ctx.executable._sdk_update] + layer_inputs + ctx.files.extra_tarballs,
    )

    outputs = [output_root, output_log, output_profile]

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = ctx.executable._action_wrapper,
        tools = [ctx.executable._sdk_update],
        arguments = [args],
        execution_requirements = {
            # Disable sandbox to avoid creating a symlink forest.
            # This does not affect hermeticity since sdk_update runs in a container.
            "no-sandbox": "",
            # Send SIGTERM instead of SIGKILL on user interruption.
            "supports-graceful-termination": "",
        },
        mnemonic = "SdkUpdate",
        progress_message = "Building %{label}",
    )

    return [
        DefaultInfo(files = depset(outputs)),
        SDKInfo(
            layers = base_sdk.layers + [output_root],
        ),
    ]

sdk_update = rule(
    implementation = _sdk_update_impl,
    attrs = {
        "base": attr.label(
            mandatory = True,
            providers = [SDKInfo],
        ),
        "extra_tarballs": attr.label_list(
            allow_files = True,
        ),
        "out": attr.string(
            doc = "Output directory name. Defaults to the target name.",
        ),
        "progress_message": attr.string(
            doc = """
            Progress message for this target.
            If the message contains `{dep_count}' it will be replaced with the
            total number of dependencies that need to be installed.
            """,
            default = "Updating SDK",
        ),
        "_action_wrapper": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/action_wrapper"),
        ),
        "_allowlist_function_transition": attr.label(
            default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
        ),
        "_sdk_update": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/sdk_update"),
        ),
    },
    cfg = primordial_transition,
)

def _sdk_install_deps_impl(ctx):
    sdk = ctx.attr.base[SDKInfo]

    install_set = depset(
        transitive = [dep[BinaryPackageSetInfo].packages for dep in ctx.attr.target_deps],
        order = "postorder",
    )

    if "{dep_count}" in ctx.attr.progress_message:
        progress_message = ctx.attr.progress_message.replace(
            "{dep_count}",
            str(len(install_set.to_list())),
        )
    else:
        progress_message = ctx.attr.progress_message

    outputs = install_deps(
        ctx = ctx,
        output_prefix = ctx.attr.out or ctx.attr.name,
        board = ctx.attr.board,
        sdk = sdk,
        overlays = ctx.attr.overlays[OverlaySetInfo],
        install_set = install_set,
        executable_action_wrapper = ctx.executable._action_wrapper,
        executable_install_deps = ctx.executable._install_deps,
        progress_message = progress_message,
    )

    return [
        DefaultInfo(files = depset(outputs)),
        SDKInfo(
            layers = sdk.layers + outputs,
        ),
    ]

sdk_install_deps = rule(
    implementation = _sdk_install_deps_impl,
    attrs = {
        "base": attr.label(
            doc = """
            Base SDK to derive a new SDK from.
            """,
            mandatory = True,
            providers = [SDKInfo],
        ),
        "board": attr.string(
            doc = """
            If set, the packages are installed into the board's sysroot,
            otherwise they are installed into the host's sysroot.
            """,
        ),
        "out": attr.string(
            doc = "Output directory name. Defaults to the target name.",
        ),
        "overlays": attr.label(
            providers = [OverlaySetInfo],
            mandatory = True,
        ),
        "progress_message": attr.string(
            doc = """
            Progress message for this target.
            If the message contains `{dep_count}' it will be replaced with the
            total number of dependencies that need to be installed.
            """,
            default = "Installing {dep_count} packages into %{label}",
        ),
        "target_deps": attr.label_list(
            doc = """
            Target packages to install in the SDK.
            """,
            providers = [BinaryPackageSetInfo],
        ),
        "_action_wrapper": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/action_wrapper"),
        ),
        "_install_deps": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/install_deps"),
        ),
    },
)

def _sdk_extend_impl(ctx):
    sdk = ctx.attr.base[SDKInfo]

    sdk = SDKInfo(
        layers = sdk.layers + ctx.files.extra_tarballs,
    )

    return [
        DefaultInfo(files = depset(sdk.layers)),
        sdk,
    ]

sdk_extend = rule(
    doc = "Adds extra tarballs to the SDK",
    implementation = _sdk_extend_impl,
    provides = [SDKInfo],
    attrs = {
        "base": attr.label(
            doc = """
            Base SDK to derive a new SDK from.
            """,
            mandatory = True,
            providers = [SDKInfo],
        ),
        "extra_tarballs": attr.label_list(
            allow_files = True,
            mandatory = True,
            doc = """
            Extra files to layer onto the base SDK.
            """,
        ),
    },
)

def _sdk_install_glibc_impl(ctx):
    output_prefix = ctx.attr.out or ctx.attr.name
    output_root = ctx.actions.declare_directory(output_prefix)
    output_log = ctx.actions.declare_file(output_prefix + ".log")
    output_profile = ctx.actions.declare_file(output_prefix + ".profile.json")

    args = ctx.actions.args()
    args.add_all([
        "--log=" + output_log.path,
        "--profile=" + output_profile.path,
        ctx.executable._sdk_install_glibc,
        "--output=" + output_root.path,
        "--board=" + ctx.attr.board,
    ])

    base_sdk = ctx.attr.base[SDKInfo]
    layer_inputs = base_sdk.layers
    args.add_all(layer_inputs, format_each = "--layer=%s", expand_directories = False)

    glibc = ctx.attr.glibc[BinaryPackageInfo].file
    args.add("--glibc", glibc)

    inputs = depset(
        [ctx.executable._sdk_install_glibc] + layer_inputs + [glibc],
    )

    outputs = [output_root, output_log, output_profile]

    ctx.actions.run(
        inputs = inputs,
        outputs = outputs,
        executable = ctx.executable._action_wrapper,
        tools = [ctx.executable._sdk_install_glibc],
        arguments = [args],
        execution_requirements = {
            # Disable sandbox to avoid creating a symlink forest.
            # This does not affect hermeticity since sdk_install_glibc runs in a container.
            "no-sandbox": "",
            # Send SIGTERM instead of SIGKILL on user interruption.
            "supports-graceful-termination": "",
        },
        mnemonic = "SdkInstallGlibc",
        progress_message = "Installing cross glibc into %{label}",
    )

    return [
        DefaultInfo(files = depset(outputs)),
        SDKInfo(
            layers = base_sdk.layers + [output_root],
        ),
    ]

sdk_install_glibc = rule(
    implementation = _sdk_install_glibc_impl,
    attrs = {
        "base": attr.label(
            mandatory = True,
            providers = [SDKInfo],
        ),
        "board": attr.string(
            doc = "The cross-* package is installed into the board's sysroot.",
            mandatory = True,
        ),
        "glibc": attr.label(
            doc = "The cross-*-cros-linux-gnu/glibc package to install",
            mandatory = True,
            providers = [BinaryPackageInfo],
        ),
        "out": attr.string(
            doc = "Output directory name. Defaults to the target name.",
        ),
        "_action_wrapper": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/action_wrapper"),
        ),
        "_sdk_install_glibc": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/sdk_install_glibc"),
        ),
    },
)