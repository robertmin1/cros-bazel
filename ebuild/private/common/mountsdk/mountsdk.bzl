# Copyright 2022 The ChromiumOS Authors.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("//bazel/ebuild/private:common.bzl", "BinaryPackageInfo", "SDKInfo", "relative_path_in_package")

MountSDKDebugInfo = provider(
    "Information required to create a debug target for a mountsdk target",
    fields = dict(
        executable = "The binary to be debugged",
        executable_runfiles = "The runfiles for the executable binary",
        args = "The arguments this package is being run with",
        direct_inputs = "The data required to build this package (eg. srcs)",
        transitive_inputs = "All the packages we transitively depend on.",
    ),
)

def _format_file_arg(file):
    return "--file=%s=%s" % (relative_path_in_package(file), file.path)

def _map_install_group(targets):
    files = []
    for target in targets:
        file = target[BinaryPackageInfo].file
        files.append(file.path)
    return ":".join(files)

def _calculate_install_groups(build_deps):
    seen = {}

    # An ordered list containing a list of deps that can be installed in parallel
    levels = []

    remaining_targets = build_deps.to_list()

    for _ in range(100):
        if len(remaining_targets) == 0:
            break

        satisfied_list = []
        not_satisfied_list = []
        for target in remaining_targets:
            info = target[BinaryPackageInfo]

            all_seen = True
            for runtime_target in info.direct_runtime_deps_targets:
                if not seen.get(runtime_target.label):
                    all_seen = False
                    break

            if all_seen:
                satisfied_list.append(target)
            else:
                not_satisfied_list.append(target)

        if len(satisfied_list) == 0:
            fail("Dependency list is unsatisfiable")

        for target in satisfied_list:
            seen[target.label] = True

        levels.append(satisfied_list)
        remaining_targets = not_satisfied_list

    if len(remaining_targets) > 0:
        fail("Too many dependencies")

    return levels

def create_layer(
        ctx,
        progress_message_name,
        transitive_build_time_deps_files,
        transitive_build_time_deps_targets,
        sdk = None,
        suffix = "-deps"):
    """Creates an action which builds an overlay in which the build dependencies are installed."""
    output_root = ctx.actions.declare_directory(ctx.attr.name + suffix)
    output_symlink_tar = ctx.actions.declare_file(ctx.attr.name + suffix + "-symlinks.tar")
    output_log = ctx.actions.declare_file(ctx.attr.name + suffix + ".log")
    sdk = sdk if sdk else ctx.attr.sdk[SDKInfo]

    args = ctx.actions.args()
    args.add_all([
        "--output=" + output_log.path,
        ctx.executable._install_deps,
        "--board=" + sdk.board,
        "--output-dir=" + output_root.path,
        "--output-symlink-tar=" + output_symlink_tar.path,
    ])

    direct_inputs = []
    transitive_inputs = [transitive_build_time_deps_files]

    args.add_all(sdk.layers, format_each = "--layer=%s", expand_directories = False)
    direct_inputs.extend(sdk.layers)

    for overlay in sdk.overlays.overlays:
        args.add("--layer=%s" % overlay.squashfs_file.path)
        direct_inputs.append(overlay.squashfs_file)

    install_groups = _calculate_install_groups(transitive_build_time_deps_targets)
    args.add_all(install_groups, map_each = _map_install_group, format_each = "--install-target=%s")

    ctx.actions.run(
        inputs = depset(direct_inputs, transitive = transitive_inputs),
        outputs = [output_root, output_symlink_tar, output_log],
        executable = ctx.executable._action_wrapper,
        tools = [ctx.executable._install_deps],
        arguments = [args],
        execution_requirements = {
            # Send SIGTERM instead of SIGKILL on user interruption.
            "supports-graceful-termination": "",
            # Disable sandbox to avoid creating a symlink forest.
            # This does not affect hermeticity since ebuild runs in a container.
            "no-sandbox": "",
        },
        mnemonic = "InstallDeps",
        progress_message = "Installing dependencies for " + progress_message_name,
    )
    return output_root, output_symlink_tar

