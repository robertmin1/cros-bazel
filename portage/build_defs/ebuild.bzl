# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("@bazel_skylib//lib:paths.bzl", "paths")
load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load("@rules_pkg//pkg:providers.bzl", "PackageArtifactInfo")
load("//bazel/bash:defs.bzl", "BASH_RUNFILES_ATTR", "wrap_binary_with_args")
load("//bazel/portage/build_defs:common.bzl", "BashrcInfo", "BinaryPackageInfo", "BinaryPackageSetInfo", "EbuildLibraryInfo", "OverlayInfo", "OverlaySetInfo", "SDKInfo", "compute_input_file_path", "relative_path_in_package", "single_binary_package_set_info")
load("//bazel/portage/build_defs:install_groups.bzl", "calculate_install_groups")
load("//bazel/portage/build_defs:interface_lib.bzl", "add_interface_library_args", "generate_interface_libraries")
load("//bazel/portage/build_defs:package_contents.bzl", "generate_contents")
load("//bazel/transitions:primordial.bzl", "primordial_transition")

# The stage1 SDK will need to be built with ebuild_primordial.
# After that, they can use the ebuild rule.
# This ensures that we don't build the stage1 targets twice.
def maybe_primordial_rule(attrs, **kwargs):
    return (
        rule(attrs = attrs, **kwargs),
        rule(cfg = primordial_transition, attrs = dict(
            _allowlist_function_transition = attr.label(
                default = "@bazel_tools//tools/allowlists/function_transition_allowlist",
            ),
            **attrs
        ), **kwargs),
    )

# Attributes common to the `ebuild`/`ebuild_debug`/`ebuild_test` rule.
_EBUILD_COMMON_ATTRS = dict(
    ebuild = attr.label(
        mandatory = True,
        allow_single_file = [".ebuild"],
    ),
    overlay = attr.label(
        mandatory = True,
        providers = [OverlayInfo],
        doc = """
        The overlay this package belongs to.
        """,
    ),
    eclasses = attr.label_list(
        providers = [PackageArtifactInfo],
        doc = """
        The eclasses this package inherits from (including transitive ones).
        """,
    ),
    category = attr.string(
        mandatory = True,
        doc = """
        The category of this package.
        """,
    ),
    package_name = attr.string(
        mandatory = True,
        doc = """
        The name of this package.
        """,
    ),
    version = attr.string(
        mandatory = True,
        doc = """
        The version of this package.
        """,
    ),
    slot = attr.string(
        mandatory = True,
        doc = """
        The slot the package is installed to.
        """,
    ),
    distfiles = attr.label_keyed_string_dict(
        allow_files = True,
    ),
    srcs = attr.label_list(
        doc = "src files used by the ebuild",
        allow_files = True,
    ),
    cache_srcs = attr.label_list(
        doc = "Cache files used by the ebuild",
        allow_files = True,
    ),
    git_trees = attr.label_list(
        doc = """
        The git tree objects listed in the CROS_WORKON_TREE variable.
        """,
        allow_empty = True,
        allow_files = True,
    ),
    use_flags = attr.string_list(
        allow_empty = True,
        doc = """
        The USE flags used to build the package.
        """,
    ),
    inject_use_flags = attr.bool(
        default = False,
        doc = """
        Inject the USE flags into the container as opposed to letting portage
        compute them.
        """,
    ),
    files = attr.label_list(
        allow_files = True,
    ),
    runtime_deps = attr.label_list(
        providers = [BinaryPackageInfo, BinaryPackageSetInfo],
    ),
    shared_lib_deps = attr.label_list(
        doc = """
        The shared libraries this target will link against.
        """,
        providers = [EbuildLibraryInfo],
    ),
    allow_network_access = attr.bool(
        default = False,
        doc = """
        Allows the build process to access the network. This should be True only
        when the package explicitly requests network access, e.g.
        RESTRICT=network-sandbox.
        """,
    ),
    board = attr.string(
        doc = """
        The target board name to build the package for. If unset, then the host
        will be targeted.
        """,
    ),
    incremental_cache_marker = attr.label(
        allow_single_file = True,
        doc = """
        Marker file for the directory for incremental build caches.
        Cache directories are created as siblings of the marker file.

        If set, mounts a persistent directory for the ebuild to reuse
        build artifacts across multiple Bazel orchestrated ebuilds invocations.
        This allows incremental builds for the internal build system
        such as make, ninja, etc.

        If unset, no cache is persisted between ebuild invocations.
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
        The portage config for the host and optionally the target board. This
        should at minimum contain a make.conf file.
        """,
        mandatory = True,
    ),
    bashrcs = attr.label_list(
        providers = [BashrcInfo],
        doc = """
        The bashrc files to execute for the package.
        """,
    ),
    _action_wrapper = attr.label(
        executable = True,
        cfg = "exec",
        default = Label("//bazel/portage/bin/action_wrapper"),
    ),
    _install_deps = attr.label(
        executable = True,
        cfg = "exec",
        default = Label("//bazel/portage/bin/install_deps"),
    ),
    _build_package = attr.label(
        executable = True,
        cfg = "exec",
        default = Label("//bazel/portage/bin/build_package"),
    ),
    _goma_info = attr.label(
        allow_single_file = True,
        default = Label("@goma_info//:goma_info"),
    ),
    _remoteexec_info = attr.label(
        allow_single_file = True,
        default = Label("@remoteexec_info//:remoteexec_info"),
    ),
)

