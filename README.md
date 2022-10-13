# ChromeOS Bazelification

This is an experiment to build ChromeOS with Bazel.

## Checking out

For the prototyping phase, we're working on building a snapshot of ChromiumOS.
Use `repo` to check out a snapshotted ChromiumOS tree + Bazel files.

```sh
$ mkdir cros-bazel
$ cd cros-bazel
$ repo init -u sso://team/cros-build-tiger/cros-bazel-manifest -b main
$ repo sync -c -j 4
$ cd src
```

## Building

First you need to generate `BUILD.bazel` files for Portage packages.
Package data needed to generate them are managed in `bazel/data/deps.json`
and it can be converted to `BUILD.bazel` with the following command:

```sh
$ bazel run //bazel/ebuild/private/cmd/update_build
```

Then you can start building packages. To build sys-apps/ethtool for example:

```sh
$ bazel build //third_party/portage-stable/sys-apps/ethtool:0
```

Note that the label "0" is a SLOT identifier. It is typically "0", but it can
have different values for packages where multiple versions can be installed
at the same time.

To build all target packages:

```
$ bazel build --keep_going //:all_target_packages
```

This is basically a short-cut to build
`//third_party/chromiumos-overlay/virtual/target-os:0`.

## Directory structure

See [manifest/_bazel.xml] for details on how this repository is organized.

[manifest/_bazel.xml]: https://team.git.corp.google.com/cros-build-tiger/cros-bazel-manifest/+/refs/heads/main/_bazel.xml

* `src/`
    * `bazel/` ... contains Bazel-related files
        * `ebuild/`
            * `defs.bzl` ... provides Bazel rules
            * `private/` ... contains programs used by Bazel rules
                * `cmd/`
                    * `create_squashfs/` ... creates squashfs from a file set; used by `overlay` rule
                    * `run_in_container/` ... runs a program within an unprivileged Linux container; used by other programs such as `build_sdk` and `build_package`
                    * `build_sdk/` ... builds SDK squashfs; used by `sdk` rule
                    * `build_package/` ... builds a Portage binary package; used by `ebuild` rule
                    * `update_build/` ... generates BUILD files for ebuilds
        * `config/` ... contains build configs like which overlays to use
        * `sdk/` ... defines SDK to use
    * `overlays/`
        * `overlay-arm64-generic/` ... a fork of overlay
    * `third_party/`
        * `portage-stable/` ... a fork of overlay
        * `eclass-overlay/` ... a fork of overlay
        * `chromiumos-overlay/` ... a fork of overlay
* `manifest/` ... copy of cros-bazel-manifest repository

## Misc Memo

### Generating BUILD files in overlays

Firstly, run `extract_deps` **in CrOS chroot** to extract package dependency
info from ebuilds.

```sh
$ cros_sdk bazel-5 run //bazel/ebuild/private/cmd/extract_deps -- --board=arm64-generic --start=virtual/target-os > bazel/data/deps.json
```

Then you can run `generate_build` to update `BUILD` files.

```sh
$ bazel run //bazel/ebuild/private/cmd/update_build -- --package-info-file $PWD/bazel/data/deps.json
```

### Visualizing the dependency graph

Firstly, build all packages to generate .tbz2 files.

```sh
$ bazel build --keep_going //:all_target_packages
```

Then run `bazel/tools/generate_depgraph.py` to generate a DOT file. It inspects
`bazel-bin` directory to see if a package was successfully built or not.

```sh
$ bazel/tools/generate_depgraph.py bazel/data/deps.json > bazel/data/deps.dot
```

### Debugging an ephemeral CrOS chroot

Sometimes you want to enter an ephemeral CrOS chroot where a package build is
failing to inspect the environment interactively.

To debug an ephemeral CrOS chroot, build a target package with
`--spawn_strategy=standalone` option. On the very first line of its stderr
output, a command line to enter the chroot is printed, just like this:

```
HINT: To debug this build environment, run the Bazel build with --spawn_strategy=standalone, and run the command printed below:
( cd path/to/somewhere && path/to/command --some-options --login )
```

The message is shown without `--spawn_strategy=standalone`, but the printed
command does not work because Bazel uses a temporary execroot.

Related code is located [here](https://team.git.corp.google.com/cros-build-tiger/cros-bazel/+/refs/heads/main/ebuild/private/cmd/build_package/main.go#190).
