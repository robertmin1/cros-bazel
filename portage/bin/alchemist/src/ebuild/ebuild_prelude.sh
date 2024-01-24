#!/bin/bash
# Copyright 2022 The ChromiumOS Authors
# Use of this source code is governed by a BSD-style license that can be
# found in the LICENSE file.

# Note: The variables are mangled with the "__xbuild_" prefix to reduce the risk
# of colliding with definitions inside the ebuild and eclasses that are source'd
# below.

if [[ -z "${__xbuild_in_ebuild}" ]]; then
  echo "__xbuild_in_ebuild is not set" >&2
  exit 1
fi

if [[ ! -f "${__xbuild_in_ebuild}" ]]; then
  echo "${__xbuild_in_ebuild} does not exist" >&2
  exit 1
fi

if [[ -z "${__xbuild_in_output_vars}" ]]; then
  echo "__xbuild_in_output_vars is not set" >&2
  exit 1
fi

declare -A __xbuild_eclass_paths

readarray -t __xbuild_eclass_dirs <<< "${__xbuild_in_eclass_dirs}"

# TODO: Is it okay to enable extglob by default?
shopt -s extglob

die() {
  echo "FATAL: $1" >&2
  exit 1
}

inherit() {
  local names=("$@")
  local name path
  for name in "${names[@]}"; do
    path=$(__xbuild_find_eclass "${name}")
    __xbuild_eclass_paths["${path}"]=1
    __xbuild_source_eclass "${name}" "${path}"
  done
}

has() {
  local target="$1"
  shift
  local value
  for value in "$@"; do
    if [[ "${value}" = "${target}" ]]; then
      return 0
    fi
  done
  return 1
}

hasv() {
  if has "$@"; then
    echo "$1"
    return 0
  fi
  return 1
}

hasq() {
  has "$@"
}

debug-print() {
  : # TODO: Implement
}

debug-print-function() {
  local name="$1"
  shift
  debug-print "${name}: entering function" "$@"
}

debug-print-section() {
  debug-print "now in section $*"
}

einfo() {
  echo "INFO: $*" >&2
}

einfon() {
  echo -n "INFO: $*" >&2
}

elog() {
  einfo "$@"
}

ewarn() {
  echo "WARN: $*" >&2
}

eqawarn() {
  echo "WARN(QA): $*" >&2
}

eerror() {
  echo "ERROR: $*" >&2
}

ebegin() {
  : # TODO: Implement
}

eend() {
  : # TODO: Implement
}

EXPORT_FUNCTIONS() {
  local name
  for name in "$@"; do
    eval "function ${name}() { ${ECLASS?}_name; }"
  done
}

# HACK: This variable has been removed upstream, but we still have some packages
# that use it.
export XORG_BASE_INDIVIDUAL_URI="https://www.x.org/releases/individual"

ver_cut() {
  local range="$1"
  local version="$2"
  if [[ -z "${version}" ]]; then
    version="${PV}"
  fi

  local begin end
  case "${range}" in
  +([0-9])) begin="${range}"; end="${range}";;
  +([0-9])-) begin="${range%-}"; end=1000;;
  +([0-9])-+([0-9])) begin="${range%-*}"; end="${range#*-}";;
  *) die "ver_cut: invalid range ${range}";;
  esac

  local versions=('') separators=()
  local head tail
  while :; do
    if [[ -z "${version}" ]]; then
      break
    fi
    tail="${version##*([^A-Za-z0-9])}"
    head="${version:0:$(( ${#version} - ${#tail} ))}"
    separators+=("${head}")
    version="${tail}"

    if [[ -z "${version}" ]]; then
      break
    fi
    case "${version}" in
    [A-Za-z]*) tail=${version##*([A-Za-z])};;
    [0-9]*) tail=${version##*([0-9])};;
    esac
    head="${version:0:$(( ${#version} - ${#tail} ))}"
    versions+=("${head}")
    version="${tail}"
  done

  local i
  for (( i=begin; i<=end; i++ )); do
    echo -n "${versions[$i]}"
    if [[ ${i} -lt ${end} ]]; then
      echo -n "${separators[$i]}"
    fi
  done
}

__xbuild_find_eclass() {
  local name="$1"
  local eclass_dir path result
  # In case of multiple matches, proceed with the latest one as the eclass dirs
  # are in the order from the least-preferred to the most-preferred ones.
  for eclass_dir in "${__xbuild_eclass_dirs[@]}"; do
    path="${eclass_dir}/${name}.eclass"
    if [[ -f "${path}" ]]; then
      result="${path}"
    fi
  done
  [[ -z "${result}" ]] && die "${name}.eclass not found"
  echo -n "${result}"
}