def _bashrc_to_path(bashrc):
    return bashrc[BashrcInfo].path

# TODO(b/269558613): Fix all call sites to always use runfile paths and delete `for_test`.
def _compute_build_package_args(ctx, output_path, use_runfiles):
    """
    Computes the arguments to run build_package.

    These arguments should be passed to action_wrapper, not build_package. They
    contain the path to the build_package executable itself, and also may start
    with options to action_wrapper (e.g. --privileged).

    This function can be called only from `ebuild`, `ebuild_debug`, and
    `ebuild_test`. Particularly, the current rule must include
    _EBUILD_COMMON_ATTRS in its attribute definition.

    Args:
        ctx: ctx: A context objected passed to the rule implementation.
        output_path: Optional[str]: A file path where an output binary package
            file is saved. If None, a binary package file is not saved.
        use_runfiles: bool: Whether to refer to input file paths in relative to
            execroot or runfiles directory. See compute_input_file_path for
            details.

    Returns:
        (args, inputs) where:
            args: Args: Arguments to pass to action_wrapper.
            inputs: Depset[File]: Inputs to action_wrapper.
    """
    args = ctx.actions.args()
    direct_inputs = []
    transitive_inputs = []

    # Define formatting functions for Args.add_all. Avoid defining them in a
    # loop to avoid memory bloat.
    def format_file_arg(file):
        return "--file=%s=%s" % (relative_path_in_package(file), compute_input_file_path(file, use_runfiles))

    def format_layer_arg(file):
        return "--layer=%s" % compute_input_file_path(file, use_runfiles)

    def format_git_tree_arg(file):
        return "--git-tree=%s" % compute_input_file_path(file, use_runfiles)

    # Path to build_package
    args.add(compute_input_file_path(ctx.executable._build_package, use_runfiles))

    # Basic arguments
    if ctx.attr.board:
        args.add("--board=" + ctx.attr.board)
    if output_path:
        args.add("--output=" + output_path)

    # We extract the <category>/<package>/<ebuild> from the file path.
    relative_ebuild_path = "/".join(ctx.file.ebuild.path.rsplit("/", 3)[1:4])
    ebuild_inside_path = "%s/%s" % (ctx.attr.overlay[OverlayInfo].path, relative_ebuild_path)

    # --ebuild
    args.add("--ebuild=%s=%s" % (ebuild_inside_path, compute_input_file_path(ctx.file.ebuild, use_runfiles)))
    direct_inputs.append(ctx.file.ebuild)

    # --file
    for file in ctx.attr.files:
        args.add_all(file.files, map_each = format_file_arg, allow_closure = True)
        transitive_inputs.append(file.files)

    # --distfile
    for distfile, distfile_name in ctx.attr.distfiles.items():
        files = distfile.files.to_list()
        if len(files) != 1:
            fail("cannot refer to multi-file rule in distfiles")
        file = files[0]
        args.add("--distfile=%s=%s" % (distfile_name, compute_input_file_path(file, use_runfiles)))
        direct_inputs.append(file)

    # --layer for SDK, overlays and eclasses
    sdk = ctx.attr.sdk[SDKInfo]
    overlays = ctx.attr.overlays[OverlaySetInfo]
    layer_inputs = (
        sdk.layers +
        overlays.layers +
        ctx.files.eclasses +
        ctx.files.portage_config +
        ctx.files.bashrcs
    )
    args.add_all(layer_inputs, map_each = format_layer_arg, expand_directories = False, allow_closure = True)
    direct_inputs.extend(layer_inputs)

    # --layer for source code
    for file in ctx.files.srcs:
        args.add("--layer=%s" % compute_input_file_path(file, use_runfiles))
        direct_inputs.append(file)

    # --layer for cache files
    # NOTE: We're not adding this file to transitive_inputs because the contents of cache files shouldn't affect the build output.
    for file in ctx.files.cache_srcs:
        args.add("--layer=%s" % compute_input_file_path(file, use_runfiles))

    # --git-tree
    args.add_all(ctx.files.git_trees, map_each = format_git_tree_arg, allow_closure = True)
    direct_inputs.extend(ctx.files.git_trees)

    # --allow-network-access
    if ctx.attr.allow_network_access:
        args.add("--allow-network-access")

    # --incremental-cache-dir
    if ctx.file.incremental_cache_marker:
        # Use the cache marker file to resolve the cache directory.
        # The caches are not exposed to Bazel as inputs as they are
        # volatile and are not supposed to use as action cache keys.
        # NOTE: build_package assumes the directory is writable.
        # TODO(b/308409815): Make this more robust.
        # See https://crrev.com/c/4989046/comment/196dbd8c_c044dfc0/.
        caches_dir = paths.dirname(compute_input_file_path(ctx.file.incremental_cache_marker, use_runfiles))
        args.add("--incremental-cache-dir=%s/portage" % caches_dir)

    # --use-flags
    if ctx.attr.inject_use_flags:
        args.add_joined("--use-flags", ctx.attr.use_flags, join_with = ",")

    # --goma-info
    # NOTE: We're not adding this file to transitive_inputs because the contents of goma_info shouldn't affect the build output.
    args.add("--goma-info=%s" % ctx.file._goma_info.path)

    # --remoteexec-info
    # NOTE: We're not adding this file to transitive_inputs because the contents of remoteexec_info shouldn't affect the build output.
    args.add("--remoteexec-info=%s" % ctx.file._remoteexec_info.path)

    args.add_all(ctx.attr.bashrcs, before_each = "--bashrc", map_each = _bashrc_to_path)

    # Consume interface libraries.
    interface_library_inputs = add_interface_library_args(
        input_targets = ctx.attr.shared_lib_deps,
        args = args,
        use_runfiles = use_runfiles,
    )
    transitive_inputs.append(interface_library_inputs)

    # Include runfiles in the inputs.
    transitive_inputs.append(ctx.attr._action_wrapper[DefaultInfo].default_runfiles.files)
    transitive_inputs.append(ctx.attr._build_package[DefaultInfo].default_runfiles.files)

    inputs = depset(direct_inputs, transitive = transitive_inputs)
    return args, inputs

