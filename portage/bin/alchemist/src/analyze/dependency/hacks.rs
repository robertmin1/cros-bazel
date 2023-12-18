// Copyright 2023 The ChromiumOS Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

use crate::{bash::vars::BashValue, ebuild::PackageDetails};

use super::DependencyKind;

// We don't want to open the flood gates and pull in ALL DEPENDs
// because there are only a handful that are actually BDEPENDs.
// We keep a hand curated list of packages that are known to be
// BDEPENDs. Ideally we upgrade all ebuilds to EAPI7 and delete this
// block, but that's a lot of work.
pub static DEPEND_AS_BDEPEND_ALLOW_LIST: [&str; 22] = [
    "app-misc/jq",
    "app-portage/elt-patches",
    "dev-lang/perl",
    "dev-perl/XML-Parser",
    "dev-python/m2crypto",
    "dev-python/setuptools",
    "dev-util/cmake",
    "dev-util/meson",
    "dev-util/meson-format-array",
    "dev-util/ninja",
    "dev-vcs/git", // TODO: We need to make cros-workon stop calling `git`.
    "sys-apps/texinfo",
    "sys-devel/autoconf",
    "sys-devel/autoconf-archive",
    "sys-devel/automake",
    "sys-devel/bison",
    "sys-devel/flex",
    "sys-devel/gnuconfig",
    "sys-devel/libtool",
    "sys-devel/m4",
    "sys-devel/make",
    "virtual/yacc",
];

