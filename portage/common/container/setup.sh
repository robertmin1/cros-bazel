#!/bin/bash -ex
# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# HACK: Print all outputs to stderr to avoid shuffled logs in Bazel output.
if [[ $# -gt 0 ]]; then
  exec >&2
fi

export LANG=en_US.UTF-8

# TODO: Move these Portage-specific variables to somewhere else.
if [[ -v "BOARD" ]]; then
  export ROOT="/build/${BOARD}/"
else
  export ROOT="/"
fi
export SYSROOT="${ROOT}"
export PORTAGE_CONFIGROOT="${ROOT}"
export PORTAGE_USERNAME=root
export PORTAGE_GRPNAME=root
export RESTRICT="fetch binchecks"
export FEATURES="binpkg-hermetic -sandbox -usersandbox -ipc-sandbox -mount-sandbox -network-sandbox -pid-sandbox"
export CCACHE_DISABLE=1

if [[ -v _LOGIN_MODE ]]; then
  LOGIN_MODE="${_LOGIN_MODE}"
  # Remove our private variable from the environment
  unset _LOGIN_MODE
else
  LOGIN_MODE=""
fi

if [[ -v _TERM ]]; then
  TERM="${_TERM}"
  # Remove our private variable from the environment
  unset _TERM
fi

invoke-bash() {
  # When bash runs in interactive mode, it creates a new processes group
  # id (PGID) and sets the terminal's processes group id (TPGID) to the newly
  # created processes group id. This allows the signals generated by Ctrl+C,
  # Ctrl+Z, etc to be handled correctly. When bash exits, the TPGID will be
  # left pointing to the terminated processes, so we need to update the TPGID
  # to restore correct signal keyboard signal handling. Ideally we can just
  # restore the TPGID that was set before we invoked bash, which is the same as
  # the PGID that this script is currently executing as. The problem is that
  # `tcgetpgrp` returns 0 because the PGID that we are executing with was
  # created outside of the PID namespace, so we no longer have access to it.
  if [[ -v TERM ]]; then
    TERM="${TERM}" bash || true
  else
    bash || true
  fi

  # Notify the ancestor that is outside the container to reset the TPGID
  printf 't' > /.control
}

if [[ "${LOGIN_MODE}" == "before" ]]; then
  invoke-bash
fi

if [[ -z "${LOGIN_MODE}" ]]; then
  exec "$@"
fi

if "$@"; then
  RC=0
else
  RC="$?"
fi

if [[ "${LOGIN_MODE}" == "after" ]]; then
  invoke-bash
elif [[ "${LOGIN_MODE}" == "after-fail" && "${RC}" -ne 0 ]]; then
  invoke-bash
fi

exit "${RC}"