def _download_prebuilt(ctx, prebuilt, output_binary_package_file):
    if prebuilt.startswith("http://") or prebuilt.startswith("https://"):
        executable = "wget"
        args = [prebuilt, "-O", output_binary_package_file.path]
    elif prebuilt.startswith("gs://"):
        executable = Label("@chromite//:src").workspace_root + "/bin/gsutil"
        args = ["cp", prebuilt, output_binary_package_file.path]
    else:
        executable = "cp"
        args = [prebuilt, output_binary_package_file.path]

    ctx.actions.run(
        inputs = [],
        outputs = [output_binary_package_file],
        executable = executable,
        arguments = args,
        execution_requirements = {
            "no-remote": "",
            "no-sandbox": "",
            "requires-network": "",
        },
        progress_message = "Downloading %s" % prebuilt,
    )

def _get_basename(ctx):
    src_basename = ctx.file.ebuild.basename.rsplit(".", 1)[0]
    if ctx.attr.suffix:
        src_basename += ctx.attr.suffix

    return src_basename

def _generate_ebuild_validation_action(ctx, binpkg):
    src_basename = _get_basename(ctx)

    validation_file = ctx.actions.declare_file(src_basename + ".validation")

    args = ctx.actions.args()
    args.add_all([
        "validate-package",
        "--touch",
        validation_file,
        "--package",
        binpkg,
    ])
    args.add_joined("--use-flags", ctx.attr.use_flags, join_with = ",", omit_if_empty = False)

    ctx.actions.run(
        inputs = depset([binpkg]),
        outputs = [validation_file],
        executable = ctx.executable._xpaktool,
        arguments = [args],
        mnemonic = "EbuildValidation",
        progress_message = "Building %{label}",
    )

    return validation_file

