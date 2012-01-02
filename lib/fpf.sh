# `fpf_arch`
#
# Write the architecture of this system to standard output.
fpf_arch() {
	dpkg --print-architecture 2>"/dev/null" ||
	rpm --eval "%_arch" 2>"/dev/null"
}

# `fpf_deps_apt_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency with APT.  Add rollback instructions to the transaction
# log and to `git-config`(1) for `fpf-remove`.
fpf_deps_apt_install() {
	ROLLBACK_VERSION="$(fpf_dpkg_version "$1")"
	if [ "$ROLLBACK_VERSION" ]
	then echo "sudo apt-get -q -y install \"$1=$ROLLBACK_VERSION\""
	else echo "sudo apt-get -q -y remove \"$1\""
	fi >&3
	git config "apt.$1.rollback-version" "$ROLLBACK_VERSION"
	if [ "$3" ]
	then fpf_if_deps sudo apt-get -q -y install "$1=$2"
	else
		dpkg --compare-versions "$ROLLBACK_VERSION" ge "$2" ||
		fpf_if_deps sudo apt-get -q -y install "$1"
		fpf_if_deps -q dpkg --compare-versions "$(
			fpf_dpkg_version "$1"
		)" ge "$2"
	fi
}

# `fpf_deps_apt_remove "$NAME"`
#
# TODO
fpf_deps_apt_remove() {
	ROLLBACK_VERSION="$(git config "apt.$1.rollback-version" || true)"
	if [ "$ROLLBACK_VERSION" ]
	then sudo apt-get -q -y install "$1=$ROLLBACK_VERSION"
	else sudo apt-get -q -y remove "$1"
	fi >&3
}

# `fpf_deps_yum_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency with Yum.
fpf_deps_yum_install() {
	ROLLBACK_VERSION="$(fpf_rpm_version "$1")"
	if [ "$ROLLBACK_VERSION" ]
	then echo "sudo yum -q -y install \"$1-$ROLLBACK_VERSION\""
	else echo "sudo yum -q -y remove \"$1\""
	fi >&3
	if [ "$3" ]
	then fpf_if_deps sudo yum install "$1-$2"
	else
		fpf_rpmvercmp "$ROLLBACK_VERSION" ">=" "$2" ||
		fpf_if_deps sudo yum install "$1"
		fpf_if_deps -q fpf_rpmvercmp "$(fpf_rpm_version "$1")" ">=" "$2"
	fi
}

# `fpf_deps_cpan_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency from CPAN.
fpf_deps_cpan_install() {
	[ "$2" != 0 -o "$3" ] &&
	echo "fpf: CPAN can only install the latest version" >&2
	fpf_if_deps cpan install "$1"
}

# `fpf_deps_gem_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency from RubyGems.
fpf_deps_gem_install() {
	[ "$3" ] && V="$2" || V=">= $2"
	gem list -i -q -v"$V" "$1" >"/dev/null" ||
	fpf_if_deps sudo gem install -v"$V" "$1"
}

# `fpf_deps_npm_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency from NPM.
fpf_deps_npm_install() {
	mkdir -p "$PREFIX/lib"
	(
		cd "$PREFIX/lib"
		if [ "$3" ]
		then fpf_if_deps npm install "$1@$2"
		else fpf_if_deps npm install "$1@>=$2"
		fi
	)
}

# `fpf_deps_pear_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency from PEAR.
fpf_deps_pear_install() {
	fpf_deps_php_install "pear" "$1" "$2" "$3"
}

# `fpf_deps_pecl_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency from PECL.
fpf_deps_pecl_install() {
	fpf_deps_php_install "pecl" "$1" "$2" "$3"
}

