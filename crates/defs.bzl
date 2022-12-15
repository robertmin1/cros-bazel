###############################################################################
# @generated
# DO NOT MODIFY: This file is auto-generated by a crate_universe tool. To
# regenerate this file, run the following:
#
#     bazel run @@//bazel:update_crates
###############################################################################
"""
# `crates_repository` API

- [aliases](#aliases)
- [crate_deps](#crate_deps)
- [all_crate_deps](#all_crate_deps)
- [crate_repositories](#crate_repositories)

"""

load("@bazel_skylib//lib:selects.bzl", "selects")
load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_tools//tools/build_defs/repo:utils.bzl", "maybe")

###############################################################################
# MACROS API
###############################################################################

# An identifier that represent common dependencies (unconditional).
_COMMON_CONDITION = ""

def _flatten_dependency_maps(all_dependency_maps):
    """Flatten a list of dependency maps into one dictionary.

    Dependency maps have the following structure:

    ```python
    DEPENDENCIES_MAP = {
        # The first key in the map is a Bazel package
        # name of the workspace this file is defined in.
        "workspace_member_package": {

            # Not all dependnecies are supported for all platforms.
            # the condition key is the condition required to be true
            # on the host platform.
            "condition": {

                # An alias to a crate target.     # The label of the crate target the
                # Aliases are only crate names.   # package name refers to.
                "package_name":                   "@full//:label",
            }
        }
    }
    ```

    Args:
        all_dependency_maps (list): A list of dicts as described above

    Returns:
        dict: A dictionary as described above
    """
    dependencies = {}

    for workspace_deps_map in all_dependency_maps:
        for pkg_name, conditional_deps_map in workspace_deps_map.items():
            if pkg_name not in dependencies:
                non_frozen_map = dict()
                for key, values in conditional_deps_map.items():
                    non_frozen_map.update({key: dict(values.items())})
                dependencies.setdefault(pkg_name, non_frozen_map)
                continue

            for condition, deps_map in conditional_deps_map.items():
                # If the condition has not been recorded, do so and continue
                if condition not in dependencies[pkg_name]:
                    dependencies[pkg_name].setdefault(condition, dict(deps_map.items()))
                    continue

                # Alert on any miss-matched dependencies
                inconsistent_entries = []
                for crate_name, crate_label in deps_map.items():
                    existing = dependencies[pkg_name][condition].get(crate_name)
                    if existing and existing != crate_label:
                        inconsistent_entries.append((crate_name, existing, crate_label))
                    dependencies[pkg_name][condition].update({crate_name: crate_label})

    return dependencies

def crate_deps(deps, package_name = None):
    """Finds the fully qualified label of the requested crates for the package where this macro is called.

    Args:
        deps (list): The desired list of crate targets.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()`.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if not deps:
        return []

    if package_name == None:
        package_name = native.package_name()

    # Join both sets of dependencies
    dependencies = _flatten_dependency_maps([
        _NORMAL_DEPENDENCIES,
        _NORMAL_DEV_DEPENDENCIES,
        _PROC_MACRO_DEPENDENCIES,
        _PROC_MACRO_DEV_DEPENDENCIES,
        _BUILD_DEPENDENCIES,
        _BUILD_PROC_MACRO_DEPENDENCIES,
    ]).pop(package_name, {})

    # Combine all conditional packages so we can easily index over a flat list
    # TODO: Perhaps this should actually return select statements and maintain
    # the conditionals of the dependencies
    flat_deps = {}
    for deps_set in dependencies.values():
        for crate_name, crate_label in deps_set.items():
            flat_deps.update({crate_name: crate_label})

    missing_crates = []
    crate_targets = []
    for crate_target in deps:
        if crate_target not in flat_deps:
            missing_crates.append(crate_target)
        else:
            crate_targets.append(flat_deps[crate_target])

    if missing_crates:
        fail("Could not find crates `{}` among dependencies of `{}`. Available dependencies were `{}`".format(
            missing_crates,
            package_name,
            dependencies,
        ))

    return crate_targets

def all_crate_deps(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Finds the fully qualified label of all requested direct crate dependencies \
    for the package where this macro is called.

    If no parameters are set, all normal dependencies are returned. Setting any one flag will
    otherwise impact the contents of the returned list.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        list: A list of labels to generated rust targets (str)
    """

    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_dependency_maps = []
    if normal:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)
    if normal_dev:
        all_dependency_maps.append(_NORMAL_DEV_DEPENDENCIES)
    if proc_macro:
        all_dependency_maps.append(_PROC_MACRO_DEPENDENCIES)
    if proc_macro_dev:
        all_dependency_maps.append(_PROC_MACRO_DEV_DEPENDENCIES)
    if build:
        all_dependency_maps.append(_BUILD_DEPENDENCIES)
    if build_proc_macro:
        all_dependency_maps.append(_BUILD_PROC_MACRO_DEPENDENCIES)

    # Default to always using normal dependencies
    if not all_dependency_maps:
        all_dependency_maps.append(_NORMAL_DEPENDENCIES)

    dependencies = _flatten_dependency_maps(all_dependency_maps).pop(package_name, None)

    if not dependencies:
        if dependencies == None:
            fail("Tried to get all_crate_deps for package " + package_name + " but that package had no Cargo.toml file")
        else:
            return []

    crate_deps = list(dependencies.pop(_COMMON_CONDITION, {}).values())
    for condition, deps in dependencies.items():
        crate_deps += selects.with_or({_CONDITIONS[condition]: deps.values()})

    return crate_deps