def _ebuild_compare_package(ctx, name, packages):
    if len(packages) != 2:
        fail("Expected two packages, got %d" % (len(packages)))

    src_basename = _get_basename(ctx)

    log_file = ctx.actions.declare_file("%s.%s.log" % (src_basename, name))

    args = ctx.actions.args()
    args.add("--log", log_file)
    args.add(compute_input_file_path(ctx.executable._xpaktool, use_runfiles = False))
    args.add("compare-packages")
    args.add_all(packages)

    ctx.actions.run(
        inputs = packages,
        outputs = [log_file],
        executable = ctx.executable._action_wrapper,
        tools = [ctx.executable._xpaktool],
        arguments = [args],
        mnemonic = "EbuildComparePackage",
    )

    return log_file

def _ebuild_impl(ctx):
    src_basename = _get_basename(ctx)

    # Declare outputs.
    output_binary_package_file = ctx.actions.declare_file(
        src_basename + ".tbz2",
    )
    output_log_file = ctx.actions.declare_file(src_basename + ".log")
    output_profile_file = ctx.actions.declare_file(
        src_basename + ".profile.json",
    )

    # Compute arguments and inputs to run build_package.
    args, inputs = _compute_build_package_args(ctx, output_path = output_binary_package_file.path, use_runfiles = False)

    # Define the main action.
    prebuilt = ctx.attr.prebuilt[BuildSettingInfo].value
    if prebuilt:
        _download_prebuilt(ctx, prebuilt, output_binary_package_file)
        ctx.actions.write(output_log_file, "Downloaded from %s\n" % prebuilt)
        ctx.actions.write(output_profile_file, "[]")
    else:
        ctx.actions.run(
            inputs = inputs,
            outputs = [
                output_binary_package_file,
                output_log_file,
                output_profile_file,
            ],
            executable = ctx.executable._action_wrapper,
            tools = [ctx.executable._build_package],
            arguments = [
                "--log=" + output_log_file.path,
                "--profile=" + output_profile_file.path,
                args,
            ],
            execution_requirements = {
                # Disable sandbox to avoid creating a symlink forest.
                # This does not affect hermeticity since ebuild runs in a container.
                "no-sandbox": "",
                # Send SIGTERM instead of SIGKILL on user interruption.
                "supports-graceful-termination": "",
            },
            mnemonic = "Ebuild",
            progress_message = "Building %{label}",
        )

    # Generate contents directories.
    contents = generate_contents(
        ctx = ctx,
        binary_package = output_binary_package_file,
        output_prefix = src_basename,
        board = ctx.attr.board,
        executable_action_wrapper = ctx.executable._action_wrapper,
        executable_extract_package = ctx.executable._extract_package,
    )

    # Generate interface libraries.
    interface_library_outputs, interface_library_providers = generate_interface_libraries(
        ctx = ctx,
        input_binary_package_file = output_binary_package_file,
        output_base_dir = src_basename,
        headers = ctx.attr.headers,
        pkg_configs = ctx.attr.pkg_configs,
        shared_libs = ctx.attr.shared_libs,
        static_libs = ctx.attr.static_libs,
        extract_interface_executable = ctx.executable._extract_interface,
        action_wrapper_executable = ctx.executable._action_wrapper,
    )

    # Compute provider data.
    package_info = BinaryPackageInfo(
        file = output_binary_package_file,
        contents = contents,
        category = ctx.attr.category,
        package_name = ctx.attr.package_name,
        version = ctx.attr.version,
        slot = ctx.attr.slot,
        direct_runtime_deps = tuple([
            target[BinaryPackageInfo].file
            for target in ctx.attr.runtime_deps
        ]),
    )

    package_set_info = single_binary_package_set_info(
        package_info,
        [
            target[BinaryPackageSetInfo]
            for target in ctx.attr.runtime_deps
        ],
    )

    validation_files = [
        _generate_ebuild_validation_action(ctx, output_binary_package_file),
    ]

    if ctx.attr.portage_profile_test_package:
        validation_files.append(
            _ebuild_compare_package(
                ctx,
                "portage-profile-test",
                [
                    ctx.attr.portage_profile_test_package[BinaryPackageInfo].file,
                    output_binary_package_file,
                ],
            ),
        )

    return [
        DefaultInfo(files = depset(
            [output_binary_package_file] +
            interface_library_outputs,
        )),
        OutputGroupInfo(
            logs = depset([output_log_file]),
            traces = depset([output_profile_file]),
            _validation = depset(validation_files),
        ),
        package_info,
        package_set_info,
    ] + interface_library_providers

