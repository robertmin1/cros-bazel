# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("//bazel/portage/build_defs:common.bzl", "BinaryPackageSetInfo", "OverlaySetInfo", "SDKInfo")
load("//bazel/portage/build_defs:install_deps.bzl", "install_deps")

def _build_image_impl(ctx):
    # Declare outputs.
    output_image_file = ctx.actions.declare_file(
        ctx.attr.output_image_file_name + ".bin",
    )
    output_log_file = ctx.actions.declare_file(
        ctx.attr.output_image_file_name + ".log",
    )
    output_profile_file = ctx.actions.declare_file(
        ctx.attr.output_image_file_name + ".profile.json",
    )

    sdk = ctx.attr.sdk[SDKInfo]
    overlays = ctx.attr.overlays[OverlaySetInfo]

    # Install all target dependencies to the SDK.
    install_set = depset(
        transitive = [
            packages[BinaryPackageSetInfo].packages
            for packages in ctx.attr.target_packages
        ],
        order = "postorder",
    )
    deps_layers, logs, traces = install_deps(
        ctx = ctx,
        output_prefix = ctx.attr.output_image_file_name + "-deps",
        board = ctx.attr.board,
        sdk = sdk,
        overlays = overlays,
        portage_configs = ctx.files.portage_config,
        install_set = install_set,
        strategy = "slow",
        executable_action_wrapper = ctx.executable._action_wrapper,
        executable_install_deps = ctx.executable._install_deps,
        executable_fast_install_packages =
            ctx.executable._fast_install_packages,
        progress_message = "Setting up SDK to build image",
    )

    # Compute arguments and inputs to build_image.
    args = ctx.actions.args()
    direct_inputs = []
    transitive_inputs = []

    args.add_all([
        "--output=" + output_image_file.path,
        "--board=" + ctx.attr.board,
        "--image-to-build=" + ctx.attr.image_to_build,
        "--image-file-name=" + ctx.attr.image_file_name,
    ])

    args.add_all(
        sdk.layers + deps_layers + overlays.layers,
        format_each = "--layer=%s",
        expand_directories = False,
    )
    direct_inputs.extend(sdk.layers + deps_layers + overlays.layers)

    args.add_all(ctx.files.files, format_each = "--layer=%s", expand_directories = False)
    direct_inputs.extend(ctx.files.files)

    target_package_files = depset(
        transitive = [
            packages[BinaryPackageSetInfo].files
            for packages in ctx.attr.target_packages
        ],
    )
    args.add_all(target_package_files, format_each = "--target-package=%s")
    transitive_inputs.append(target_package_files)

    host_package_files = depset(
        transitive = [
            packages[BinaryPackageSetInfo].files
            for packages in ctx.attr.host_packages
        ],
    )
    args.add_all(host_package_files, format_each = "--host-package=%s")
    transitive_inputs.append(target_package_files)

    if ctx.attr.override_base_packages:
        args.add_all(ctx.attr.override_base_packages, format_each = "--override-base-package=%s")

    inputs = depset(direct_inputs, transitive = transitive_inputs)

    # Define the main action.
    ctx.actions.run(
        inputs = inputs,
        outputs = [output_image_file, output_log_file, output_profile_file],
        executable = ctx.executable._action_wrapper,
        tools = [ctx.executable._build_image],
        arguments = [
            "--log=" + output_log_file.path,
            "--profile=" + output_profile_file.path,
            "--privileged",
            "--privileged-output=" + output_image_file.path,
            ctx.executable._build_image.path,
            args,
        ],
        execution_requirements = {
            # Send SIGTERM instead of SIGKILL on user interruption.
            "supports-graceful-termination": "",
            # Disable sandbox to avoid creating a symlink forest.
            # This does not affect hermeticity since ebuild runs in a container.
            "no-sandbox": "",
            "no-remote": "",
        },
        progress_message = "Building " + output_image_file.basename,
    )

    return [
        DefaultInfo(files = depset([output_image_file])),
        OutputGroupInfo(
            logs = depset([output_log_file] + logs),
            traces = depset([output_profile_file] + traces),
        ),
    ]

build_image = rule(
    implementation = _build_image_impl,
    doc = "Builds a ChromeOS image.",
    attrs = dict(
        image_to_build = attr.string(
            doc = """
            The name of the image to build (e.g. "base", "dev", or "test").
            """,
            mandatory = True,
        ),
        image_file_name = attr.string(
            doc = """
            The name of the image file generated by build_image script (e.g. "chromiumos_base_image").
            """,
            mandatory = True,
        ),
        output_image_file_name = attr.string(
            doc = """
            The name of the output image file (e.g. "chromiumos_base_image").
            """,
            mandatory = True,
        ),
        target_packages = attr.label_list(
            providers = [BinaryPackageSetInfo],
            mandatory = True,
            doc = """
            Packages included in the image.
            """,
        ),
        host_packages = attr.label_list(
            providers = [BinaryPackageSetInfo],
            allow_empty = True,
            doc = """
            Host binary packages required by chromite's build_image script.
            """,
        ),
        override_base_packages = attr.string_list(
            allow_empty = True,
            doc = """
            Overrides packages to install on the base image. If empty,
            virtual/target-os is selected.
            """,
        ),
        files = attr.label_list(
            allow_files = True,
            doc = """
            Extra files to be made available in the ephemeral chroot.
            """,
        ),
        board = attr.string(
            mandatory = True,
            doc = """
            The target board name to build the package for.
            """,
        ),
        sdk = attr.label(
            providers = [SDKInfo],
            mandatory = True,
        ),
        overlays = attr.label(
            providers = [OverlaySetInfo],
            mandatory = True,
        ),
        portage_config = attr.label_list(
            providers = [PackageArtifactInfo],
            doc = """
            The portage config for the host and the target. This should
            at minimum contain a make.conf file.
            """,
            mandatory = True,
        ),
        _action_wrapper = attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/action_wrapper"),
        ),
        _build_image = attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/build_image"),
        ),
        _install_deps = attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/install_deps"),
        ),
        _fast_install_packages = attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/fast_install_packages"),
        ),
    ),
)
