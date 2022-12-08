#!/bin/sh

# If we try to use sudo when the sandbox is active, we get ugly warnings that
# just confuse developers.  Disable the sandbox in this case by rexecing.
if [ "${SANDBOX_ON}" = "1" ]; then
  SANDBOX_ON=0 exec "$0" "$@"
else
  unset LD_PRELOAD
fi

export CHOST="${CHOST}"
export PORTAGE_CONFIGROOT="/build/${BOARD}"
export SYSROOT="/build/${BOARD}"
if [ -z "$PORTAGE_USERNAME" ]; then
  export PORTAGE_USERNAME=$(basename "${HOME}")
fi
export ROOT="/build/${BOARD}"
exec sudo -E ${COMMAND} "$@"