ebuild, ebuild_primordial = maybe_primordial_rule(
    implementation = _ebuild_impl,
    doc = "Builds a Portage binary package from an ebuild file.",
    attrs = dict(
        headers = attr.string_list(
            allow_empty = True,
            doc = """
            The path inside the binpkg that contains the public C headers
            exported by this library.
            """,
        ),
        pkg_configs = attr.string_list(
            allow_empty = True,
            doc = """
            The path inside the binpkg that contains the pkg-config
            (man 1 pkg-config) `pc` files exported by this package.
            The `pc` is used to look up the CFLAGS and LDFLAGS required to link
            to the library.
            """,
        ),
        shared_libs = attr.string_list(
            allow_empty = True,
            doc = """
            The path inside the binpkg that contains shared object libraries.
            """,
        ),
        static_libs = attr.string_list(
            allow_empty = True,
            doc = """
            The path inside the binpkg that contains static libraries.
            """,
        ),
        suffix = attr.string(
            doc = """
            Suffix to add to the output file. i.e., libcxx-17.0-r15<suffix>.tbz2
            """,
        ),
        prebuilt = attr.label(providers = [BuildSettingInfo]),
        portage_profile_test_package = attr.label(
            doc = """
            A package built using the standard portage profile configuration.

            Setting this field will add a validator that compares this package
            to the one using standard portage profiles. This is useful to
            validate that alchemist's compiled profiles are valid.
            """,
            providers = [BinaryPackageInfo],
        ),
        _extract_package = attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/extract_package"),
        ),
        _extract_interface = attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/extract_interface"),
        ),
        _xpaktool = attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/xpaktool"),
        ),
        **_EBUILD_COMMON_ATTRS
    ),
)

