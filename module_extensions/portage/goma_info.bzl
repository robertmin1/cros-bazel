# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

_GOMA_INFO_REPO_BUILD_FILE = """
exports_files(["goma_info"])
"""

_ENVIRON = [
    "GCE_METADATA_HOST",
    "GCE_METADATA_IP",
    "GCE_METADATA_ROOT",
    "GOMA_ARBITRARY_TOOLCHAIN_SUPPORT",
    "GOMA_BACKEND_SOFT_STICKINESS",
    "GOMA_GCE_SERVICE_ACCOUNT",
    "GOMA_MAX_COMPILER_DISABLED_TASKS",
    "GOMA_RPC_EXTRA_PARAMS",
    "GOMA_SERVER_HOST",
]

def _goma_info_repository_impl(repo_ctx):
    """Repository rule to generate info needed to use goma."""

    goma_info_dict = {
        "use_goma": repo_ctx.os.environ.get("USE_GOMA") == "true",
        "envs": {},
    }

    for env in _ENVIRON:
        var = repo_ctx.os.environ.get(env)
        if var:
            goma_info_dict["envs"][env] = var

    # Use GOMA_OAUTH2_CONFIG_FILE as the oauth2 config file path if specified.
    # Otherwise, use "$HOME/.goma_client_oauth2_config" if exists.
    oauth2_config_file = repo_ctx.os.environ.get("GOMA_OAUTH2_CONFIG_FILE")
    if not oauth2_config_file:
        home = repo_ctx.os.environ.get("HOME")
        if home:
            default_oauth2_config_file = home + "/.goma_client_oauth2_config"
            if repo_ctx.path(default_oauth2_config_file).exists:
                oauth2_config_file = default_oauth2_config_file
    if oauth2_config_file:
        goma_info_dict["oauth2_config_file"] = oauth2_config_file

    luci_context = repo_ctx.os.environ.get("LUCI_CONTEXT")
    if luci_context:
        goma_info_dict["luci_context"] = luci_context

    # TODO(b/300218625): Remove this to make this failure fatal when this becomes stable.
    if goma_info_dict["use_goma"] and not (
        goma_info_dict["envs"].get("GOMA_GCE_SERVICE_ACCOUNT") or
        goma_info_dict.get("luci_context") or goma_info_dict.get("oauth2_config_file")
    ):
        print("USE_GOMA is set to true, but no valid auth is provided. Force-disabling goma.")
        goma_info_dict["use_goma"] = False

    if goma_info_dict["use_goma"]:
        print("Goma is enabled. Going to use goma to build chromeos-chrome.")
        print("luci_context=" + str(goma_info_dict.get("luci_context")))
        print("oauth2_config_file=" + str(goma_info_dict.get("oauth2_config_file")))
        print("envs=" + str(goma_info_dict.get("envs")))

    goma_info = json.encode(goma_info_dict)

    repo_ctx.file("goma_info", content = goma_info)
    repo_ctx.file("BUILD.bazel", content = _GOMA_INFO_REPO_BUILD_FILE)

goma_info = repository_rule(
    implementation = _goma_info_repository_impl,
    environ = _ENVIRON + [
        "GOMA_OAUTH2_CONFIG_FILE",
        "HOME",
        "LUCI_CONTEXT",
        "USE_GOMA",
    ],
    local = True,
)
