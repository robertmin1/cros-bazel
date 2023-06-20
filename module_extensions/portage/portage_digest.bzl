# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

_PORTAGE_DIGEST_REPO_BUILD_FILE = """
exports_files(["board", "digest", "profile"])
"""

def _portage_digest_repository_impl(repo_ctx):
    """Repository rule to generate a digest of the boards overlays."""

    # Keep all the ctx.path calls first to avoid expensive restarts
    alchemist = repo_ctx.path(repo_ctx.attr.alchemist)

    # --source-dir needs the repo root, not just the `src` directory
    root = repo_ctx.workspace_root.dirname

    # BOARD has the format <board>:<profile>
    board = repo_ctx.os.environ.get("BOARD", "")
    parts = board.split(":", 1)
    if len(parts) > 1:
        board = parts[0]
        profile = parts[1]
    else:
        profile = ""

    # If we don't have a BOARD defined, we need to clear out the repository
    if board:
        # TODO: add a cache_dir argument
        args = [
            alchemist,
            "--board",
            board,
            "--source-dir",
            root,
            "digest-repo",
        ]
        st = repo_ctx.execute(args)
        if st.return_code:
            fail("Error running command %s:\n%s%s" %
                 (args, st.stdout, st.stderr))

        digest = st.stdout
    else:
        digest = ""

    repo_ctx.file("BUILD.bazel", content = _PORTAGE_DIGEST_REPO_BUILD_FILE)

    # Pass the config to the @portage repo
    repo_ctx.file("board", content = board)
    repo_ctx.file("digest", content = digest)
    repo_ctx.file("profile", content = profile)

portage_digest = repository_rule(
    implementation = _portage_digest_repository_impl,
    environ = [
        # See tools/bazel for where this variable is set
        "_CACHE_BUST_DATE",
        "BOARD",
    ],
    attrs = dict(
        alchemist = attr.label(allow_single_file = True),
    ),
    local = True,
)
