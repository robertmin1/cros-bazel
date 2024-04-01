# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

def cros_sdk_repositories(http_file):
    http_file(
        name = "cros-sdk",
        sha256 = "9a8689236881de6fbd7cc8981693d78202f1ded8cb52f32ecdea4896820005df",
        urls = ["https://storage.googleapis.com/chromiumos-sdk/cros-sdk-2024.04.01.020054.tar.xz"],
        downloaded_file_path = "sdk.tar.xz",
    )

    http_file(
        name = "cros-bazel-sdk",
        sha256 = "fdd242a81296072c83ceb8089ee92882d8e57b600c8c01651447c350416a7d9a",
        urls = ["https://storage.googleapis.com/chromiumos-sdk/cros-bazel-sdk-2024.01.08.tar.zst"],
        downloaded_file_path = "cros-bazel-sdk.tar.zst",
    )
