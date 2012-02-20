# `fpf_arch`
#
# Write the architecture of this system to standard output.
fpf_arch() {
	dpkg --print-architecture 2>"/dev/null" ||
	rpm --eval "%_arch" 2>"/dev/null"
}

# `fpf_dep "$MANAGER" "$ARG"`
#
# Parse a command-line dependency declaration and write a `git-config`(1)
# command to add it to the package to standard output.
#
# The format expected for the argument is `"$PACKAGE>=$VERSION",
# `"$PACKAGE==$VERSION"`, or `"$PACKAGE"`.
fpf_dep() {
	case "$2" in
		*">="*)
			P="$(echo "$2" | awk -F">=" '{print $1}')"
			V="$(echo "$2" | awk -F">=" '{print $2}')"
			echo "git config \"$1.$P.version\" \"$V\"";;
		*"=="*)
			P="$(echo "$2" | awk -F"==" '{print $1}')"
			V="$(echo "$2" | awk -F"==" '{print $2}')"
			echo "git config \"$1.$P.version\" \"$V\""
			echo "git config --bool \"$1.$P.pinned\" \"true\"";;
		*) echo "git config \"$1.$2.version\" \"0\"";;
	esac >>"$TMP/deps"
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
	TS="$(date -u +"%s")"
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
	git ls-tree "$1" | while read M T S F
	do
		[ -z "$2" ] && P="$F" || P="$2/$F"
		echo "$M" "$T" "$S" "$P"
		case "$T" in
			"blob") ;;
			"tree") fpf_git_ls "$S" "$P";;
			*) echo "fpf: unknown object type $T" >&2 && exit 1;;
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

# `fpf_mode "$PATHNAME"`
#
# Write `$PATHNAME`'s 4-digit octal mode to standard output.
fpf_mode() {
	M="$(stat -c"%a" "$1")"
	[ "${#M}" = 3 ] && echo "0$M" || echo "$M"
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
		">=") [ "$(echo "$1\n$3" | fpf_rpmvercmp_sort | head -n"1")" = "$1" ];;
		"==") [ "$(
			echo "$1" | _fpf_rpmvercmp_sed
		)" = "$(
			echo "$3" | _fpf_rpmvercmp_sed
		)" ];;
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
		printf "$L "
		echo "$L" | fpf_rpmvercmp_sed
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
	truncate -s"0" "$TXN_LOG"
}
