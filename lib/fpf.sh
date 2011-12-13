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

_git_commit() {
	TS="$(date -u +%s)"
	git hash-object --no-filters --stdin -t"commit" -w <<EOF
tree $1
author $(git config "user.name") <$(git config "user.email")> $TS +0000
committer $(git config "user.name") <$(git config "user.email")> $TS +0000

EOF
}

_git_ls_tree() {
	git ls-tree "$1" | while read MODE TYPE SHA FILENAME
	do
		PATHNAME="$2/$FILENAME"
		L_MODE="$(echo -n "$MODE" | tail -c4)"
		P_MODE="$(_stat "$PREFIX/$PATHNAME" 2>"/dev/null" || true)"
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
			"tree") _git_ls_tree "$SHA" "$PATHNAME";;
			*) echo "fpf: unknown object type $TYPE" >&2 && exit 1;;
		esac
	done
}

_git_write_tree() {
	{
		find "$1" -maxdepth 1 -mindepth 1 -type d -printf '%P\n' |
		while read D
		do
			/bin/echo -en "04$(_stat "$1/$D") $D\\0$(
				_git_write_tree "$1/$D" | sed -r 's/../\\x&/g'
			)"
		done
		find "$1" -maxdepth 1 -mindepth 1 -type f -printf '%P\n' |
		while read F
		do
			/bin/echo -en "10$(_stat "$1/$F") $F\\0$(
				git hash-object --no-filters -t"blob" -w "$1/$F" |
				sed -r 's/../\\x&/g'
			)"
		done
	} | git hash-object --no-filters --stdin -t"tree" -w
}

_stat() {
	MODE="$(stat -c"%a" "$1")"
	if [ "${#MODE}" = 3 ]
	then echo "0$MODE"
	else echo "$MODE"
	fi
}