// TODO: Remove this hack.
pub fn get_extra_dependencies(
    details: &PackageDetails,
    kind: DependencyKind,
    cross_compile: bool,
) -> String {
    let extra = match (details.as_basic_data().package_name.as_str(), kind) {
        // poppler seems to support building without Boost, but the build fails
        // without it.
        ("app-text/poppler", DependencyKind::Build) => "dev-libs/boost",
        // m2crypt fails to build for missing Python.h.
        ("dev-python/m2crypto", DependencyKind::Build) => "dev-lang/python:3.8",
        // xau.pc contains "Requires: xproto", so it should be listed as RDEPEND.
        ("x11-libs/libXau", DependencyKind::Run) => "x11-base/xorg-proto",

        // x11-misc/compose-tables requires the unprefixed cpp located at
        // /usr/bin/cpp. This symlink points to `clang-cpp`, but the symlink
        // is created by the `gcc` package. x11-misc/compose-tables doesn't
        // actually use GCC for anything other than this symlink.
        // See b/258234653
        ("x11-misc/compose-tables", DependencyKind::BuildHost) => "sys-devel/gcc",
        ("x11-libs/libX11", DependencyKind::BuildHost) => "sys-devel/gcc",

        // The nls use flag claims that gettext is optional, but in reality
        // the ./configure script calls `aclocal` and it expects the gettext
        // macros.
        ("media-libs/libexif", DependencyKind::BuildHost) => "sys-devel/gettext",

        /*
         * /build/arm64-generic/tmp/portage/sys-fs/fuse-2.9.8-r5/work/fuse-2.9.8/missing: line 81: aclocal-1.15: command not found
         * CDPATH="${ZSH_VERSION+.}:" && cd . && /bin/sh /build/arm64-generic/tmp/portage/sys-fs/fuse-2.9.8-r5/work/fuse-2.9.8/missing aclocal-1.15 -I m4
         * configure.ac:74: warning: macro 'AM_ICONV' not found in library
         */
        ("sys-fs/fuse", DependencyKind::BuildHost) => "sys-devel/automake sys-devel/gettext",

        /*
         * checking host system type... Invalid configuration `aarch64-cros-linux-gnu': machine `aarch64-cros' not recognized
         */
        ("dev-libs/libdaemon", DependencyKind::BuildHost) => "sys-devel/gnuconfig",
        ("net-misc/iperf", DependencyKind::BuildHost) => "sys-devel/gnuconfig",

        /*
         * aclocal-1.15: command not found
         *  ./Configure: line 39: which: command not found
         */
        ("sys-processes/lsof", DependencyKind::BuildHost) => "sys-devel/automake sys-apps/which",

        /*
         *  configure.ac:36: warning: macro 'AM_ICONV' not found in library
         */
        ("app-arch/cabextract", DependencyKind::BuildHost) => "sys-devel/gettext",

        // When cross compiling `dev-libs/nss`, it requires `dev-libs/nss` to be
        // installed on the build host. We can't add `dev-libs/nss` as a BDEPEND
        // to the ebuild because that would cause a circular dependency when
        // building for the host.
        // See: https://bugs.gentoo.org/759127
        ("dev-libs/nss", DependencyKind::BuildHost) if cross_compile => "dev-libs/nss",
        // dev-libs/nss needs to run the `shlibsign` binary when installing.
        // When cross-compiling that means we need need to use the build host's
        // `shlibsign`.
        ("dev-libs/nss", DependencyKind::InstallHost) if cross_compile => "dev-libs/nss",

        /*
         * make[2]: Entering directory '/build/arm64-generic/tmp/portage/net-libs/rpcsvc-proto-1.3.1-r4/work/rpcsvc-proto-1.3.1/rpcsvc'
         * rpcgen -h -o klm_prot.h klm_prot.x
         * make[2]: rpcgen: Command not found
         */
        ("net-libs/rpcsvc-proto", DependencyKind::BuildHost) if cross_compile => {
            "net-libs/rpcsvc-proto"
        }

        /*
         * cannot find C preprocessor: cpp
         *
         * We use gcc for `cpp`, we should switch this to clang.
         * /usr/bin/x86_64-pc-linux-gnu-cpp: symbolic link to /usr/x86_64-pc-linux-gnu/gcc-bin/10.2.0/x86_64-pc-linux-gnu-cpp
         */
        ("net-libs/rpcsvc-proto", DependencyKind::BuildHost) if !cross_compile => "sys-devel/gcc",

        /*
         * configure: WARNING: nih-dbus-tool not found, but you are cross-compiling.  Using built copy, which is probably not what you want.  Set NIH_DBUS_TOOL maybe?
         */
        ("sys-libs/libnih", DependencyKind::BuildHost) if cross_compile => "sys-libs/libnih",

        /*
         * bc -c ./libmath.b </dev/null >libmath.h
         * /bin/sh: line 1: bc: command not found
         */
        ("sys-devel/bc", DependencyKind::BuildHost) if cross_compile => "sys-devel/bc",

        /*
         * /bin/sh: line 2: -F/build/arm64-generic/tmp/portage/sys-apps/groff-1.22.4-r2/work/groff-1.22.4/font: No such file or directory
         */
        ("sys-apps/groff", DependencyKind::BuildHost) if cross_compile => "sys-apps/groff",

        /*
         * /bin/sh: line 1: bc: command not found
         * make[2]: *** [/mnt/host/source/src/third_party/kernel/v5.15/./Kbuild:24: include/generated/timeconst.h] Error 127
         *
         * /bin/sh: line 1: perl: command not found
         * make[2]: *** [/mnt/host/source/src/third_party/kernel/v5.15/lib/Makefile:323: lib/oid_registry_data.c] Error 127
         *
         * /build/arm64-generic/tmp/portage/sys-kernel/chromeos-kernel-5_15-9999/temp/environment: line 1659: lz4: command not found
         *
         * /build/arm64-generic/tmp/portage/sys-kernel/chromeos-kernel-5_15-9999/temp/environment: line 1748: fdtget: command not found
         *
         * /build/arm64-generic/tmp/portage/sys-kernel/chromeos-kernel-5_15-9999/temp/environment: line 2436: mkimage: command not found
         *
         * TODO: Update cros-kernel eclass
         */
        ("sys-kernel/chromeos-kernel-5_15", DependencyKind::BuildHost) => {
            "sys-devel/bc dev-lang/perl app-arch/lz4 sys-apps/dtc dev-embedded/u-boot-tools"
        }

        /*
         * checking for compile_et... no
         * configure: error: cannot find compile_et
         * ### /build/arm64-generic/tmp/portage/app-crypt/mit-krb5-1.20.1/work/krb5-1.20.1/src-.arm64/config.log:
         */
        ("app-crypt/mit-krb5", DependencyKind::BuildHost) => "sys-fs/e2fsprogs",

        /*
         * configure:13038: error: possibly undefined macro: AC_LIB_PREPARE_PREFIX
         */
        ("media-libs/libmtp", DependencyKind::BuildHost) => "sys-devel/gettext",

        /*
         * /bin/sh: line 1: glib-mkenums: command not found
         * make: *** [Makefile:1301: gudev/gudevenumtypes.c] Error 127
         */
        ("dev-libs/libgudev", DependencyKind::BuildHost) => "dev-util/glib-utils",

        /*
         *  *    brltty_config ...
         * /usr/bin/env: ‘tclsh’: No such file or directory
         */
        ("app-accessibility/brltty", DependencyKind::BuildHost) => "dev-lang/tcl",

        /*
         * perl ./xml2lst.pl < evdev.xml > evdev.lst
         * /bin/sh: line 1: perl: command not found
         */
        ("x11-misc/xkeyboard-config", DependencyKind::BuildHost) => "dev-lang/perl",

        /*
         * ./Configure: line 39: which: command not found
         * ./Configure: line 2873: perl: command not found
         */
        ("sys-process/lsof", DependencyKind::BuildHost) => "dev-lang/perl sys-apps/which",

        /*
         * /build/arm64-generic/tmp/portage/sys-fs/ecryptfs-utils-108-r5/temp/environment: line 876: intltoolize: command not found
         * ERROR: sys-fs/ecryptfs-utils-108-r5::portage-stable failed (prepare phase):
         * Failed Running glib-gettextize !
         */
        ("sys-fs/ecryptfs-utils", DependencyKind::BuildHost) => "dev-util/intltool dev-libs/glib",

        /*
         * /bin/sh: line 15: soelim: command not found
         */
        ("net-nds/openldap", DependencyKind::BuildHost) => "sys-apps/groff",

        /*
         * We need gcc because chrome uses a bundled ninja that is built against libstdc++.
         *
         * /home/root/chrome_root/src/third_party/ninja/ninja: error while loading shared libraries: libstdc++.so.6: cannot open shared object file: No such file or directory
         *
         * We need lsof for chromeos-chrome to use goma.
         */
        ("chromeos-base/chrome-icu", DependencyKind::BuildHost) => "sys-devel/gcc",
        ("chromeos-base/chromeos-chrome", DependencyKind::BuildHost) => {
            "sys-devel/gcc sys-process/lsof"
        }

        /*
         * b/296430298
         *
         * chromeos-chrome-118.0.5949.0_rc-r1: Traceback (most recent call last):
         * chromeos-chrome-118.0.5949.0_rc-r1:   File "/build/arm64-generic/usr/local/build/autotest/utils/packager.py", line 11, in <module>
         * chromeos-chrome-118.0.5949.0_rc-r1:     import common
         * chromeos-chrome-118.0.5949.0_rc-r1:   File "/build/arm64-generic/usr/local/build/autotest/utils/common.py", line 6, in <module>
         * chromeos-chrome-118.0.5949.0_rc-r1:     import setup_modules
         * chromeos-chrome-118.0.5949.0_rc-r1:   File "/build/arm64-generic/usr/local/build/autotest/client/setup_modules.py", line 3, in <module>
         * chromeos-chrome-118.0.5949.0_rc-r1:     import six
         * chromeos-chrome-118.0.5949.0_rc-r1: ModuleNotFoundError: No module named 'six'
         * chromeos-chrome-118.0.5949.0_rc-r1:  * ERROR: chromeos-base/chromeos-chrome-118.0.5949.0_rc-r1::chromiumos failed (postinst phase):
         */
        ("chromeos-base/chromeos-chrome", DependencyKind::InstallHost) => "dev-python/six",
        /* pkg_postinst: ModuleNotFoundError: No module named 'six' */
        ("chromeos-base/autotest", DependencyKind::InstallHost) => "dev-python/six",

        /*
         * /build/arm64-generic/tmp/portage/net-libs/libmbim-9999/temp/environment: line 3552: git: command not found
         *
         * So this one is annoying. It's an EAPI 6 ebuild, so it doesn't get the git BDEPEND,
         * but we really only need git to get the VCS_ID. We need to update the cros-workon
         * eclass to stop calling git if there is no .git directory.
         */
        ("net-libs/libmbim", DependencyKind::BuildHost) => "dev-vcs/git",
        ("media-libs/minigbm", DependencyKind::BuildHost) => "dev-vcs/git",
        ("media-libs/cros-camera-hal-usb", DependencyKind::BuildHost) => "dev-vcs/git",

        /*
         * /bin/sh: line 1: git: command not found
         *
         * We should fix these packages upstream so it doesn't depend on git.
         */
        ("sys-apps/proot", DependencyKind::BuildHost) => "dev-vcs/git",
        ("app-misc/jq", DependencyKind::BuildHost) => "dev-vcs/git",

        /*
         * b/299325226 - gcc is missing (exec: "gcc": executable file not found in syzkaller-0.0.21ATH)
         */
        ("dev-go/syzkaller", DependencyKind::BuildHost) => "dev-vcs/git sys-devel/gcc",

        /* Our setuptools is way too old. b/293899573 */
        ("dev-python/jinja", DependencyKind::BuildHost) => "dev-python/markupsafe",

        /*
         * /var/tmp/portage/sys-libs/binutils-libs-2.37_p1-r1/work/binutils-2.37/missing: line 81: makeinfo: command not found
         */
        ("sys-libs/binutils-libs", DependencyKind::BuildHost) => "sys-apps/texinfo",

        /*
         * make[1]: flex: Command not found
         */
        ("sys-libs/libsepol", DependencyKind::BuildHost) => "sys-devel/flex",

        /* TODO: I lost the error message */
        ("sys-fs/lvm2", DependencyKind::BuildHost) => "sys-apps/which sys-devel/binutils",
        ("x11-misc/compose-tables", DependencyKind::Build) => "x11-misc/util-macros",

        /*
         * pkg_resources.DistributionNotFound: The 'pip' distribution was not found and is required by the application
         * ERROR: 'pip wheel' requires the 'wheel' package. To fix this, run: pip install wheel
         */
        ("dev-python/jaraco-functools", DependencyKind::BuildHost) => "dev-python/setuptools_scm",
        ("dev-python/tempora", DependencyKind::BuildHost) => "dev-python/setuptools_scm",
        ("dev-python/pyusb", DependencyKind::BuildHost) => "dev-python/setuptools_scm",
        ("dev-python/portend", DependencyKind::BuildHost) => "dev-python/setuptools_scm",
        ("dev-python/cherrypy", DependencyKind::BuildHost) => "dev-python/setuptools_scm",
        ("dev-python/cryptography", DependencyKind::BuildHost) => "dev-python/cffi",

        /*
         * checking XSLTPROC requirement... configure: error: Missing XSLTPROC
         */
        ("dev-libs/opensc", DependencyKind::BuildHost) => {
            "dev-libs/libxslt app-text/docbook-xsl-stylesheets"
        }

        /*
         * /bin/sh: line 1: x86_64-pc-linux-gnu-gcc: command not found
         * make[1]: *** [scripts/Makefile.host:104: scripts/basic/fixdep] Error 127
         *
         * We force busybox to be built with GCC instead of LLVM. We should see if we can use
         * LLVM instead.
         *
         * /bin/sh: line 1: pod2text: command not found
         * /bin/sh: line 1: pod2man: command not found
         * /bin/sh: line 1: pod2html: command not found
         */
        ("sys-apps/busybox", DependencyKind::BuildHost) => "sys-devel/gcc dev-lang/perl",

        /*
         * File "build/servo/data/data_integrity_test.py", line 13, in <module>
         *     import pytest
         * ModuleNotFoundError: No module named 'pytest'
         *
         * Not sure if we should refactor hdctools to not require pytest.
         */
        ("dev-util/hdctools", DependencyKind::BuildHost) => "dev-python/pytest",

        /*
         * /build/arm64-generic/tmp/portage/media-gfx/perceptualdiff-1.1.1-r3/temp/environment: line 2412: cmake: command not found
         *
         * Fix the ebuild to use the cmake eclass.
         */
        ("media-gfx/perceptualdiff", DependencyKind::BuildHost) => "dev-util/cmake",

        /*
         * ninja: error: 'modules/dnn/protobuf::protoc', needed by '/build/arm64-generic/tmp/portage/media-libs/opencv-4.5.5-r1/work/opencv-4.5.5_build-.arm64/modules/dnn/opencv-caffe.pb.cc', missing and no known rule to make it
         */
        ("media-libs/opencv", DependencyKind::BuildHost) => "dev-libs/protobuf",

        /* We need to upgrade distutils-r1 to latest from upstream */
        ("dev-util/meson", DependencyKind::Run) => "dev-python/setuptools",

        /*
         * checking for curl-config... no
         * /build/amd64-generic/tmp/portage/dev-libs/xmlrpc-c-1.51.06-r3/work/xmlrpc-c-1.51.06/configure: line 410: test: then: integer expression expected
         */
        ("dev-libs/xmlrpc-c", DependencyKind::BuildHost) => "net-misc/curl",

        /*
         * /bin/sh: line 1: bison: command not found
         * /bin/sh: line 1: flex: command not found
         */
        ("sys-power/iasl", DependencyKind::BuildHost) => "sys-devel/bison sys-devel/flex",

        /*
         * configure.ac:141: warning: macro 'AM_ICONV' not found in library
         * configure.ac:142: warning: macro 'AM_GNU_GETTEXT' not found in library
         * configure.ac:143: warning: macro 'AM_GNU_GETTEXT_VERSION' not found in library
         * configure.ac:144: warning: macro 'AM_GNU_GETTEXT_REQUIRE_VERSION' not found in library
         */
        ("media-gfx/zbar", DependencyKind::BuildHost) => "sys-devel/gettext virtual/libiconv",

        /*
         * /var/tmp/portage/dev-lang/rust-bootstrap-1.69.0/work/opt/rust-bootstrap-1.68.0/bin/cargo: error while loading shared libraries: libssl.so.1.1: cannot open shared object file: No such file or directory
         */
        ("dev-lang/rust-bootstrap", DependencyKind::BuildHost) => "dev-libs/openssl:PITA",

        _ => "",
    };

    let mut extra = extra.to_string();

    // The eclass will set IDEPEND for EAPI 8+, but we are currently using
    // EAPI7, so this doesn't get set correctly.
    if details.inherited.contains("fcaps") && kind == DependencyKind::InstallHost {
        extra += " sys-libs/libcap";
    }

    extra
}

// TODO: Remove this hack.
pub fn is_rust_source_package(details: &PackageDetails) -> bool {
    let is_rust_package = details.inherited.contains("cros-rust");
    let is_cros_workon_package = details.inherited.contains("cros-workon");
    let has_src_compile = matches!(
        details.metadata.vars.hash_map().get("HAS_SRC_COMPILE"),
        Some(BashValue::Scalar(s)) if s == "1");

    is_rust_package && !is_cros_workon_package && !has_src_compile
}
