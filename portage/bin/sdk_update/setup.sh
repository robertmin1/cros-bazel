#!/bin/bash -ex
# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# HACK: Print all outputs to stderr to avoid shuffled logs in Bazel output.
exec >&2

export LANG=en_US.UTF-8

for i in /stage/tarballs/*; do
  tar -xv -f "${i}" -C /
done

locale-gen --jobs 1

export SOURCE_DATE_EPOCH=946710000

for PYTHON_VERSION in python3.6 python3.8
do
  if ! command -v "${PYTHON_VERSION}" > /dev/null; then
    continue
  fi

  # Python 3.8 changed the lib dir path.
  PYTHON_LIBDIR=lib
  if [[ "${PYTHON_VERSION}" == "python3.6" ]]; then
    PYTHON_LIBDIR=lib64
  fi

  # Patch portage to support binpkg-hermetic.
  # Ideally we land https://chromium-review.googlesource.com/c/chromiumos/third_party/portage_tool/+/4018820
  # and can remove this hack.
  # The patch was generated by running:
  # $ git format-patch HEAD~
  # $ sed -i -E -e 's|([ab])/bin/|\1/usr/PYTHON_LIBDIR/portage/PYTHON_VERSION/|g' \
  #       -e 's|([ab])/lib/portage/|\1/usr/PYTHON_LIBDIR/PYTHON_VERSION/site-packages/portage/|g' \
  #       *.patch
  patch -d "/" -p 1 < <(
    sed -e "s/PYTHON_VERSION/${PYTHON_VERSION}/g" \
        -e "s/PYTHON_LIBDIR/${PYTHON_LIBDIR}/g" \
      /usr/src/portage/0001-bin-Add-binpkg-hermetic-feature.patch \
      /usr/src/portage/0002-bin-phase-functions-Move-du-stats-into-subshell.patch \
      /usr/src/portage/0003-config-Don-t-directly-modify-FEATURES.patch \
      /usr/src/portage/0004-CHROMIUM-Disable-pretend-phase-when-invoking-ebuild.patch \
      /usr/src/portage/0005-b-293714014-Print-extra-logging-in-check_locale.patch
  )

  # TODO: Consider using fakeroot-like approach to emulate file permissions.
  sed -i -e '/dir_mode_map = {/,/}/s/False/True/' \
    "/usr/${PYTHON_LIBDIR}/${PYTHON_VERSION}/site-packages/portage/package/ebuild/config.py"

  # HACK: Allow FEATURES=fakeroot even if UID is 0.
  # TODO: Land https://chromium-review.googlesource.com/c/chromiumos/third_party/portage_tool/+/4519681
  sed -i "s/fakeroot = fakeroot and uid != 0/fakeroot = fakeroot/" \
    "/usr/${PYTHON_LIBDIR}/${PYTHON_VERSION}/site-packages/portage/package/ebuild/doebuild.py"

  "${PYTHON_VERSION}" -m compileall "/usr/${PYTHON_LIBDIR}/${PYTHON_VERSION}/site-packages/portage/"
done

rm -f /usr/src/portage/*
