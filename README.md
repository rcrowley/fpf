fpf: Effing Package Format
==========================

Yes, this is a new package format.  It is very opinionated and perhaps you'll like it.

The plan
--------

1. Format specification.
2. `fpf-build`, `fpf-install`, `fpf-check`, and `fpf-remove`.
3. Repository specification and [Freight](https://github.com/rcrowley/freight) integration.
4. [`fpm`](https://github.com/jordansissel/fpm) integration.

Unfeatures
----------

Actions taken on behalf of a package installation, upgrade, downgrade, or removal can rarely happen without consideration for other systems, which puts responsibility for these actions on the configuration management tool, not the package manager.  This goes equally for user and group management as it does for service restarts.  Therefore: **no maintainer scripts**.

Configuration files are likewise the responsibility of the configuration management tool because they commonly contain references to other systems (database connection credentials, downstream web servers, etc.).  Programs should assume sensible defaults in the absence of their configuration files.  Therefore: **no special handling of configuration files**.

This is 2011 and we all use version control software.  Honestly, we basically all use Git.  Therefore: **no source packages**.

Much to my dismay, many open-source communities promote isolating their dependencies from the rest of the system (for the curious: I prefer faking entire systems with [`lxc`](http://lxc.sourceforge.net/) and [`debootstrap`](http://wiki.debian.org/Debootstrap)) and particularly installing packages as normal users.  A widely-useful package format should support these practices.  Therefore: **remain installation prefix-agnostic** and **don't require `root` privileges**.

Design
------

An FPF package is a `tar`(5) archive of a bare Git repository.  The repository `HEAD` points to a default branched named the same as the package itself.  That branch contains one commit, made by the package maintainer.  That commit's tree contains all the files in the package, relative to the installation prefix, which is unknown to the package maintainer.

Package metadata is stored via `git-config`(1) in the `fpf` section.  The following metadata are allowed:

* `fpf.arch`: pointer size (32 or 64) of target systems.  If not present, the package targets all systems.
* `fpf.name`: package name.
* `fpf.version`: package version number.  See <http://semver.org>.

*Dependency metadata is still under consideration.*

Files and directories in an FPF package may have any access mode, including being `setuid`, `setgid`, `sticky`.  The complete access mode is stored in the Git tree objects in the package and the mode is restored when the package is installed.  Full use of the access mode means that `git-write-tree` and `git-checkout` can't be used directly on the package.

Files and directories are owned by the effective user and group of the `fpf-install` process that installed the package.  This is the least satisfying aspect of the package format: packages containing files that require mixed ownership are out of luck.  On the other hand, the most frequent pattern that calls for mixed ownership is that of `root` owning programs and libraries and a normal user owning data, which should not be a part of a package, anyway.

Objects are compressed in Git repositories so compression of the outer `tar`(5) archive would reclaim little, if any, space and would hinder quickly extracting package metadata.

Package installation is a two step process:

1. Create a working copy of the Git repository.
2. Hard link files from the working copy into place within the installation prefix.

Having a working copy provides another two step process for checking the integrigy of an installed package:

1. Verify the access mode of all files and directories and the link count of all regular files.
2. Verify that the working copy matches the package's Git commit.
