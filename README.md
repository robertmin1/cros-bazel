# rules_ebuild

This is an experiment to build Portage packages with Bazel.

```
$ bazel build //portage-stable/sys-apps/ethtool
$ file bazel-bin/portage-stable/sys-apps/ethtool/ethtool-4.13.tbz2
bazel-bin/portage-stable/sys-apps/ethtool/ethtool-4.13.tbz2: Gentoo binary package (XPAK)
```