def aliases(
        normal = False,
        normal_dev = False,
        proc_macro = False,
        proc_macro_dev = False,
        build = False,
        build_proc_macro = False,
        package_name = None):
    """Produces a map of Crate alias names to their original label

    If no dependency kinds are specified, `normal` and `proc_macro` are used by default.
    Setting any one flag will otherwise determine the contents of the returned dict.

    Args:
        normal (bool, optional): If True, normal dependencies are included in the
            output list.
        normal_dev (bool, optional): If True, normal dev dependencies will be
            included in the output list..
        proc_macro (bool, optional): If True, proc_macro dependencies are included
            in the output list.
        proc_macro_dev (bool, optional): If True, dev proc_macro dependencies are
            included in the output list.
        build (bool, optional): If True, build dependencies are included
            in the output list.
        build_proc_macro (bool, optional): If True, build proc_macro dependencies are
            included in the output list.
        package_name (str, optional): The package name of the set of dependencies to look up.
            Defaults to `native.package_name()` when unset.

    Returns:
        dict: The aliases of all associated packages
    """
    if package_name == None:
        package_name = native.package_name()

    # Determine the relevant maps to use
    all_aliases_maps = []
    if normal:
        all_aliases_maps.append(_NORMAL_ALIASES)
    if normal_dev:
        all_aliases_maps.append(_NORMAL_DEV_ALIASES)
    if proc_macro:
        all_aliases_maps.append(_PROC_MACRO_ALIASES)
    if proc_macro_dev:
        all_aliases_maps.append(_PROC_MACRO_DEV_ALIASES)
    if build:
        all_aliases_maps.append(_BUILD_ALIASES)
    if build_proc_macro:
        all_aliases_maps.append(_BUILD_PROC_MACRO_ALIASES)

    # Default to always using normal aliases
    if not all_aliases_maps:
        all_aliases_maps.append(_NORMAL_ALIASES)
        all_aliases_maps.append(_PROC_MACRO_ALIASES)

    aliases = _flatten_dependency_maps(all_aliases_maps).pop(package_name, None)

    if not aliases:
        return dict()

    common_items = aliases.pop(_COMMON_CONDITION, {}).items()

    # If there are only common items in the dictionary, immediately return them
    if not len(aliases.keys()) == 1:
        return dict(common_items)

    # Build a single select statement where each conditional has accounted for the
    # common set of aliases.
    crate_aliases = {"//conditions:default": common_items}
    for condition, deps in aliases.items():
        condition_triples = _CONDITIONS[condition]
        if condition_triples in crate_aliases:
            crate_aliases[condition_triples].update(deps)
        else:
            crate_aliases.update({_CONDITIONS[condition]: dict(deps.items() + common_items)})

    return selects.with_or(crate_aliases)