# `fpf_deps_php_install "$PROGNAME" "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency from PEAR or PECL.
fpf_deps_php_install() {
	echo "sudo \"$1\" uninstall \"$2\"" >&3
	ROLLBACK_VERSION="$(
		sudo "$1" info "$2" | grep "^Release Version" | awk '{print $3}'
	)"
	if [ "$ROLLBACK_VERSION" ]
	then echo "sudo "$1" install \"$2-$ROLLBACK_VERSION\""
	fi >&3
	if [ "$4" ]
	then fpf_if_deps sudo "$1" install "$2-$3"
	else fpf_if_deps sudo "$1" install "$2"
	fi
}

# `fpf_deps_pip_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency from PyPI.
fpf_deps_pip_install() {
	ROLLBACK_VERSION="$(sudo pip freeze | grep "^$1" | cut -d"=" -f"3")"
	if [ "$ROLLBACK_VERSION" ]
	then echo "sudo pip install \"$1==$ROLLBACK_VERSION\""
	else echo "sudo uninstall \"$1\""
	fi >&3
	if [ "$3" ]
	then fpf_if_deps sudo pip install "$1==$2"
	else fpf_if_deps sudo pip install "$1>=$2"
	fi
}

# `fpf_deps_fpr_install "$NAME" "$VERSION" "$PINNED"`
#
# Install a dependency with FPR.
fpf_deps_fpr_install() {
	echo "fpr-remove \"$1\"" >&3
	ROLLBACK_VERSION="$(git config "fpf.version")"
	if [ "$ROLLBACK_VERSION" ]
	then echo "fpr-install -v\"$ROLLBACK_VERSION\" \"$1\""
	fi >&3
	if [ "$3" ]
	then fpf_if_deps fpr-install --prefix="$PREFIX" -p -v"$2" "$1"
	else fpf_if_deps fpr-install --prefix="$PREFIX" -v"$2" "$1"
	fi
}

# `fpf_dpkg_version "$NAME"`
#
# Write the version of `$NAME` installed to standard output.
fpf_dpkg_version() {
	dpkg-query -W -f'${Version}' "$1" 2>"/dev/null" || true
}

# `fpf_git_commit_tree "$TREE"`
#
# Record a new commit referencing `$TREE` using the currently configured
# Git author (use `git-config`(1) to get/set `user.name` and `user.email`).
# No commit message is recorded.
#
# This function requires `GIT_DIR` and `GIT_WORK_TREE` to be exported.
fpf_git_commit_tree() {
	TS="$(date -u +%s)"
	git hash-object --no-filters --stdin -t"commit" -w <<EOF
tree $1
author $(git config "user.name") <$(git config "user.email")> $TS +0000
committer $(git config "user.name") <$(git config "user.email")> $TS +0000

EOF
}

# `fpf_git_ls "$TREE"`
#
# Print the mode, type, sha, and pathname of each entry in a `$TREE`,
# recursively.  The only difference between this and `git-ls-tree`(1) is the
# fact that this takes care of recursion on nested tree objects automatically.
#
# This function requires `GIT_DIR` to be exported.
fpf_git_ls() {
	git ls-tree "$1" | while read MODE TYPE SHA FILENAME
	do
		[ -z "$2" ] && PATHNAME="$FILENAME" || PATHNAME="$2/$FILENAME"
		echo "$MODE" "$TYPE" "$SHA" "$PATHNAME"
		case "$TYPE" in
			"blob") ;;
			"tree") fpf_git_ls "$SHA" "$PATHNAME";;
			*) echo "fpf: unknown object type $TYPE" >&2 && exit 1;;
		esac
	done
}

# `fpf_git_write_tree "$DIRNAME"`
#
# Write tree objects to Git's object store recursively, starting with
# `$DIRNAME`.  Each file and directory's full access mode is stored in the
# tree, including the `setuid`, `setgid`, and `sticky` bits.
#
# This function requires `GIT_DIR` and `GIT_WORK_TREE` to be exported.
fpf_git_write_tree() {
	{
		find "$1" -maxdepth 1 -mindepth 1 -type d -printf '%P\n' |
		while read D
		do
			/bin/echo -en "04$(fpf_mode "$1/$D") $D\\0$(
				fpf_git_write_tree "$1/$D" | sed -r 's/../\\x&/g'
			)"
		done
		find "$1" -maxdepth 1 -mindepth 1 -type f -printf '%P\n' |
		while read F
		do
			/bin/echo -en "10$(fpf_mode "$1/$F") $F\\0$(
				git hash-object --no-filters -t"blob" -w "$1/$F" |
				sed -r 's/../\\x&/g'
			)"
		done
	} | git hash-object --no-filters --stdin -t"tree" -w
}

