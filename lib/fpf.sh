# `fpf_arch`
#
# Write the architecture of this system to standard output.
fpf_arch() {
	dpkg --print-architecture 2>"/dev/null" ||
	rpm --eval "%_arch" 2>"/dev/null"
}

# `fpf_dpkg_version "$NAME"`
#
# Write the version of `$NAME` installed to standard output.
fpf_dpkg_version() {
	dpkg-query -W -f'${Version}' "$1" 2>"/dev/null" || echo "0"
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

# `fpf_git_config_prefix "$PREFIX"`
#
# Write all `git-config`(1) names and values to standard output with names
# that begin with `$PREFIX`.  The prefix is stripped from the name before it
# is written; for example, `foo.bar = baz` is written as `bar = baz` when
# the prefix `foo.` is given.
fpf_git_config_prefix() {
	git config --get-regexp "^$(echo "$1" | sed "s/\\./\\./")" |
	cut -c"$((${#1} + 1))-" ||
	true
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

# `fpf_if_deps ...`
#
# Execute the arguments as a command if the global $DEPS = 1.
fpf_if_deps() {
	[ "$DEPS" = 1 ] && eval "$@" || echo "$@"
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
	rpm --qf="%{VERSION}-%{RELEASE}" -q "$1" 2>"/dev/null" || echo "0"
}

# `fpf_rpmvercmp "$VERSION1" "$OPERATOR" "$VERSION2"`
#
# Test the expression given in the arguments according to the RPM version
# comparison algorithm.  The only operators supported are ">=" and "==".
#
# See also: <http://fedoraproject.org/wiki/Tools/RPM/VersionComparison>
fpf_rpmvercmp() {
	case "$2" in
		">=")
			test "$(
				echo -e "$1\n$3" | fpf_rpmvercmp_sort | head -n1
			)" = "$1";;
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
	sort -r -k2 |
	cut -d" " -f1
}
