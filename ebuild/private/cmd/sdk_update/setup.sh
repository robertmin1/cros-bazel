#!/bin/bash -ex
# Copyright 2022 The ChromiumOS Authors.
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# HACK: Print all outputs to stderr to avoid shuffled logs in Bazel output.
exec >&2

export LANG=en_US.UTF-8
export PORTAGE_USERNAME=root
export PORTAGE_GRPNAME=root
export RESTRICT="fetch"
export FEATURES="digest -sandbox -usersandbox"  # TODO: turn on sandbox

for i in /stage/tarballs/*; do
  tar -xv -f "${i}" -C /
done

locale-gen --jobs 1

# Patch portage to support binpkg-hermetic.
# Ideally we land https://chromium-review.googlesource.com/c/chromiumos/third_party/portage_tool/+/4018820
# and can remove this hack.
# The patch was generated by running:
# $ git format-patch HEAD~
# $ sed -i -E -e 's|([ab])/bin/|\1/usr/lib64/portage/python3.6/|g' \
#       -e 's|([ab])/lib/portage/|\1/usr/lib64/python3.6/site-packages/portage/|g' \
#       *.patch
patch -i /usr/src/portage/0001-bin-Add-binpkg-hermetic-feature.patch -d / -p 1
patch -i /usr/src/portage/0002-bin-phase-functions-Move-du-stats-into-subshell.patch -d / -p 1
rm /usr/src/portage/*

# TODO: Consider using fakeroot-like approach to emulate file permissions.
sed -i -e '/dir_mode_map = {/,/}/s/False/True/' /usr/lib/python3.6/site-packages/portage/package/ebuild/config.py

# HACK: Allow FEATURES=fakeroot even if UID is 0.
# TODO: Find a better way.
sed -i "s/fakeroot = fakeroot and uid != 0/fakeroot = fakeroot/" /usr/lib/python3.6/site-packages/portage/package/ebuild/doebuild.py

read -ra atoms <<<"${INSTALL_ATOMS_HOST}"
if (( ${#atoms[@]} )); then
  # TODO: emerge is too slow! Find a way to speed up.
  time emerge --oneshot --usepkgonly --nodeps --jobs=16 "${atoms[@]}"
fi

read -ra atoms <<<"${INSTALL_ATOMS_TARGET}"
if (( ${#atoms[@]} )); then
  # TODO: emerge is too slow! Find a way to speed up.
  time ROOT="/build/${BOARD}/" SYSROOT="/build/${BOARD}/" PORTAGE_CONFIGROOT="/build/${BOARD}/" emerge --oneshot --usepkgonly --nodeps --jobs=16 "${atoms[@]}"
fi

# Install libc to sysroot.
# Logic borrowed from chromite/lib/toolchain.py.
# TODO: Stop hard-coding aarch64-cros-linux-gnu.
rm -rf /tmp/libc
mkdir -p /tmp/libc
tar -I "zstd -f" -x -f "/var/lib/portage/pkgs/cross-aarch64-cros-linux-gnu/glibc-"*.tbz2 -C /tmp/libc
mkdir -p "/build/${BOARD}" "/build/${BOARD}/usr/lib/debug"
rsync --archive --hard-links "/tmp/libc/usr/aarch64-cros-linux-gnu/" "/build/${BOARD}/"
rsync --archive --hard-links "/tmp/libc/usr/lib/debug/usr/aarch64-cros-linux-gnu/" "/build/${BOARD}/usr/lib/debug/"

# The portage database contains some non-hermetic install artifacts:
# COUNTER: Since we are installing packages in parallel the COUNTER variable
#          can change depending on when it was installed.
# environment.bz2: The environment contains EPOCHTIME and SRANDOM from when the
#                  package was installed. We could modify portage to omit these,
#                  but I didn't think the binpkg-hermetic FEATURE should apply
#                  to locally installed artifacts. So we just delete the file
#                  for now.
# CONTENTS: This file is sorted in the binpkg, but when portage installs the
#           binpkg it recreates it in a non-hermetic way, so we manually sort
#           it.
# Deleting the files causes a "special" delete marker to be created by overlayfs
# this isn't supported by bazel. So instead we just truncate the files.
for root in '' "/build/$BOARD"; do
  find "$root"/var/db/pkg/ -name environment.bz2 -exec truncate -s 0 '{}' +
  echo '0' > /tmp/zero
  find "$root"/var/db/pkg/ -name COUNTER -exec cp /tmp/zero '{}' \;
  find "$root"/var/db/pkg/ -name CONTENTS -exec sort -o '{}' '{}' \;
done

# So this is kind of annoying, since we monkey patch the .py files above the
# python interpreter will regenerate the bytecode cache. This bytecode file
# has the timestamp of the source file embedded. Once we stop monkey patching
# python and get the changed bundled in the SDK we can delete the following
# lines.
truncate -s 0 \
  /usr/lib64/python3.6/site-packages/portage/dbapi/__pycache__/vartree.cpython-36.pyc \
  /usr/lib64/python3.6/site-packages/portage/package/ebuild/__pycache__/config.cpython-36.pyc \
  /usr/lib64/python3.6/site-packages/portage/package/ebuild/__pycache__/doebuild.cpython-36.pyc \
  /usr/lib64/python3.6/site-packages/portage/__pycache__/const.cpython-36.pyc