__xbuild_source_eclass() {
  local name="$1"
  local path="$2"

  local saved_ECLASS="${ECLASS}"

  local saved_IUSE="${IUSE}"
  unset IUSE
  local saved_REQUIRED_USE="${REQUIRED_USE}"
  unset REQUIRED_USE
  local saved_DEPEND="${DEPEND}"
  unset DEPEND
  local saved_BDEPEND="${BDEPEND}"
  unset BDEPEND
  local saved_RDEPEND="${RDEPEND}"
  unset RDEPEND
  local saved_PDEPEND="${PDEPEND}"
  unset PDEPEND
  local saved_IDEPEND="${IDEPEND}"
  unset IDEPEND

  ECLASS="${name}"

  source "${path}"

  unset ECLASS
  if [[ -n "${saved_ECLASS}" ]]; then
    ECLASS="${saved_ECLASS}"
  fi
  INHERITED="${INHERITED} ${name}"

  __xbuild_eclass_IUSE="${__xbuild_eclass_IUSE:+${__xbuild_eclass_IUSE} }${IUSE}"
  IUSE="${saved_IUSE}"
  __xbuild_eclass_REQUIRED_USE="${__xbuild_eclass_REQUIRED_USE:+${__xbuild_eclass_REQUIRED_USE} }${REQUIRED_USE}"
  REQUIRED_USE="${saved_REQUIRED_USE}"
  __xbuild_eclass_DEPEND="${__xbuild_eclass_DEPEND:+${__xbuild_eclass_DEPEND} }${DEPEND}"
  DEPEND="${saved_DEPEND}"
  __xbuild_eclass_BDEPEND="${__xbuild_eclass_BDEPEND:+${__xbuild_eclass_BDEPEND} }${BDEPEND}"
  BDEPEND="${saved_BDEPEND}"
  __xbuild_eclass_RDEPEND="${__xbuild_eclass_RDEPEND:+${__xbuild_eclass_RDEPEND} }${RDEPEND}"
  RDEPEND="${saved_RDEPEND}"
  __xbuild_eclass_PDEPEND="${__xbuild_eclass_PDEPEND:+${__xbuild_eclass_PDEPEND} }${PDEPEND}"
  PDEPEND="${saved_PDEPEND}"
  __xbuild_eclass_IDEPEND="${__xbuild_eclass_IDEPEND:+${__xbuild_eclass_IDEPEND} }${IDEPEND}"
  IDEPEND="${saved_IDEPEND}"
}

unset EAPI EBUILD ECLASS INHERITED
EBUILD="${__xbuild_in_ebuild}"
set -- "${__xbuild_in_ebuild}"

source "${__xbuild_in_ebuild}"

# In EAPI=0/1/2/3, RDEPEND=DEPEND if RDEPEND is unset.
# https://projects.gentoo.org/pms/8/pms.html#x1-690007.3.7
case "${EAPI}" in
0|1|2|3)
  if [[ -z "${RDEPEND+x}" ]]; then
    RDEPEND="${DEPEND}"
  fi
esac

# Collect accumulated metadata keys in eclasses.
# https://projects.gentoo.org/pms/8/pms.html#x1-10600010.2
IUSE="${__xbuild_eclass_IUSE:+${__xbuild_eclass_IUSE} }${IUSE}"
REQUIRED_USE="${__xbuild_eclass_REQUIRED_USE:+${__xbuild_eclass_REQUIRED_USE} }${REQUIRED_USE}"
DEPEND="${__xbuild_eclass_DEPEND:+${__xbuild_eclass_DEPEND} }${DEPEND}"
BDEPEND="${__xbuild_eclass_BDEPEND:+${__xbuild_eclass_BDEPEND} }${BDEPEND}"
RDEPEND="${__xbuild_eclass_RDEPEND:+${__xbuild_eclass_RDEPEND} }${RDEPEND}"
PDEPEND="${__xbuild_eclass_PDEPEND:+${__xbuild_eclass_PDEPEND} }${PDEPEND}"
IDEPEND="${__xbuild_eclass_IDEPEND:+${__xbuild_eclass_IDEPEND} }${IDEPEND}"

__xbuild_out_inherit_paths=("${!__xbuild_eclass_paths[@]}")

if [[ "$(type -t src_compile)" == "function" ]]; then
  __xbuild_out_has_src_compile=1
else
  __xbuild_out_has_src_compile=0
fi

set -o posix
set > "${__xbuild_in_output_vars}"
