# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("//bazel/module_extensions/cros_deps/depot_tools:repositories.bzl", "depot_tools")

def _cros_deps_impl(module_ctx):
    depot_tools(name = "depot_tools")

cros_deps = module_extension(
    implementation = _cros_deps_impl,
)