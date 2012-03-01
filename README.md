FPF: Effing Package Format
==========================

This is a new package format.  It strives to remove considerations for problems we no longer have, simplify the package maintainer's life by doing less in better defined ways, and play nicely with other package managers.  There's very little to the online package archive format and that's what makes it great.

The plan
--------

1. Package file format specification.
2. `fpf-build`, `fpf-install-package`, `fpf-check`, and `fpf-remove`.
3. Archive format specification and [Freight](https://github.com/rcrowley/freight) integration.
4. `fpf-install`, `fpf-add-archive`, and `fpf-remove-archive`.
5. [`fpm`](https://github.com/jordansissel/fpm) integration.

Unfeatures
----------

Actions taken on behalf of a package installation, upgrade, downgrade, or removal can rarely happen without consideration for other systems, which puts responsibility for these actions on the configuration management tool, not the package manager.  This goes equally for user and group management as it does for service restarts.  Therefore: **no maintainer scripts**.

Configuration files are likewise the responsibility of the configuration management tool because they commonly contain references to other systems (database connection credentials, downstream web servers, etc.).  Programs should assume sensible defaults in the absence of their configuration files.  Therefore: **no special handling of configuration files**.

This is 2012 and we all use version control software.  Honestly, we basically all use Git.  Therefore: **no source packages**.

Much to my dismay, many open-source communities promote isolating their dependencies from the rest of the system (for the curious: I prefer faking entire systems with [`lxc`](http://lxc.sourceforge.net/) and [`debootstrap`](http://wiki.debian.org/Debootstrap)) and installing packages as normal users.  A widely-useful package format should support these practices.  Therefore: **remain installation prefix-agnostic** and **don't require `root` privileges**.

Design
------

An FPF package is a `tar`(5) archive of a bare Git repository.  The repository `HEAD` points to a default branch named the same as the package itself.  That branch contains one commit, made by the package maintainer.  That commit's tree contains all the files in the package, relative to the installation prefix, which is unknown to the package maintainer.

Package metadata is stored via `git-config`(1) in the `fpf` section.  The following metadata are defined:

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
9. `fpf`

The values of the `git-config`(1) names `apt.foo.version` and `fpf.bar.version` above specify a version number in the format expected by the associated package manager.  Because `fpf.bar.pinned` is `true`, FPF insists this exact version number be present to satisfy the dependency.

Files and directories in an FPF package may have any access mode, including being `setuid`, `setgid`, or `sticky`.  The complete access mode is stored in the Git tree objects in the package and the mode is restored when the package is installed.  Full use of the access mode means that `git-write-tree` and `git-checkout` can't be used directly on the package.

Files and directories are owned by the effective user and group of the `fpf-install-package` process that installed the package.  This is the least satisfying aspect of the package format: packages containing files that require mixed ownership are out of luck.  On the other hand, the most frequent pattern that calls for mixed ownership is that of `root` owning programs and libraries and a normal user owning data, which should not be a part of a package, anyway.

Objects are compressed in Git repositories so compression of the outer `tar`(5) archive would reclaim little, if any, space and would hinder quickly extracting package metadata.

Package installation begins by extracting the bare Git repository into a temporary location.  After reading package metadata, the package can be moved into <code><em>prefix</em>/lib/fpf/<em>name</em>.git</code>.  The repository should be made non-bare and a working copy should be checked out in <code><em>prefix</em></code>.  `git-checkout`(1) can't be used here because it does not respect the full access mode stored in Git tree objects.

The integrity of an installed package may be verified by `git-status`(1), `git-diff-files`(1), and friends.

FPF package archives should be served over HTTP.  An archive is identified by its URL, which should be a directory containing `index.txt`.  Each line of this file lists the pathname (relative to the archive) and SHA1 sum of a package in the same format as `sha1sum`(1): the SHA1 sum, two spaces, and the pathname.

The pathnames that appear in `index.txt` contain several significant components.  They must take one of the two forms:

* <code><em>name</em>/<em>version</em>/<em>filename</em>.fpf</code>
* <code><em>name</em>/<em>version</em>/<em>arch</em>/<em>filename</em>.fpf</code>

The _name_, _version_, and optional _arch_ have the same meaning as the metadata stored within the package.  The pathnames may contain other leading directories.  The format of the filename is unspecified but it's a good idea to use <code><em>name</em>-<em>version</em>.<em>arch</em>.fpf</code>.

As an example, consider version `0.0.0` of the package `foo` for all architectures in the archive `http://example.com/example`.  The following are valid URLs for the package file:

* `http://example.com/example/foo/0.0.0/foo-0.0.0.fpf`
* `http://example.com/example/foo/0.0.0/whatever.fpf`
* `http://example.com/whatever/foo/0.0.0/foo-0.0.0.fpf`

The following are invalid:

* `http://example.com/example/foo-0.0.0.fpf`: the package file is not in its name and version directories.
* `http://example.com/example/foo/foo-0.0.0.fpf`: the package file is not in its version directory.
* `http://example.com/example/foo-0.0.0/foo-0.0.0.fpf`: the package file is not in its name or version directories.

Suppose `http://example.com/example/foo/0.0.0/foo-0.0.0.fpf` is the URL of the package file with SHA1 sum `0123456789012345678901234567890123456789` in the `http://example.com/example` archive.  `http://example.com/example/index.txt` must contain the following line:

	0123456789012345678901234567890123456789  foo/0.0.0/foo-0.0.0.fpf

The integrity of files within a package may be verified from the SHA1 sums maintained in the Git object store.  The integrity of a complete FPF package may be verified by its SHA1 sum as compared to the SHA1 sum that appears in `index.txt`.  The integrity of `index.txt` may be verified by the GPG signature in `index.txt.gpg`.

The GPG public keys necessary to perform this verification must be distributed ahead-of-time and are expected in the <code><em>prefix</em>/lib/fpf/keyring.gpg</code> keyring.

Quirks
------

* Dependencies managed by APT, Yum, PEAR, and PECL can only be installed system-wide so these packages are installed using `sudo`(8).
* Dependencies managed by RubyGems and `pip` are currently installed system-wide using `sudo`(8) but this should be made configurable.
* Dependencies managed by NPM are installed in `$PREFIX/node_modules`.  This may be a horrible idea.

TODO
----

* Decide how to allow RubyGems and `pip` to run as a normal user.
  * Support for Bundler and Virtualenv are also desirable.
* Give two shits (one shit each) about PEAR/PECL.
* Remove GPG public keys when they're no longer referenced by any archives.
* Test `fpf-install` and other archive-related features and tools.

TODONE
------

* Build packages.
* Install packages.
* Check package integrity.
* Install dependencies.
* Verify that a dependency is indeed satisfied after blindly installing the latest version from upstream.

Related material
----------------

* <http://twitter.theinfo.org/146678092239339520>