def mountsdk_generic(ctx, progress_message_name, inputs, binpkg_output_file, outputs, args, install_deps = False, generate_run_action = True):
    sdk = ctx.attr.sdk[SDKInfo]
    args.add_all([
        "--output=" + binpkg_output_file.path,
        "--board=" + sdk.board,
    ])

    direct_inputs = [ctx.executable._builder]
    direct_inputs.extend(inputs)
    transitive_inputs = []

    args.add_all(sdk.layers, format_each = "--layer=%s", expand_directories = False)
    direct_inputs.extend(sdk.layers)

    for file in ctx.attr.files:
        args.add_all(file.files, map_each = _format_file_arg)
        transitive_inputs.append(file.files)

    for distfile, distfile_name in ctx.attr.distfiles.items():
        files = distfile.files.to_list()
        if len(files) != 1:
            fail("cannot refer to multi-file rule in distfiles")
        file = files[0]
        args.add("--distfile=%s=%s" % (distfile_name, file.path))
        direct_inputs.append(file)

    for overlay in sdk.overlays.overlays:
        args.add("--layer=%s" % overlay.squashfs_file.path)
        direct_inputs.append(overlay.squashfs_file)

    for file in ctx.files.srcs:
        args.add("--layer=%s" % file.path)
        direct_inputs.append(file)

    # TODO: Consider target/host transitions.
    transitive_build_time_deps_files = depset(
        # Pull in runtime dependencies of build-time dependencies.
        # TODO: Revisit this logic to see if we can avoid pulling in transitive
        # dependencies.
        transitive = [dep[BinaryPackageInfo].transitive_runtime_deps_files for dep in ctx.attr.build_deps],
        order = "postorder",
    )

    transitive_build_time_deps_targets = depset(
        ctx.attr.build_deps,
        # Pull in runtime dependencies of build-time dependencies.
        # TODO: Revisit this logic to see if we can avoid pulling in transitive
        # dependencies.
        transitive = [dep[BinaryPackageInfo].transitive_runtime_deps_targets for dep in ctx.attr.build_deps],
        order = "postorder",
    )

    if install_deps:
        deps_directory, deps_symlink_tar = create_layer(
            ctx,
            progress_message_name,
            transitive_build_time_deps_files,
            transitive_build_time_deps_targets,
        )
        args.add(deps_directory.path, format = "--layer=%s")
        args.add(deps_symlink_tar.path, format = "--layer=%s")
        transitive_inputs.append(depset([deps_directory, deps_symlink_tar]))
    else:
        transitive_inputs.append(transitive_build_time_deps_files)
        install_groups = _calculate_install_groups(transitive_build_time_deps_targets)
        args.add_all(install_groups, map_each = _map_install_group, format_each = "--install-target=%s")

    transitive_runtime_deps_files = depset(
        [binpkg_output_file],
        transitive = [dep[BinaryPackageInfo].transitive_runtime_deps_files for dep in ctx.attr.runtime_deps],
        order = "postorder",
    )

    transitive_runtime_deps_targets = depset(
        ctx.attr.runtime_deps,
        transitive = [dep[BinaryPackageInfo].transitive_runtime_deps_targets for dep in ctx.attr.runtime_deps],
        order = "postorder",
    )

    if generate_run_action:
        ctx.actions.run(
            inputs = depset(direct_inputs, transitive = transitive_inputs),
            outputs = outputs,
            executable = ctx.executable._builder,
            arguments = [args],
            execution_requirements = {
                # Send SIGTERM instead of SIGKILL on user interruption.
                "supports-graceful-termination": "",
                # Disable sandbox to avoid creating a symlink forest.
                # This does not affect hermeticity since ebuild runs in a container.
                "no-sandbox": "",
                "no-remote": "",
            },
            mnemonic = "Ebuild",
            progress_message = "Building " + progress_message_name,
        )

    return [
        BinaryPackageInfo(
            file = binpkg_output_file,
            transitive_runtime_deps_files = transitive_runtime_deps_files,
            transitive_runtime_deps_targets = transitive_runtime_deps_targets,
            direct_runtime_deps_targets = ctx.attr.runtime_deps,
        ),
        MountSDKDebugInfo(
            executable = ctx.executable._builder,
            executable_runfiles = ctx.attr._builder[DefaultInfo].default_runfiles,
            args = args,
            direct_inputs = direct_inputs,
            transitive_inputs = transitive_inputs,
        ),
    ]

COMMON_ATTRS = dict(
    distfiles = attr.label_keyed_string_dict(
        allow_files = True,
    ),
    srcs = attr.label_list(
        doc = "src files used by the ebuild",
        allow_files = True,
    ),
    build_deps = attr.label_list(
        providers = [BinaryPackageInfo],
    ),
    runtime_deps = attr.label_list(
        providers = [BinaryPackageInfo],
    ),
    files = attr.label_list(
        allow_files = True,
    ),
    sdk = attr.label(
        providers = [SDKInfo],
        mandatory = True,
    ),
    _install_deps = attr.label(
        executable = True,
        cfg = "exec",
        default = Label("//bazel/ebuild/private/cmd/install_deps"),
    ),
)

def _mountsdk_debug_impl(ctx):
    debug_info = ctx.attr.target[MountSDKDebugInfo]

    wrapper = ctx.actions.declare_file(ctx.label.name)

    args = ctx.actions.args()
    args.add_all([wrapper, debug_info.executable])
    ctx.actions.run(
        executable = ctx.executable._create_debug_script,
        arguments = [args, debug_info.args],
        outputs = [wrapper],
    )

    runfiles = ctx.runfiles(transitive_files = depset(debug_info.direct_inputs, transitive = debug_info.transitive_inputs))
    runfiles = runfiles.merge_all([
        debug_info.executable_runfiles,
        ctx.attr._bash_runfiles[DefaultInfo].default_runfiles,
    ])

    return [DefaultInfo(
        files = depset([wrapper]),
        runfiles = runfiles,
        executable = wrapper,
    )]

_mountsdk_debug = rule(
    implementation = _mountsdk_debug_impl,
    attrs = dict(
        target = attr.label(
            providers = [MountSDKDebugInfo],
            mandatory = True,
        ),
        _bash_runfiles = attr.label(default = "@bazel_tools//tools/bash/runfiles"),
        _create_debug_script = attr.label(
            default = "//bazel/ebuild/private/common/mountsdk:create_debug_file",
            executable = True,
            cfg = "exec",
        ),
    ),
    executable = True,
)

# Creates two targets.
# * name: orig_rule(**kwargs).
# * {name}_debug: Something equivalent to the above target, but for use with
#   bazel run instead of bazel build, so you can debug it.
def debuggable_mountsdk(name, orig_rule, **kwargs):
    orig_rule(name = name, **kwargs)
    _mountsdk_debug(
        name = name + "_debug",
        target = name,
        visibility = kwargs.get("visibility", None),
    )
