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
	git ls-tree "$1" | while read MODE TYPE SHA FILENAME
	do
		MODE="$(echo -n "$MODE" | tail -c4)"
		case "$TYPE" in
			"blob")
				git cat-file "blob" "$SHA" >"$2/$FILENAME"
				chmod "$MODE" "$2/$FILENAME";;
			"tree")
				mkdir -m"$MODE" "$2/$FILENAME"
				_git_checkout_tree "$SHA" "$2/$FILENAME";;
			*) echo "fpf: unknown object type $TYPE" >&2 && exit 1;;
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

# `_verify_mode "$TREE"`
#
# Verify the access mode of objects in the working copy match those in
# `$TREE`, recursively.  A character is printed to standard output and a
# message is printed to standard error for each missing file or mismatched
# mode.  Verification fails if any characters are printed to standard output.
#
# This function requires `GIT_DIR` and `GIT_WORK_TREE` to be exported.
_verify_mode() {
	git ls-tree "$1" | while read MODE TYPE SHA FILENAME
	do
		PATHNAME="$2/$FILENAME"
		L_MODE="$(echo -n "$MODE" | tail -c4)"
		P_MODE="$(_mode "$PREFIX/$PATHNAME" 2>"/dev/null" || true)"
		if [ -z "$P_MODE" ]
		then
			echo "fpf: $PREFIX/$PATHNAME is missing" >&2
			echo 1
		elif [ -n "$L_MODE" -a "$L_MODE" != "$P_MODE" ]
		then
			echo "fpf: $PREFIX/$PATHNAME mode is $P_MODE, should be $L_MODE" >&2
			echo 1
		fi
		case "$TYPE" in
			"blob") ;;
			"tree") _verify_mode "$SHA" "$PATHNAME";;
			*) echo "fpf: unknown object type $TYPE" >&2 && exit 1;;
		esac
	done
}
