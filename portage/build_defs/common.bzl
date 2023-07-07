# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("@bazel_skylib//lib:paths.bzl", "paths")

BinaryPackageInfo = provider(
    """
    Describes a Portage binary package.

    A rule providing BinaryPackageInfo must also provide BinaryPackageSetInfo
    that covers all transitive runtime dependencies of this package.

    All fields in this provider must have immutable types (i.e. no list/dict)
    because a BinaryPackageInfo is always accompanied by a BinaryPackageSetInfo
    referencing it with a depset.
    """,
    fields = {
        "file": """
            File: A binary package file (.tbz2) of this package.
        """,
        "category": """
            str: The category of this package.
        """,
        "all_files": """
            Depset[File]: All binary package files including this package's one
            itself and all transitive runtime dependencies.

            The Depset must be constructed in a way so that its to_list()
            returns packages in a valid installation order, i.e. a package's
            runtime dependencies are fully satisfied by packages that appear
            before it.
        """,
        "direct_runtime_deps": """
            tuple[BinaryPackageInfo]: Direct runtime dependencies of the
            package. See the provider description for why this field is a tuple,
            not a list.
        """,
        "transitive_runtime_deps": """
            Depset[BinaryPackageInfo]: Transitive runtime dependencies of the
            package. Note that this depset does *NOT* contain this package
            itself, just because it is impossible to construct a
            self-referencing provider.

            The Depset must be constructed in a way so that its to_list()
            returns packages in a valid installation order, i.e. a package's
            runtime dependencies are fully satisfied by packages that appear
            before it.
        """,
    },
)

BinaryPackageSetInfo = provider(
    """
    Represents a set of Portage binary packages.

    A package set represented by this provider is always closed over transitive
    runtime dependencies. That is, if the set contains a package X, it also
    contains all transitive dependencies of the package X.

    A rule providing BinaryPackageInfo must also provide BinaryPackageSetInfo
    that covers all transitive runtime dependencies of this package.
    """,
    fields = {
        "packages": """
            Depset[BinaryPackageInfo]: All Portage binary packages included in
            this set.

            The Depset must be constructed in a way so that its to_list()
            returns packages in a valid installation order, i.e. a package's
            runtime dependencies are fully satisfied by packages that appear
            before it.
        """,
        "files": """
            Depset[File]: All Portage binary package files included in this set.

            The Depset must be constructed in a way so that its to_list()
            returns packages in a valid installation order, i.e. a package's
            runtime dependencies are fully satisfied by packages that appear
            before it.
        """,
    },
)

OverlayInfo = provider(
    "Portage overlay info",
    fields = {
        "path": """
            String: Path inside the container where the overlay's ebuilds are
            mounted.
        """,
        "layer": """
            File: A file which represents an overlay layer. A layer
            file can be a tar file (.tar or .tar.zst).
        """,
    },
)

OverlaySetInfo = provider(
    "Portage overlay set info",
    fields = {
        "layers": """
            File[]: A list of files each of which represents an overlay. A layer
            file can be a directory or a tar file (.tar or .tar.zst). Layers are
            ordered from lower to upper; in other words, a file from a layer can
            be overridden by one in another layer that appears later in the
            list.
        """,
    },
)

SDKInfo = provider(
    """
    Contains information necessary to mount an ephemeral CrOS SDK.
    """,
    fields = {
        "layers": """
            File[]: A list of files each of which represents a file system layer
            of the SDK. A layer file can be a directory or a tar file (.tar or
            .tar.zst). Layers are ordered from lower to upper; in other words,
            a file from a layer can be overridden by one in another layer that
            appears later in the list.
        """,
    },
)

EbuildLibraryInfo = provider(
    "Ebuild library info",
    fields = {
        "strip_prefix": """
            str: The prefix to strip off the files when installing into the sdk.
        """,
        "headers": """
            Depset[File]: Headers provided by the package.
        """,
        "pkg_configs": """
            Depset[File]: .pc files provided by the package.
        """,
        "shared_libs": """
            Depset[File]: .so files provided by the package.
        """,
        "static_libs": """
            Depset[File]: .a files provided by the package.
        """,
    },
)

# rustc flags to enable debug symbols.
RUSTC_DEBUG_FLAGS = ["--codegen=debuginfo=2"]

def _workspace_root(label):
    return paths.join("..", label.workspace_name) if label.workspace_name else ""

def relative_path_in_label(file, label):
    return paths.relativize(file.short_path, paths.join(_workspace_root(label), label.package))

def relative_path_in_package(file):
    owner = file.owner
    if owner == None:
        fail("File does not have an associated owner label")
    return relative_path_in_label(file, owner)

def compute_input_file_path(file, use_runfiles):
    """
    Computes a file path referring to the given input file.

    This function helps you to refer to input file path correctly in the two
    major different working directory configurations: execroot and runfiles.

    When you are going to use a file in a build action run by "bazel build",
    pass use_runfiles=False. The function will just return `file.path` that is
    valid in an action execroot.

    When you are going to use a file in a binary file invoked for "bazel run"
    or "bazel test", pass use_runfiles=True and make sure to include the file
    in the runfiles of the binary. Then this function will return a file path
    you can refer to the file in the runfile tree of the binary.

    Args:
        file: File: An input file.
        use_runfiles: bool: Whether to refer to the input file in a path
            relative to execroot or runfiles directory.

    Returns:
        A file path referring to the given file.
    """
    if file.owner == None:
        fail("Unable to compute a path for a file not associated with a label")
    if use_runfiles:
        return paths.join(_workspace_root(file.owner), file.short_path)
    else:
        return file.path

def single_binary_package_set_info(package_info):
    """
    Creates BinaryPackageSetInfo for a single binary package.

    Args:
        package_info: BinaryPackageInfo: A provider describing a binary package.

    Returns:
        BinaryPackageSetInfo: A provider representing all transitive runtime
            dependencies of the given binary package.
    """
    return BinaryPackageSetInfo(
        packages = depset(
            [package_info],
            transitive = [
                depset(
                    [dep],
                    transitive = [dep.transitive_runtime_deps],
                    order = "postorder",
                )
                for dep in package_info.direct_runtime_deps
            ],
            order = "postorder",
        ),
        files = package_info.all_files,
    )