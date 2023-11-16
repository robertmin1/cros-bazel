# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# AUTO-GENERATED FILE. DO NOT EDIT.
# To regenerate, run "bazel run //bazel/portage/bin/alchemist/src/bin/alchemist:regen_repo_rule_srcs"

ALCHEMIST_REPO_RULE_SRCS = [
    "@cros//bazel:Cargo.lock",
    "@cros//bazel/portage/bin/alchemist:BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist:src/analyze/dependency.rs",
    "@cros//bazel/portage/bin/alchemist:src/analyze/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/analyze/restrict.rs",
    "@cros//bazel/portage/bin/alchemist:src/analyze/source.rs",
    "@cros//bazel/portage/bin/alchemist:src/bash/expr/eval.rs",
    "@cros//bazel/portage/bin/alchemist:src/bash/expr/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/bash/expr/parser.rs",
    "@cros//bazel/portage/bin/alchemist:src/bash/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/bash/vars.rs",
    "@cros//bazel/portage/bin/alchemist:src/common.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/bundle.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/compiler.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/makeconf/generate/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/makeconf/generate/templates/make.conf",
    "@cros//bazel/portage/bin/alchemist:src/config/makeconf/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/makeconf/parser.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/miscconf/accept_keywords.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/miscconf/bashrc.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/miscconf/mask.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/miscconf/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/miscconf/provided.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/miscconf/useflags.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/profile.rs",
    "@cros//bazel/portage/bin/alchemist:src/config/site.rs",
    "@cros//bazel/portage/bin/alchemist:src/data.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/algorithm.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/package/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/package/parser.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/parser.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/requse/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/requse/parser.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/restrict/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/restrict/parser.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/uri/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/dependency/uri/parser.rs",
    "@cros//bazel/portage/bin/alchemist:src/ebuild/ebuild_prelude.sh",
    "@cros//bazel/portage/bin/alchemist:src/ebuild/metadata.rs",
    "@cros//bazel/portage/bin/alchemist:src/ebuild/mod.rs",
    "@cros//bazel/portage/bin/alchemist:src/fakechroot.rs",
    "@cros//bazel/portage/bin/alchemist:src/fileops.rs",
    "@cros//bazel/portage/bin/alchemist:src/lib.rs",
    "@cros//bazel/portage/bin/alchemist:src/path.rs",
    "@cros//bazel/portage/bin/alchemist:src/repository.rs",
    "@cros//bazel/portage/bin/alchemist:src/resolver.rs",
    "@cros//bazel/portage/bin/alchemist:src/simpleversion.rs",
    "@cros//bazel/portage/bin/alchemist:src/testutils.rs",
    "@cros//bazel/portage/bin/alchemist:src/toolchain/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:alchemist.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:digest_repo.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:dump_package.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:dump_profile.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/common.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/deps.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/overlays/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/overlays/templates/chromiumos-overlay.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/overlays/templates/eclass.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/overlays/templates/overlay.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/overlays/templates/overlays.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/packages/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/packages/templates/package.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/portage_config/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/portage_config/templates/portage-config.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sdk/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sdk/templates/base.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sdk/templates/emerge",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sdk/templates/host.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sdk/templates/pkg-config",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sdk/templates/portage-tool",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sdk/templates/stage1.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sdk/templates/target.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sources/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/internal/sources/templates/source.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/public/mod.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/public/templates/images.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/public/templates/package.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:generate_repo/templates/root.BUILD.bazel",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:main.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:src.bzl",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:ver_rs.rs",
    "@cros//bazel/portage/bin/alchemist/src/bin/alchemist:ver_test.rs",
    "@cros//bazel/portage/common/chrome-trace:BUILD.bazel",
    "@cros//bazel/portage/common/chrome-trace:src/lib.rs",
    "@cros//bazel/portage/common/cliutil:BUILD.bazel",
    "@cros//bazel/portage/common/cliutil:src/config.rs",
    "@cros//bazel/portage/common/cliutil:src/lib.rs",
    "@cros//bazel/portage/common/cliutil:src/logging.rs",
    "@cros//bazel/portage/common/cliutil:src/stdio_redirector.rs",
    "@cros//bazel/portage/common/fileutil:BUILD.bazel",
    "@cros//bazel/portage/common/fileutil:src/dualpath.rs",
    "@cros//bazel/portage/common/fileutil:src/lib.rs",
    "@cros//bazel/portage/common/fileutil:src/move.rs",
    "@cros//bazel/portage/common/fileutil:src/remove.rs",
    "@cros//bazel/portage/common/fileutil:src/symlink_forest.rs",
    "@cros//bazel/portage/common/fileutil:src/tempdir.rs",
    "@cros//bazel/portage/common/portage/version:BUILD.bazel",
    "@cros//bazel/portage/common/portage/version:src/lib.rs",
    "@cros//bazel/portage/common/portage/version:src/version.rs",
    "@cros//bazel/portage/common/tracing-chrome-trace:BUILD.bazel",
    "@cros//bazel/portage/common/tracing-chrome-trace:src/lib.rs",
]