###############################################################################
# WORKSPACE MEMBER DEPS AND ALIASES
###############################################################################

_NORMAL_DEPENDENCIES = {
    "bazel": {
        _COMMON_CONDITION: {
            "env_logger": "@update_crates__env_logger-0.9.3//:env_logger",
            "log": "@update_crates__log-0.4.17//:log",
        },
    },
}

_NORMAL_ALIASES = {
    "bazel": {
        _COMMON_CONDITION: {
        },
    },
}

_NORMAL_DEV_DEPENDENCIES = {
    "bazel": {
    },
}

_NORMAL_DEV_ALIASES = {
    "bazel": {
    },
}

_PROC_MACRO_DEPENDENCIES = {
    "bazel": {
    },
}

_PROC_MACRO_ALIASES = {
    "bazel": {
    },
}

_PROC_MACRO_DEV_DEPENDENCIES = {
    "bazel": {
    },
}

_PROC_MACRO_DEV_ALIASES = {
    "bazel": {
    },
}

_BUILD_DEPENDENCIES = {
    "bazel": {
    },
}

_BUILD_ALIASES = {
    "bazel": {
    },
}

_BUILD_PROC_MACRO_DEPENDENCIES = {
    "bazel": {
    },
}

_BUILD_PROC_MACRO_ALIASES = {
    "bazel": {
    },
}

_CONDITIONS = {
    "cfg(target_os = \"hermit\")": [],
    "cfg(unix)": ["aarch64-apple-darwin", "aarch64-apple-ios", "aarch64-apple-ios-sim", "aarch64-linux-android", "aarch64-unknown-linux-gnu", "arm-unknown-linux-gnueabi", "armv7-linux-androideabi", "armv7-unknown-linux-gnueabi", "i686-apple-darwin", "i686-linux-android", "i686-unknown-freebsd", "i686-unknown-linux-gnu", "powerpc-unknown-linux-gnu", "s390x-unknown-linux-gnu", "x86_64-apple-darwin", "x86_64-apple-ios", "x86_64-linux-android", "x86_64-unknown-freebsd", "x86_64-unknown-linux-gnu"],
    "cfg(windows)": ["aarch64-pc-windows-msvc", "i686-pc-windows-msvc", "x86_64-pc-windows-msvc"],
    "i686-pc-windows-gnu": [],
    "x86_64-pc-windows-gnu": [],
}

###############################################################################

