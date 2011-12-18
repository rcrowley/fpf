FPF: Effing Package Format
==========================

This is a new package format.  It strives to remove considerations for problems we no longer have, simplify the package maintainer's life by doing less in better defined ways, and play nicely with other package managers.

The plan
--------

1. FPF specification.
2. `fpf-build`, `fpf-install`, `fpf-check`, and `fpf-remove`.
3. [FPR specification](https://github.com/rcrowley/fpr) and [Freight](https://github.com/rcrowley/freight) integration.
4. [`fpm`](https://github.com/jordansissel/fpm) integration.

Unfeatures
----------

Actions taken on behalf of a package installation, upgrade, downgrade, or removal can rarely happen without consideration for other systems, which puts responsibility for these actions on the configuration management tool, not the package manager.  This goes equally for user and group management as it does for service restarts.  Therefore: **no maintainer scripts**.

Configuration files are likewise the responsibility of the configuration management tool because they commonly contain references to other systems (database connection credentials, downstream web servers, etc.).  Programs should assume sensible defaults in the absence of their configuration files.  Therefore: **no special handling of configuration files**.

This is 2011 and we all use version control software.  Honestly, we basically all use Git.  Therefore: **no source packages**.

Much to my dismay, many open-source communities promote isolating their dependencies from the rest of the system (for the curious: I prefer faking entire systems with [`lxc`](http://lxc.sourceforge.net/) and [`debootstrap`](http://wiki.debian.org/Debootstrap)) and particularly installing packages as normal users.  A widely-useful package format should support these practices.  Therefore: **remain installation prefix-agnostic** and **don't require `root` privileges**.

Design
------

An FPF package is a `tar`(5) archive of a bare Git repository.  The repository `HEAD` points to a default branch named the same as the package itself.  That branch contains one commit, made by the package maintainer.  That commit's tree contains all the files in the package, relative to the installation prefix, which is unknown to the package maintainer.

Package metadata is stored via `git-config`(1) in the `fpf` section.  The following metadata are allowed:

* `fpf.arch`: target architecture (`amd64`, `x86_64`, `i386`, etc.).  If not present, the package targets all systems.
* `fpf.name`: package name.
* `fpf.version`: package version number.  See <http://semver.org>.

Dependency metadata is likewise stored via `git-config`(1).  FPF packages may declare dependencies on packages managed by other package managers, so all dependencies are qualified with their package manager.  For example, the following Git `config` section declares dependencies on `foo` from APT and `bar` from FPF:

	[apt "foo"]
		version = 0.0.0-1
	[fpf "bar"]
		version = 0.0.0
		pinned = true

The following package managers are supported; they should be examined in this order during installation:

1. `apt`  (Only examined if `apt-get` and `dpkg` are available on `PATH`.)
2. `yum`  (Only examined if `yum` and `rpm` are available on `PATH`.)
3. `cpan`
4. `gem`
5. `npm`
6. `pear`
7. `pecl`
8. `pip`
9. `fpr`

The values of the `git-config`(1) names `apt.foo.version` and `fpf.bar.version` above specify a version number in the format expected by the associated package manager.  Because `fpf.bar.pinned` is `true`, FPF insists this exact version number be present to satisfy the dependency.

Files and directories in an FPF package may have any access mode, including being `setuid`, `setgid`, `sticky`.  The complete access mode is stored in the Git tree objects in the package and the mode is restored when the package is installed.  Full use of the access mode means that `git-write-tree` and `git-checkout` can't be used directly on the package.

Files and directories are owned by the effective user and group of the `fpf-install` process that installed the package.  This is the least satisfying aspect of the package format: packages containing files that require mixed ownership are out of luck.  On the other hand, the most frequent pattern that calls for mixed ownership is that of `root` owning programs and libraries and a normal user owning data, which should not be a part of a package, anyway.

Objects are compressed in Git repositories so compression of the outer `tar`(5) archive would reclaim little, if any, space and would hinder quickly extracting package metadata.

Package installation begins by extracting the bare Git repository into a temporary location.  After reading package metadata, the package can be moved into <code><em>prefix</em>/lib/fpf/<em>name</em>.git</code>.  The repository should be made non-bare and a working copy should be checked out in <code><em>prefix</em></code>.  `git-checkout`(1) can't be used here because it does not respect the full access mode stored in Git tree objects.

The integrity of an installed package may be verified by `git-status`(1), `git-diff-files`(1), and friends.

Quirks
------

* Dependencies managed by APT, Yum, PEAR, and PECL can only be installed system-wide so these packages are installed using `sudo`(8).
* Dependencies managed by RubyGems and `pip` are currently installed system-wide using `sudo`(8) but this should be made configurable.
* Dependencies managed by NPM are installed in `$PREFIX/lib/node_modules`.  This may be a horrible idea and needs to be run past a real Node programmer.

TODO
----

* Make dependencies that weren't already satisfied eligible for rollback.
* Verifiy that dependencies are satisfied after installing the latest version.

TODONE
------

* Build packages.
* Install packages.
* Check package integrity.
* Install dependencies.

Related material
----------------

* <http://twitter.theinfo.org/146678092239339520>