_DEBUG_SCRIPT = """
# Arguments passed in during build time are passed in relative to the execroot,
# which means all files passed in are relative paths starting with bazel-out/
# Thus, we cd to the directory in our working directory containing a bazel-out.

wd="$(pwd)"
cd "${wd%%/bazel-out/*}"

# The runfiles manifest file contains relative paths, which are evaluated
# relative to the working directory. Since we provide our own working directory,
# we need to use the RUNFILES_DIR instead.
export RUNFILES_DIR="${RUNFILES_MANIFEST_FILE%_manifest}"
unset RUNFILES_MANIFEST_FILE
"""

def _ebuild_debug_impl(ctx):
    src_basename = _get_basename(ctx)

    # Declare outputs.
    output_debug_script = ctx.actions.declare_file(src_basename + "_debug.sh")

    # Compute arguments and inputs to run build_package.
    # While we include all relevant input files in the wrapper script's
    # runfiles, we embed execroot paths in the script, not runfiles paths, so
    # that the debug invocation is closer to the real build execution.
    args, inputs = _compute_build_package_args(ctx, output_path = None, use_runfiles = False)

    # An interactive run will make --login default to after.
    # The user can still explicitly set --login=before if they wish.
    args.add("--interactive")

    return wrap_binary_with_args(
        ctx,
        out = output_debug_script,
        binary = ctx.executable._action_wrapper,
        args = args,
        content_prefix = _DEBUG_SCRIPT,
        runfiles = ctx.runfiles(transitive_files = inputs),
    )

# TODO(b/298889830): Remove this rule once chromite starts using install_list.
ebuild_debug, ebuild_debug_primordial = maybe_primordial_rule(
    implementation = _ebuild_debug_impl,
    executable = True,
    doc = "Enters the ephemeral chroot to build a Portage binary package in.",
    attrs = dict(
        _bash_runfiles = BASH_RUNFILES_ATTR,
        suffix = attr.string(
            doc = """
            Suffix to add to the output file. i.e., libcxx-17.0-r15<suffix>_debug.sh
            """,
        ),
        **_EBUILD_COMMON_ATTRS
    ),
)

_INSTALL_SCRIPT_HEADER = """#!/bin/bash
set -ue

if [[ ! -e /etc/cros_chroot_version ]]; then
  echo "Cannot run outside the cros SDK chroot."
  exit 1
fi

# Arguments passed in during build time are passed in relative to the execroot,
# which means all files passed in are relative paths starting with bazel-out/
# Thus, we cd to the directory in our working directory containing a bazel-out.

wd="$(pwd)"
cd "${wd%%/bazel-out/*}"
"""

def _ebuild_install_impl(ctx):
    src_basename = ctx.file.ebuild.basename.rsplit(".", 1)[0]

    # Generate script.
    script_contents = _INSTALL_SCRIPT_HEADER

    # Add script to copy binary packages to the PKGDIR.
    for package in ctx.attr.packages:
        info = package[BinaryPackageInfo]
        dest_dir = "/build/%s/packages/%s/" % (ctx.attr.board, info.category)
        dest_path = "%s/%s" % (dest_dir, info.file.basename)
        script_contents += """
        sudo mkdir -p "%s"
        sudo cp "%s" "%s"
        sudo chmod 644 "%s"
        """ % (dest_dir, info.file.path, dest_path, dest_path)

    # Add script to install binary packages.
    install_groups = calculate_install_groups(
        [package[BinaryPackageInfo] for package in ctx.attr.packages],
        provided_packages = depset(),
    )
    for install_group in install_groups:
        atoms = [
            "=%s/%s" % (info.category, info.file.basename.rsplit(".", 1)[0])
            for info in install_group
        ]
        script_contents += "emerge-%s --usepkgonly --nodeps --jobs %s\n" % (
            ctx.attr.board,
            " ".join(atoms),
        )

    # Write script.
    output_install_script = ctx.actions.declare_file(src_basename +
                                                     "_install.sh")
    ctx.actions.write(
        output_install_script,
        script_contents,
        is_executable = True,
    )

    runfiles = ctx.runfiles(files = [
        package[BinaryPackageInfo].file
        for package in ctx.attr.packages
    ])
    return DefaultInfo(
        executable = output_install_script,
        runfiles = runfiles,
    )

