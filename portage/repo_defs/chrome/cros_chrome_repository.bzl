# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("@bazel_skylib//lib:paths.bzl", "paths")

def _exec(ctx, cmd, msg = None, retries = 0, **kwargs):
    env = dict(ctx.os.environ)
    env.update(kwargs)
    if msg:
        ctx.report_progress(msg)

    st = None
    for attempt in range(0, retries + 1):
        # Use 3600 as timeout because gclient can take a long time to finish.
        st = ctx.execute(cmd, timeout = 3600, environment = env)
        if st.return_code:
            if attempt == retries:
                fail("Error running attempt %s/%s for command %s:\n%s%s" %
                     (attempt + 1, retries + 1, cmd, st.stdout, st.stderr))
            else:
                print("Error running attempt %s/%s for command %s:\n%s%s\nRetrying." %
                      (attempt + 1, retries + 1, cmd, st.stdout, st.stderr))
        else:
            print("Finished running command %s (attempt %s/%s)" % (cmd, attempt + 1, retries + 1))
            break
    return st.stdout

def _git(ctx, repo, args, msg = None):
    cmd = ["git", "-C", repo] + args
    return _exec(ctx, cmd, msg, retries = 1)

def _cros_chrome_repository_impl(ctx):
    """Repository rule that downloads the Chromium/Chrome source."""

    print("Started fetching Chromium source.")

    tar = ctx.which("tar")
    if not tar:
        fail("tar was not found on the path")

    ctx.template(".gclient", ctx.attr._gclient_template, {
        "{internal}": str(ctx.attr.internal),
        "{tag}": ctx.attr.tag,
    })

    reset_ref = "tags/" + ctx.attr.tag
    fetch_ref = "tags/" + ctx.attr.tag + ":tags/" + ctx.attr.tag

    ctx.delete("src")
    _exec(ctx, ["git", "init", "src"])
    _git(ctx, "src", ["remote", "add", "origin", ctx.attr.remote])
    _git(ctx, "src", ["fetch", "--depth=1", "origin", fetch_ref], "Fetching " + fetch_ref)
    _git(ctx, "src", ["reset", "--hard", reset_ref], "Resetting to " + reset_ref)
    _git(ctx, "src", ["clean", "-xdf"])

    # The chromium repo is huge and gclient will perform a blind `git fetch`
    # that attempts to fetch all the refs. We want to ensure we only pull
    # the specific tag, so we override the fetch config
    _git(
        ctx,
        "src",
        [
            "config",
            "remote.origin.fetch",
            "refs/tags/{}:refs/tags/{}".format(ctx.attr.tag, ctx.attr.tag),
        ],
    )

    _exec(ctx, [
        ctx.attr.gclient,
        "sync",
        "--noprehooks",
        "--nohooks",
        # This unfortunately doesn't change how much data we fetch.
        "--no-history",
        # This still pulls in 10000 commits. I wish we could specify the depth.
        "--shallow",
        "--jobs",
        "12",
    ], "Fetching third_party chromium dependencies")

    pwd = _exec(ctx, ["pwd"]).strip()

    # Set the cache directories so we don't write to the users home directory.
    cipd_cache_dir = paths.join(pwd, ".cipd-cache")
    vpython_root = paths.join(pwd, ".vpython-root")
    depot_tools_path = paths.join(pwd, "src/third_party/depot_tools")

    # Never auto update depot_tools since we won't have network access.
    ctx.file(paths.join(depot_tools_path, ".disable_auto_update"), "")

    # This command will populate the cipd cache and create a python venv.
    _exec(
        ctx,
        [paths.join(depot_tools_path, "ensure_bootstrap")],
        "Downloading depot_tools dependencies",
        PATH = "{}:{}".format(depot_tools_path, ctx.os.environ["PATH"]),
        CIPD_CACHE_DIR = cipd_cache_dir,
        VPYTHON_VIRTUALENV_ROOT = vpython_root,
        DEPOT_TOOLS_DIR = depot_tools_path,
    )

    # Run the hooks with the depot tools pinned by chromium.
    _exec(
        ctx,
        [
            paths.join(depot_tools_path, "gclient"),
            "runhooks",
            "--force",
            "--jobs",
            "12",
        ],
        "Running chromium hooks",
        PATH = "{}:{}".format(depot_tools_path, ctx.os.environ["PATH"]),
        CIPD_CACHE_DIR = cipd_cache_dir,
        VPYTHON_VIRTUALENV_ROOT = vpython_root,
    )

    # See https://reproducible-builds.org/docs/archives/
    tar_common = [
        "tar",
        "--format",
        "gnu",
        "--sort",
        "name",
        "--mtime",
        "1970-1-1 00:00Z",
        "--owner",
        "0",
        "--group",
        "0",
        "--numeric-owner",
        "--exclude-vcs",
        "--auto-compress",
        "--create",
        # r: Apply transformation to regular archive members.
        # S: Do not apply transformation to symbolic link targets.
        # h: Apply transformation to hard link targets.
        "--transform=flags=rSh;s,^,/home/root/chrome_root/,",
    ]

    # Remove CIPD files to make this hermetic.
    ctx.delete("src/third_party/depot_tools/.cipd_bin")

    # Remove CIPD cache files in src/third_party/depot_tools/bootstrap-*_bin/.cipd
    for path in _exec(
        ctx,
        [
            "find",
            "src/third_party/depot_tools",
            "-maxdepth",
            "1",
            "-type",
            "d",
            "-name",
            "bootstrap-*_bin",
        ],
    ).strip("\n").split("\n"):
        ctx.delete(paths.join(path, ".cipd"))

    # Remove depot_tools/metrics.cfg because its contents can be different for
    # each user and it's unecessary.
    ctx.delete("src/third_party/depot_tools/metrics.cfg")

    # Remove reclient_cfgs/reproxy.cfg because its contents contains a full path
    # and it's unnecessary.
    ctx.delete("src/buildtools/reclient_cfgs/reproxy.cfg")

    # We use zstd since it's way faster than gzip and should be installed by
    # default on most distributions. Hopefully the compression algorithm doesn't
    # change between hosts, otherwise the output won't be hermetic.
    #
    # The compressed src should be around ~5GiB, uncompressed it's about 20 GiB.
    _exec(
        ctx,
        tar_common + [
            "--file",
            "src.tar.zst",
            # chromium src and depot_tools with it's own .cipd_bin
            "src",
            # Needed to signal the gclient root
            ".gclient",
            # Hashes of all the dependencies. Useful since we don't include the
            # .git directories.
            ".gclient_entries",
            # We don't include the .vpython-root since it contains absolute
            # symlinks which we can't use inside the chroot. Since we have the
            # cache and pkgs we can recreate it in the chroot without network
            # access.
        ],
        ZSTD_NBTHREADS = "0",
        msg = "Tarring up Chromium src",
    )
    if ctx.attr.internal:
        # We split the src into two tarballs to make it clear that one is only
        # meant for internal consumption.
        _exec(
            ctx,
            tar_common + ["--file", "src-internal.tar.zst", "src-internal"],
            ZSTD_NBTHREADS = "0",
            msg = "Tarring up Chrome src",
        )

    _exec(
        ctx,
        tar_common + [
            "--file",
            "cipd-cache.tar.zst",
            ".cipd-cache",
        ],
        ZSTD_NBTHREADS = "0",
        msg = "Tarring up CIPD cache files",
    )

    ctx.delete(".cipd")
    ctx.delete(".cipd-cache")
    ctx.delete(".gclient")
    ctx.delete(".gclient_entries")
    ctx.delete(".gclient_previous_custom_vars")
    ctx.delete(".gclient_previous_sync_commits")
    ctx.delete(".vpython-root")
    ctx.delete("src")
    if ctx.attr.internal:
        ctx.delete("src-internal")

    ctx.file("WORKSPACE", "workspace(name = \"{name}\")\n".format(name = ctx.name))
    ctx.template("BUILD.bazel", ctx.attr._build_file)

_cros_sdk_repository_attrs = {
    "gclient": attr.label(
        doc = """gclient binary used to fetch chromium.""",
        mandatory = True,
    ),
    "internal": attr.bool(
        doc = """If true download Chrome if false download Chromium.""",
        default = False,
    ),
    "remote": attr.string(
        doc = "The URI of the remote Chromium Git repository",
        default = "https://chromium.googlesource.com/chromium/src.git",
    ),
    "tag": attr.string(
        doc = """The expected SHA-256 of the file downloaded.""",
        mandatory = True,
    ),
    "_build_file": attr.label(
        allow_single_file = True,
        default = ":BUILD.chrome-template",
    ),
    "_gclient_template": attr.label(
        doc = """.gclient template.""",
        default = ":gclient-template.py",
    ),
}

cros_chrome_repository = repository_rule(
    implementation = _cros_chrome_repository_impl,
    attrs = _cros_sdk_repository_attrs,
)
