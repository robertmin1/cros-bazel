# Copyright 2023 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

load("//bazel/module_extensions/portage:alchemist.bzl", "alchemist")
load("//bazel/module_extensions/portage:goma_info.bzl", "goma_info")
load("//bazel/module_extensions/portage:portage.bzl", _portage = "portage")
load("//bazel/module_extensions/portage:portage_digest.bzl", "portage_digest")
load("//bazel/module_extensions/portage:vpython_info.bzl", "vpython_info")
load("//bazel/module_extensions/private:hub_repo.bzl", "hub_init")
load("//bazel/portage/repo_defs/chrome:cros_chrome_repository.bzl", _cros_chrome_repository = "cros_chrome_repository")
load("//bazel/repo_defs:repo_repository.bzl", _repo_repository = "repo_repository")

"""Module extensions to generate the @portage repo.

We have to split this into 2 extensions, because module extensions cannot read
any files generated by repos declared in their own module extension (this would
create circular dependencies). However, they can read files generated by repos
declared in other module extensions."""

def _portage_impl(module_ctx):
    alchemist(name = "alchemist")
    goma_info(
        name = "goma_info",
    )
    portage_digest(
        name = "portage_digest",
        alchemist = "@alchemist//:alchemist",
    )
    vpython_info(
        name = "vpython_info",
    )

    _portage(
        name = "portage",
        board = "@portage_digest//:board",
        profile = "@portage_digest//:profile",
        digest = "@portage_digest//:digest",
        alchemist = "@alchemist//:alchemist",
    )

portage = module_extension(
    implementation = _portage_impl,
)

def _portage_deps_impl(module_ctx):
    deps_path = module_ctx.path(Label("@portage//:deps.json"))

    deps = json.decode(module_ctx.read(deps_path))
    hub = hub_init()
    cros_chrome_repository = hub.wrap_rule(
        _cros_chrome_repository,
        default_targets = {
            "src": "//:src",
            "src_internal": "//:src_internal",
        },
    )
    repo_repository = hub.wrap_rule(
        _repo_repository,
        default_targets = {"src": "//:src"},
    )

    for repo in deps:
        for rule, kwargs in repo.items():
            name = kwargs["name"]
            if rule == "HttpFile":
                hub.http_file.alias_only(**kwargs)
            elif rule == "GsFile":
                hub.gs_file.alias_only(**kwargs)
            elif rule == "RepoRepository":
                repo_repository.alias_only(**kwargs)
            elif rule == "CipdFile":
                hub.cipd_file.alias_only(**kwargs)
            elif rule == "CrosChromeRepository":
                cros_chrome_repository.alias_only(**kwargs)
            else:
                fail("Unknown rule %s" % rule)

    hub.generate_hub_repo(
        name = "portage_deps",
        visibility = ["@portage//:all_packages"],
    )

portage_deps = module_extension(
    implementation = _portage_deps_impl,
)
