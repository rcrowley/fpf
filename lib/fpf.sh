# `_arch`
#
# Write the architecture of this system to standard output.
_arch() {
	dpkg --print-architecture 2>"/dev/null" ||
	rpm --eval "%_arch" 2>"/dev/null"
}

# `_git_checkout "$TREE" "$DIRNAME"`
#
# Checkout `$TREE` in `$DIRNAME`, recursively.  This works about like
# `git-checkout`(1) with two exceptions: it begins with a tree object, not a
# commit object, and it respects the full possibilities expressed by the
# access mode stored with each blob or tree object in the tree.
#
# This function requires `GIT_DIR` and `GIT_WORK_TREE` to be exported.
_git_checkout_tree() {
	_git_ls_tree "$1" | while read MODE TYPE SHA PATHNAME
	do
		MODE="$(echo -n "$MODE" | tail -c4)"
		case "$TYPE" in
			"blob")
				git cat-file "blob" "$SHA" >"$2/$PATHNAME"
				chmod "$MODE" "$2/$PATHNAME";;
			"tree")
				mkdir -m"$MODE" -p "$2/$PATHNAME";;
		esac
	done
}

# `_git_commit "$TREE"`
#
# Record a new commit referencing `$TREE` using the currently configured
# Git author (use `git-config`(1) to get/set `user.name` and `user.email`).
# No commit message is recorded.
#
# This function requires `GIT_DIR` and `GIT_WORK_TREE` to be exported.
_git_commit() {
	TS="$(date -u +%s)"
	git hash-object --no-filters --stdin -t"commit" -w <<EOF
tree $1
author $(git config "user.name") <$(git config "user.email")> $TS +0000
committer $(git config "user.name") <$(git config "user.email")> $TS +0000

EOF
}

# `_git_ls_tree "$TREE"`
#
# Print the mode, type, sha, and pathname of each entry in a `$TREE`,
# recursively.  The only difference between this and `git-ls-tree`(1) is the
# fact that this takes care of recursion on nested tree objects automatically.
#
# This function requires `GIT_DIR` to be exported.
_git_ls_tree() {
	git ls-tree "$1" | while read MODE TYPE SHA FILENAME
	do
		[ -z "$2" ] && PATHNAME="$FILENAME" || PATHNAME="$2/$FILENAME"
		echo "$MODE" "$TYPE" "$SHA" "$PATHNAME"
		case "$TYPE" in
			"blob") ;;
			"tree") _git_ls_tree "$SHA" "$PATHNAME";;
			*) echo "fpf: unknown object type $TYPE" >&2 && exit 1;;
		esac
	done
}

# `_git_write_tree "$DIRNAME"`
#
# Write tree objects to Git's object store recursively, starting with
# `$DIRNAME`.  Each file and directory's full access mode is stored in the
# tree, including the `setuid`, `setgid`, and `sticky` bits.
#
# This function requires `GIT_DIR` and `GIT_WORK_TREE` to be exported.
_git_write_tree() {
	{
		find "$1" -maxdepth 1 -mindepth 1 -type d -printf '%P\n' |
		while read D
		do
			/bin/echo -en "04$(_mode "$1/$D") $D\\0$(
				_git_write_tree "$1/$D" | sed -r 's/../\\x&/g'
			)"
		done
		find "$1" -maxdepth 1 -mindepth 1 -type f -printf '%P\n' |
		while read F
		do
			/bin/echo -en "10$(_mode "$1/$F") $F\\0$(
				git hash-object --no-filters -t"blob" -w "$1/$F" |
				sed -r 's/../\\x&/g'
			)"
		done
	} | git hash-object --no-filters --stdin -t"tree" -w
}

# `_mode "$PATHNAME"`
#
# Write `$PATHNAME`'s 4-digit octal mode to standard output.
_mode() {
	MODE="$(stat -c"%a" "$1")"
	if [ "${#MODE}" = 3 ]
	then echo "0$MODE"
	else echo "$MODE"
	fi
}