ebuild_install, ebuild_install_primordial = maybe_primordial_rule(
    implementation = _ebuild_install_impl,
    executable = True,
    doc = "Installs the package to the environment.",
    attrs = dict(
        ebuild = attr.label(
            mandatory = True,
            allow_single_file = [".ebuild"],
        ),
        category = attr.string(
            mandatory = True,
            doc = """
            The category name of the package.
            """,
        ),
        board = attr.string(
            mandatory = True,
            doc = """
            The target board name to build the package for.
            """,
        ),
        packages = attr.label_list(
            providers = [BinaryPackageInfo],
        ),
    ),
)

_EbuildInstalledInfo = provider(fields = dict(
    checksum = "(File) File containing a hash of the transitive runtime deps",
))

def _ebuild_install_action_impl(ctx):
    pkg = ctx.attr.package[BinaryPackageInfo]
    checksum = ctx.actions.declare_file(ctx.label.name + ".sha256sum")
    args = ctx.actions.args()
    args.add(pkg.file)
    args.add("/build/%s/packages/%s/%s" % (
        ctx.attr.board,
        pkg.category,
        pkg.file.basename,
    ))
    pkg_name = pkg.category + "/" + pkg.file.basename.rsplit(".", 1)[0]
    args.add("emerge-%s --usepkgonly --nodeps --jobs =%s" % (
        ctx.attr.board,
        pkg_name,
    ))
    args.add(checksum)

    inputs = [pkg.file]

    # The only use of this is to ensure that our checksum is a hash of the
    # transitive dependencies rather than just this file.
    # This ensures that if we have foo -> bar -> baz, and we change baz, foo
    # will reinstall itself.
    for dep in ctx.attr.requires:
        inputs.append(dep[_EbuildInstalledInfo].checksum)
        args.add(dep[_EbuildInstalledInfo].checksum)

    ctx.actions.run(
        executable = ctx.executable._installer,
        inputs = inputs,
        arguments = [args],
        outputs = [checksum],
        execution_requirements = {
            # This implies no-sandbox and no-remote
            "local": "1",
            # Ideally we should cache this if it matches the most recent hash
            # in the cache, but the disk cache is considered a local cache, and
            # can store older hashes.
            "no-cache": "1",
        },
        progress_message = "Installing %s to sysroot" % pkg_name,
    )

    return [
        # We don't really want DefaultInfo, but this forces it to actually
        # execute the installation when we build the target.
        DefaultInfo(files = depset([checksum])),
        _EbuildInstalledInfo(checksum = checksum),
    ]

ebuild_install_action = rule(
    implementation = _ebuild_install_action_impl,
    doc = "Installs the package to the permanent SDK using a bazel action.",
    attrs = dict(
        package = attr.label(
            providers = [BinaryPackageInfo],
        ),
        board = attr.string(
            mandatory = True,
            doc = """
            The target board name to build the package for.
            """,
        ),
        requires = attr.label_list(providers = [_EbuildInstalledInfo]),
        _installer = attr.label(
            default = "//bazel/portage/build_defs:ebuild_installer",
            executable = True,
            cfg = "exec",
        ),
    ),
    provides = [_EbuildInstalledInfo],
)

