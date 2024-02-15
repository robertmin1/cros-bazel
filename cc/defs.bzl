# Copyright 2024 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("@bazel_skylib//rules:common_settings.bzl", "BuildSettingInfo")
load(
    "@rules_cc//cc:defs.bzl",
    _cc_binary = "cc_binary",
    _cc_library = "cc_library",
)
load("//bazel/module_extensions/toolchains:hermetic_launcher.bzl", "HERMETIC_ATTRS", "hermetic_defaultinfo")

visibility("public")

# https://bazel.build/reference/be/common-definitions#common-attributes
_COMMON_BUILD_ARGS = [
    "compatible_with",
    "deprecation",
    "distribs",
    "exec_compatible_with",
    "exec_properties",
    "features",
    "restricted_to",
    "tags",
    "target_compatible_with",
    "testonly",
    "toolchains",
    "visibility",
]

# https://bazel.build/reference/be/common-definitions#common-attributes-binaries
_COMMON_BIN_ARGS = [
    "args",
    "env",
    "output_licenses",
]

# https://bazel.build/reference/be/common-definitions#common-attributes-tests
_COMMON_TEST_ARGS = [
    "args",
    "env",
    "env_inherit",
    "size",
    "timeout",
    "flaky",
    "shard_count",
    "local",
]

def _hermetic_launcher_impl(ctx):
    info = ctx.attr.bin[DefaultInfo]
    return [hermetic_defaultinfo(
        ctx,
        files = info.files,
        executable = ctx.executable.bin,
        runfiles = info.default_runfiles,
        symlink = not ctx.attr.enable[BuildSettingInfo].value,
    )]

_WRAPPER_KWARGS = dict(
    implementation = _hermetic_launcher_impl,
    attrs = dict(
        bin = attr.label(mandatory = True, executable = True, cfg = "exec"),
        enable = attr.label(mandatory = True, providers = [BuildSettingInfo]),
    ) | HERMETIC_ATTRS,
    executable = True,
)

_hermetic_launcher_nontest = rule(**_WRAPPER_KWARGS)
_hermetic_launcher_test = rule(test = True, **_WRAPPER_KWARGS)

def _hermetic_launcher(is_test):
    """Generates a macro that wraps a rule to ensure it runs hermetically.

    Args:
        rule_type: rule: The rule to wrap (eg. cc_binary).
        is_test: bool: Whether the rule is a test rule.
    Returns:
        A macro wrapping the rule with a hermetic launcher.
    """
    wrapper_rule = _hermetic_launcher_test if is_test else _hermetic_launcher_nontest

    def wrapper(name, visibility = None, **kwargs):
        # The hard part here is determining which kwargs should go to the
        # cc_binary rule, which should go to the launcher, and which should go
        # to both.
        wrapper_args = {}
        inner_args = {}
        for k, v in kwargs.items():
            if k in _COMMON_BUILD_ARGS or k in _COMMON_BIN_ARGS:
                # Attributes such as testonly are relevant for both the inner
                # and outer rules.
                wrapper_args[k] = v
                inner_args[k] = v
            elif k in _COMMON_TEST_ARGS:
                # If this is a non-test rule, this allows bazel itself to handle
                # the error.
                wrapper_args[k] = v
            else:
                inner_args[k] = v

        _cc_binary(
            name = name + ".elf",
            visibility = ["//visibility:private"],
            **inner_args
        )

        wrapper_rule(
            name = name,
            bin = name + ".elf",
            enable = "@cros//bazel/module_extensions/toolchains/cc:hermetic",
            visibility = visibility,
            **wrapper_args
        )

    return wrapper

cc_binary = _hermetic_launcher(is_test = False)
cc_test = _hermetic_launcher(is_test = True)
cc_library = _cc_library