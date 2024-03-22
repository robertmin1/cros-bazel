# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

def _chromite_impl(repo_ctx):
    # Callers can use checked-out Chromite by invoking bazel with
    # `--repo_env=use_pinned_chromite=false`
    use_pinned_chromite = repo_ctx.os.environ.get("use_pinned_chromite") not in ["false", "False"]

    if use_pinned_chromite:
        repo_ctx.download_and_extract(
            url = "https://storage.googleapis.com/chromeos-localmirror/chromite-bundles/chromite-20240409_142939-9369805bd6c6b5f59a92b3a4106eb691594eb06b.tar.zst",
            sha256 = "3222910e09113a8fab81de305cb4add9c2251f9774b6cb4b3b7330753ad2cb8f",
        )
    else:
        # While most repo rules would inject BUILD.project-chromite during the repo
        # rule, since we perform a symlink, doing so would add it to the real
        # chromite directory.
        realpath = str(repo_ctx.workspace_root.realpath).rsplit("/", 1)[0]
        out = repo_ctx.path(".")
        repo_ctx.symlink(realpath + "/chromite", out)

chromite = repository_rule(
    implementation = _chromite_impl,
    environ = ["use_pinned_chromite"],
)