def _ebuild_install_list_impl(ctx):
    src_basename = ctx.file.ebuild.basename.rsplit(".", 1)[0]

    path_to_info = {
        package[BinaryPackageInfo].file.path: package[BinaryPackageInfo]
        for package in ctx.attr.packages
    }

    packages = []
    for package in ctx.attr.packages:
        info = package[BinaryPackageInfo]
        name = "%s/%s" % (info.category, info.file.basename)
        path = info.file.path

        dep_names = []
        for dep_file in info.direct_runtime_deps:
            dep = path_to_info[dep_file.path]
            if not dep:
                fail("ebuild_install_list: packages are not exhaustive")
            dep_names.append("%s/%s" % (dep.category, dep.file.basename))

        packages.append("""{
            "name": "%s",
            "path": "%s",
            "deps": [%s]
        }""" % (name, path, ",".join(["\"%s\"" % dep for dep in dep_names])))

    contents = "[%s]" % ",".join(packages)

    output = ctx.actions.declare_file(src_basename + "_install_list.json")
    ctx.actions.write(
        output,
        contents,
    )

    runfiles = ctx.runfiles(files = [
        package[BinaryPackageInfo].file
        for package in ctx.attr.packages
    ])
    return DefaultInfo(
        files = depset([output]),
        runfiles = runfiles,
    )

ebuild_install_list, ebuild_install_list_primordial = maybe_primordial_rule(
    implementation = _ebuild_install_list_impl,
    doc = "Generates a JSON file which contains necessary info to install the package to the environment.",
    attrs = dict(
        ebuild = attr.label(
            mandatory = True,
            allow_single_file = [".ebuild"],
        ),
        category = attr.string(
            mandatory = True,
            doc = """
            The category name of the package.
            """,
        ),
        board = attr.string(
            mandatory = True,
            doc = """
            The target board name to build the package for.
            """,
        ),
        packages = attr.label_list(
            providers = [BinaryPackageInfo, BinaryPackageSetInfo],
        ),
    ),
)

def _ebuild_test_impl(ctx):
    src_basename = ctx.file.ebuild.basename.rsplit(".", 1)[0]

    # Declare outputs.
    output_runner_script = ctx.actions.declare_file(src_basename + "_test.sh")

    # Compute arguments and inputs to run build_package.
    args, inputs = _compute_build_package_args(ctx, output_path = None, use_runfiles = True)
    args.add("--test")

    return wrap_binary_with_args(
        ctx,
        out = output_runner_script,
        binary = ctx.executable._action_wrapper,
        args = args,
        runfiles = ctx.runfiles(transitive_files = inputs),
    )

ebuild_test, ebuild_primordial_test = maybe_primordial_rule(
    implementation = _ebuild_test_impl,
    doc = "Runs ebuild tests.",
    attrs = dict(
        _bash_runfiles = BASH_RUNFILES_ATTR,
        **_EBUILD_COMMON_ATTRS
    ),
    test = True,
)

def _ebuild_compare_package_test_impl(ctx):
    if len(ctx.attr.packages) != 2:
        fail("Expected two packages, got %d" % (len(ctx.attr.packages)))

    inputs = [
        package[BinaryPackageInfo].file
        for package in ctx.attr.packages
    ]

    args = ["compare-packages"]
    for file in inputs:
        args.append(file)

    return wrap_binary_with_args(
        ctx,
        out = ctx.outputs.executable,
        binary = ctx.attr._xpaktool,
        args = args,
        content_prefix = "export RUST_BACKTRACE=1",
        runfiles = ctx.runfiles(transitive_files = depset(inputs)),
    )

ebuild_compare_package_test, ebuild_compare_package_primordial_test = maybe_primordial_rule(
    implementation = _ebuild_compare_package_test_impl,
    doc = """
    Compares two binary packages and ensures they are identical. This test is
    helpful to ensure that ebuild outputs are hermetic.

    Unfortunately this test can't guarantee that two hosts will produce the same
    binary package. i.e., The `make -j <cores>` might get logged into the ebuild
    environment file which is build machine specific.
    """,
    attrs = {
        "packages": attr.label_list(
            doc = "The two binary packages to compare.",
            providers = [BinaryPackageInfo],
            mandatory = True,
        ),
        "_bash_runfiles": BASH_RUNFILES_ATTR,
        "_xpaktool": attr.label(
            executable = True,
            cfg = "exec",
            default = Label("//bazel/portage/bin/xpaktool"),
        ),
    },
    test = True,
)