def crate_repositories():
    """A macro for defining repositories for all generated crates"""
    maybe(
        http_archive,
        name = "update_crates__aho-corasick-0.7.20",
        sha256 = "cc936419f96fa211c1b9166887b38e5e40b19958e5b895be7c1f93adec7071ac",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/aho-corasick/0.7.20/download"],
        strip_prefix = "aho-corasick-0.7.20",
        build_file = Label("@chromiumos//bazel/crates:BUILD.aho-corasick-0.7.20.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__atty-0.2.14",
        sha256 = "d9b39be18770d11421cdb1b9947a45dd3f37e93092cbf377614828a319d5fee8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/atty/0.2.14/download"],
        strip_prefix = "atty-0.2.14",
        build_file = Label("@chromiumos//bazel/crates:BUILD.atty-0.2.14.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__cfg-if-1.0.0",
        sha256 = "baf1de4339761588bc0619e3cbc0120ee582ebb74b53b4efbf79117bd2da40fd",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/cfg-if/1.0.0/download"],
        strip_prefix = "cfg-if-1.0.0",
        build_file = Label("@chromiumos//bazel/crates:BUILD.cfg-if-1.0.0.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__env_logger-0.9.3",
        sha256 = "a12e6657c4c97ebab115a42dcee77225f7f482cdd841cf7088c657a42e9e00e7",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/env_logger/0.9.3/download"],
        strip_prefix = "env_logger-0.9.3",
        build_file = Label("@chromiumos//bazel/crates:BUILD.env_logger-0.9.3.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__hermit-abi-0.1.19",
        sha256 = "62b467343b94ba476dcb2500d242dadbb39557df889310ac77c5d99100aaac33",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/hermit-abi/0.1.19/download"],
        strip_prefix = "hermit-abi-0.1.19",
        build_file = Label("@chromiumos//bazel/crates:BUILD.hermit-abi-0.1.19.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__humantime-2.1.0",
        sha256 = "9a3a5bfb195931eeb336b2a7b4d761daec841b97f947d34394601737a7bba5e4",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/humantime/2.1.0/download"],
        strip_prefix = "humantime-2.1.0",
        build_file = Label("@chromiumos//bazel/crates:BUILD.humantime-2.1.0.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__libc-0.2.138",
        sha256 = "db6d7e329c562c5dfab7a46a2afabc8b987ab9a4834c9d1ca04dc54c1546cef8",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/libc/0.2.138/download"],
        strip_prefix = "libc-0.2.138",
        build_file = Label("@chromiumos//bazel/crates:BUILD.libc-0.2.138.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__log-0.4.17",
        sha256 = "abb12e687cfb44aa40f41fc3978ef76448f9b6038cad6aef4259d3c095a2382e",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/log/0.4.17/download"],
        strip_prefix = "log-0.4.17",
        build_file = Label("@chromiumos//bazel/crates:BUILD.log-0.4.17.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__memchr-2.5.0",
        sha256 = "2dffe52ecf27772e601905b7522cb4ef790d2cc203488bbd0e2fe85fcb74566d",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/memchr/2.5.0/download"],
        strip_prefix = "memchr-2.5.0",
        build_file = Label("@chromiumos//bazel/crates:BUILD.memchr-2.5.0.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__regex-1.7.0",
        sha256 = "e076559ef8e241f2ae3479e36f97bd5741c0330689e217ad51ce2c76808b868a",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/regex/1.7.0/download"],
        strip_prefix = "regex-1.7.0",
        build_file = Label("@chromiumos//bazel/crates:BUILD.regex-1.7.0.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__regex-syntax-0.6.28",
        sha256 = "456c603be3e8d448b072f410900c09faf164fbce2d480456f50eea6e25f9c848",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/regex-syntax/0.6.28/download"],
        strip_prefix = "regex-syntax-0.6.28",
        build_file = Label("@chromiumos//bazel/crates:BUILD.regex-syntax-0.6.28.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__termcolor-1.1.3",
        sha256 = "bab24d30b911b2376f3a13cc2cd443142f0c81dda04c118693e35b3835757755",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/termcolor/1.1.3/download"],
        strip_prefix = "termcolor-1.1.3",
        build_file = Label("@chromiumos//bazel/crates:BUILD.termcolor-1.1.3.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__winapi-0.3.9",
        sha256 = "5c839a674fcd7a98952e593242ea400abe93992746761e38641405d28b00f419",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi/0.3.9/download"],
        strip_prefix = "winapi-0.3.9",
        build_file = Label("@chromiumos//bazel/crates:BUILD.winapi-0.3.9.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__winapi-i686-pc-windows-gnu-0.4.0",
        sha256 = "ac3b87c63620426dd9b991e5ce0329eff545bccbbb34f3be09ff6fb6ab51b7b6",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-i686-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-i686-pc-windows-gnu-0.4.0",
        build_file = Label("@chromiumos//bazel/crates:BUILD.winapi-i686-pc-windows-gnu-0.4.0.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__winapi-util-0.1.5",
        sha256 = "70ec6ce85bb158151cae5e5c87f95a8e97d2c0c4b001223f33a334e3ce5de178",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-util/0.1.5/download"],
        strip_prefix = "winapi-util-0.1.5",
        build_file = Label("@chromiumos//bazel/crates:BUILD.winapi-util-0.1.5.bazel"),
    )

    maybe(
        http_archive,
        name = "update_crates__winapi-x86_64-pc-windows-gnu-0.4.0",
        sha256 = "712e227841d057c1ee1cd2fb22fa7e5a5461ae8e48fa2ca79ec42cfc1931183f",
        type = "tar.gz",
        urls = ["https://crates.io/api/v1/crates/winapi-x86_64-pc-windows-gnu/0.4.0/download"],
        strip_prefix = "winapi-x86_64-pc-windows-gnu-0.4.0",
        build_file = Label("@chromiumos//bazel/crates:BUILD.winapi-x86_64-pc-windows-gnu-0.4.0.bazel"),
    )
