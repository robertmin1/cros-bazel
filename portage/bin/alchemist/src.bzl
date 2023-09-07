# AUTO GENERATED DO NOT EDIT!
# Regenerate this file using ./regen-srcs.sh
# It should be regenerated each time a file is added or removed.

load(":shared_crates.bzl", "SHARED_CRATES")

_DEV_SRCS_NO_LOCK = [
    "//bazel/portage/bin/alchemist:Cargo.toml",
    "//bazel/portage/bin/alchemist:src/analyze/dependency.rs",
    "//bazel/portage/bin/alchemist:src/analyze/mod.rs",
    "//bazel/portage/bin/alchemist:src/analyze/restrict.rs",
    "//bazel/portage/bin/alchemist:src/analyze/source.rs",
    "//bazel/portage/bin/alchemist:src/bash/expr/eval.rs",
    "//bazel/portage/bin/alchemist:src/bash/expr/mod.rs",
    "//bazel/portage/bin/alchemist:src/bash/expr/parser.rs",
    "//bazel/portage/bin/alchemist:src/bash/mod.rs",
    "//bazel/portage/bin/alchemist:src/bash/vars.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/alchemist.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/digest_repo.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/dump_package.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/common.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/deps.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/mod.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/overlays/mod.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/overlays/templates/chromiumos-overlay.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/overlays/templates/eclass.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/overlays/templates/overlay.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/overlays/templates/overlays.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/packages/mod.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/packages/templates/package.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sdk/mod.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sdk/templates/base.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sdk/templates/emerge",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sdk/templates/host.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sdk/templates/pkg-config",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sdk/templates/portage-tool",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sdk/templates/stage1.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sdk/templates/target.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/mod.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/templates/source.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/.presubmitignore",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/empty_dirs.golden.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/empty_dirs_git.llvm-project.golden.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/empty_dirs_git.platform2.golden.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/golden/foo/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/golden/foo/bar/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/golden/foo/bar/baz/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/golden/foo/bar/baz/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/golden/foo/bar/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/golden/foo/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/source/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/source/foo/bar/baz/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/source/foo/bar/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/source/foo/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/nested/sources.json",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/simple/golden/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/simple/golden/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/simple/source/file.txt",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/simple/sources.json",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_dirs/golden/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_dirs/golden/__rename__0",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_dirs/sources.json",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_files/golden/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_files/golden/__rename__0",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_files/golden/__rename__1",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_files/golden/__rename__2",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_files/source/BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_files/source/WORKSPACE.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/special_files/sources.json",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/symlinks/golden/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/internal/sources/testdata/symlinks/sources.json",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/mod.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/public/mod.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/public/templates/package.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/settings.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/templates/root.BUILD.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/generate_repo/templates/settings.bzl",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/main.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/.presubmitignore",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/README.md",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/WORKSPACE.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/amd64-generic/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/amd64-generic/make.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/amd64-generic/metadata/layout.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/amd64-generic/profiles/base/make.defaults",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/amd64-generic/toolchain.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/chromeos/config/make.conf.common",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/chromeos/config/make.conf.generic-target",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/eclass/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/eclass/myclass.eclass",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/eclass/mysuper.eclass",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/metadata/layout.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/simple/aaa/aaa-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/simple/bbb/bbb-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/sys-kernel/linux-headers/linux-headers-4.14.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/sys-libs/gcc-libs/gcc-libs-10.2.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/sys-libs/glibc/glibc-2.35-r20.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/sys-libs/libcxx/libcxx-16.0_pre484197.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/sys-libs/llvm-libunwind/llvm-libunwind-16.0_pre484197.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/bashrcandpatches/bashrcandpatches-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/bashrcandpatches/bashrcandpatches.bashrc",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/bashrcandpatches/files/1.patch",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/bashrcandpatches/files/2.patch",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/distfiles/Manifest",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/distfiles/distfiles-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/failure/failure-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/inherit/inherit-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/chromiumos/test-cases/testonlydeps/testonlydeps-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/portage-stable/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/portage-stable/metadata/layout.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/overlays/portage-stable/virtual/os-headers/os-headers-0-r2.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/simple/aaa/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/simple/aaa/aaa-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/simple/bbb/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/simple/bbb/bbb-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-kernel/linux-headers/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-kernel/linux-headers/linux-headers-4.14.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-libs/gcc-libs/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-libs/gcc-libs/gcc-libs-10.2.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-libs/glibc/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-libs/glibc/glibc-2.35-r20.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-libs/libcxx/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-libs/libcxx/libcxx-16.0_pre484197.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-libs/llvm-libunwind/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/sys-libs/llvm-libunwind/llvm-libunwind-16.0_pre484197.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/bashrcandpatches/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/bashrcandpatches/bashrcandpatches-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/bashrcandpatches/files/1.patch",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/bashrcandpatches/files/2.patch",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/distfiles/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/distfiles/distfiles-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/failure/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/failure/failure-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/inherit/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/inherit/inherit-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/testonlydeps/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/chromiumos/test-cases/testonlydeps/testonlydeps-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/portage-stable/virtual/os-headers/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/packages/stage1/target/board/portage-stable/virtual/os-headers/os-headers-0-r2.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/eclean",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/emaint",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/emerge",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/equery",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/make.conf.board",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/make.conf.board_setup",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/pkg-config",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/portageq",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/qcheck",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/qdepends",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/qfile",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/qlist",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/qmerge",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sdk/stage1/target/board/qsize",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sources/src/scripts/hooks/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/internal/sources/src/scripts/hooks/install/hello.sh",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/settings.bzl",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/simple/aaa/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/simple/bbb/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/sys-kernel/linux-headers/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/sys-libs/gcc-libs/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/sys-libs/glibc/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/sys-libs/libcxx/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/sys-libs/llvm-libunwind/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/test-cases/bashrcandpatches/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/test-cases/distfiles/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/test-cases/failure/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/test-cases/inherit/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/test-cases/testonlydeps/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/golden/virtual/os-headers/BUILD.golden.bazel",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/chromite/__pycache__/README.md",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/chromite/main.py",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/overlays/overlay-amd64-generic/make.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/overlays/overlay-amd64-generic/metadata/layout.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/overlays/overlay-amd64-generic/profiles/base/make.defaults",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/overlays/overlay-amd64-generic/toolchain.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/overlays/overlay-amd64-host/metadata/layout.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/overlays/overlay-amd64-host/toolchain.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/scripts/hooks/install/hello.sh",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/chromeos/config/make.conf.common",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/chromeos/config/make.conf.generic-target",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/eclass/myclass.eclass",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/eclass/mysuper.eclass",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/metadata/layout.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/simple/aaa/aaa-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/simple/bbb/bbb-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/sys-kernel/linux-headers/linux-headers-4.14.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/sys-libs/gcc-libs/gcc-libs-10.2.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/sys-libs/glibc/glibc-2.35-r20.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/sys-libs/libcxx/libcxx-16.0_pre484197.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/sys-libs/llvm-libunwind/llvm-libunwind-16.0_pre484197.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/bashrcandpatches/bashrcandpatches-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/bashrcandpatches/bashrcandpatches.bashrc",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/bashrcandpatches/files/1.patch",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/bashrcandpatches/files/2.patch",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/distfiles/Manifest",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/distfiles/distfiles-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/failure/failure-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/inherit/inherit-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/chromiumos-overlay/test-cases/testonlydeps/testonlydeps-1.0.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/portage-stable/metadata/layout.conf",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/testdata/input/src/third_party/portage-stable/virtual/os-headers/os-headers-0-r2.ebuild",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/ver_rs.rs",
    "//bazel/portage/bin/alchemist:src/bin/alchemist/ver_test.rs",
    "//bazel/portage/bin/alchemist:src/common.rs",
    "//bazel/portage/bin/alchemist:src/config/bundle.rs",
    "//bazel/portage/bin/alchemist:src/config/makeconf/generate/mod.rs",
    "//bazel/portage/bin/alchemist:src/config/makeconf/generate/templates/make.conf",
    "//bazel/portage/bin/alchemist:src/config/makeconf/mod.rs",
    "//bazel/portage/bin/alchemist:src/config/makeconf/parser.rs",
    "//bazel/portage/bin/alchemist:src/config/miscconf/accept_keywords.rs",
    "//bazel/portage/bin/alchemist:src/config/miscconf/mask.rs",
    "//bazel/portage/bin/alchemist:src/config/miscconf/mod.rs",
    "//bazel/portage/bin/alchemist:src/config/miscconf/provided.rs",
    "//bazel/portage/bin/alchemist:src/config/miscconf/useflags.rs",
    "//bazel/portage/bin/alchemist:src/config/mod.rs",
    "//bazel/portage/bin/alchemist:src/config/profile.rs",
    "//bazel/portage/bin/alchemist:src/config/site.rs",
    "//bazel/portage/bin/alchemist:src/data.rs",
    "//bazel/portage/bin/alchemist:src/dependency/algorithm.rs",
    "//bazel/portage/bin/alchemist:src/dependency/mod.rs",
    "//bazel/portage/bin/alchemist:src/dependency/package/mod.rs",
    "//bazel/portage/bin/alchemist:src/dependency/package/parser.rs",
    "//bazel/portage/bin/alchemist:src/dependency/parser/mod.rs",
    "//bazel/portage/bin/alchemist:src/dependency/parser/restrict.rs",
    "//bazel/portage/bin/alchemist:src/dependency/parser/uri.rs",
    "//bazel/portage/bin/alchemist:src/dependency/restrict.rs",
    "//bazel/portage/bin/alchemist:src/dependency/uri.rs",
    "//bazel/portage/bin/alchemist:src/ebuild/ebuild_prelude.sh",
    "//bazel/portage/bin/alchemist:src/ebuild/metadata.rs",
    "//bazel/portage/bin/alchemist:src/ebuild/mod.rs",
    "//bazel/portage/bin/alchemist:src/fakechroot.rs",
    "//bazel/portage/bin/alchemist:src/fileops.rs",
    "//bazel/portage/bin/alchemist:src/lib.rs",
    "//bazel/portage/bin/alchemist:src/repository.rs",
    "//bazel/portage/bin/alchemist:src/resolver.rs",
    "//bazel/portage/bin/alchemist:src/simpleversion.rs",
    "//bazel/portage/bin/alchemist:src/testutils.rs",
    "//bazel/portage/bin/alchemist:src/toolchain/mod.rs",
]