# `fpf_if_deps [-q] ...`
#
# Execute the arguments as a command if the global `$DEPS` = 1.  If `-q`
# is given and `$DEPS` is 0, don't write the command that would have been
# executed to standard output.
fpf_if_deps() {
	if [ "$1" = "-q" ]
	then QUIET=1 shift
	else QUIET=0
	fi
	if [ "$DEPS" = 1 ]
	then "$@"
	elif [ "$QUIET" = 0 ]
	then echo "$@"
	fi
}

# `fpf_mode "$PATHNAME"`
#
# Write `$PATHNAME`'s 4-digit octal mode to standard output.
fpf_mode() {
	MODE="$(stat -c"%a" "$1")"
	[ "${#MODE}" = 3 ] && echo "0$MODE" || echo "$MODE"
}

# `fpf_rpm_version "$NAME"`
#
# Write the version of `$NAME` installed to standard output.
fpf_rpm_version() {
	rpm --qf="%{VERSION}-%{RELEASE}" -q "$1" 2>"/dev/null" || true
}

# `fpf_rpmvercmp "$VERSION1" "$OPERATOR" "$VERSION2"`
#
# Test the expression given in the arguments according to the RPM version
# comparison algorithm.  The only operators supported are ">=" and "==".
#
# See also: <http://fedoraproject.org/wiki/Tools/RPM/VersionComparison>
fpf_rpmvercmp() {
	case "$2" in
		">=") test "$(echo "$1\n$3" | fpf_rpmvercmp_sort | head -n1)" = "$1";;
		"==")
			test "$(
				echo "$1" | _fpf_rpmvercmp_sed
			)" = "$(
				echo "$3" | _fpf_rpmvercmp_sed
			)";;
	esac
}

# `fpf_rpmvercmp_sed`
#
# Transform an RPM-style version number into a lexically-comparable,
# space-delimited tuple.
fpf_rpmvercmp_sed() {
	sed -r '
		s/([0-9])([a-z])/\1 \2/gi
		s/([a-z])([0-9])/\1 \2/gi
		s/[^0-9a-z]+/ /gi
		s/(^| )([a-z]+)/\1b\2/g
		s/(^| )([A-Z]+)/\1a\2/g
		s/(^| )([0-9]{5})/\1N\2/g
		s/(^| )([0-9]{4})/\1N0\2/g
		s/(^| )([0-9]{3})/\1N00\2/g
		s/(^| )([0-9]{2})/\1N000\2/g
		s/(^| )([0-9]{1})/\1N0000\2/g
	'
}

# `fpf_rpmvercmp_sort`
#
# Sort the stream of RPM-style version numbers on standard input, writing
# the results to standard output.
fpf_rpmvercmp_sort() {
	while read LINE
	do
		echo -n "$LINE "
		echo "$LINE" | fpf_rpmvercmp_sed
	done |
	sort -r -k"2" |
	cut -d" " -f"1"
}

# `fpf_txn_begin`
#
# Initialize a new transaction rollback log, the name of which is stored in
# `ROLLBACK`, and a trap that executes the rollback log in reverse order when
# the process exits.
fpf_txn_begin() {
	TXN_LOG="$(mktemp)"
	trap "tac \"$TXN_LOG\" | sh; rm -f \"$TXN_LOG\"" EXIT INT TERM
}

# `fpf_txn_commit`
#
# Commit the transaction by truncating the rollback log so that nothing is
# rolled back when the process exits.
fpf_txn_commit() {
	cat "$TXN_LOG"
	truncate -s"0" "$TXN_LOG"
}
