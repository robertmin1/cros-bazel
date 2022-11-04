# Copyright 2022 The ChromiumOS Authors.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.
#
# This file assumes it is being run on a linux x86_64 host.

solutions = [
    {
        "name": 'src',
        "url": 'https://chromium.googlesource.com/chromium/src.git@{tag}',
        "deps_file": 'DEPS',
        "managed": True,
        "custom_deps": {},
        "custom_vars": {
            'checkout_src_internal': {internal}
        },
    },
]

# The cache_dir causes more pain than it solves honestly. It requires
# pulling all the refs for chromium which makes it very expensive and
# painful. So we leave it disabled for now.

target_os = ["chromeos"]
# Don't set target_os_only otherwise the host tools won't get installed

target_cpu = ["arm64", "x64"]
# Don't set target_cpu_only otherwise the host cpu tools won't get installed