_SHARED_CRATE_FILES = [
    "//bazel/portage/common/chrome-trace:Cargo.toml",
    "//bazel/portage/common/chrome-trace:src/lib.rs",
    "//bazel/portage/common/cliutil:Cargo.toml",
    "//bazel/portage/common/cliutil:src/config.rs",
    "//bazel/portage/common/cliutil:src/lib.rs",
    "//bazel/portage/common/cliutil:src/logging.rs",
    "//bazel/portage/common/cliutil:src/stdio_redirector.rs",
    "//bazel/portage/common/fileutil:Cargo.toml",
    "//bazel/portage/common/fileutil:src/dualpath.rs",
    "//bazel/portage/common/fileutil:src/lib.rs",
    "//bazel/portage/common/fileutil:src/move.rs",
    "//bazel/portage/common/fileutil:src/remove.rs",
    "//bazel/portage/common/fileutil:src/symlink_forest.rs",
    "//bazel/portage/common/fileutil:src/tempdir.rs",
    "//bazel/portage/common/portage/version:Cargo.toml",
    "//bazel/portage/common/portage/version:src/lib.rs",
    "//bazel/portage/common/portage/version:src/version.rs",
    "//bazel/portage/common/testutil:Cargo.toml",
    "//bazel/portage/common/testutil:src/golden.rs",
    "//bazel/portage/common/testutil:src/lib.rs",
    "//bazel/portage/common/testutil:src/namespace.rs",
    "//bazel/portage/common/tracing-chrome-trace:Cargo.toml",
    "//bazel/portage/common/tracing-chrome-trace:src/lib.rs",
]

_LOCK = "//bazel/portage/bin/alchemist:Cargo.lock"
_DEV_SRCS = _DEV_SRCS_NO_LOCK + [_LOCK]

_RELEASE_SRCS = [src for src in _DEV_SRCS if "/testdata/" not in src]

ALCHEMIST_BAZEL_SRCS = [
  Label(x) for x in _DEV_SRCS + SHARED_CRATES
]

ALCHEMIST_REPO_RULE_SRCS = [
  Label(x) for x in _RELEASE_SRCS + _SHARED_CRATE_FILES
]
