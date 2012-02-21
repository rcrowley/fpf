cd "$(mktemp -d)"
trap "cd && rm -rf \"$PWD\"" EXIT INT TERM

touch "remove"
fpf-build -A -d"." -n"remove" -v"0.0.0-0" "remove.fpf"
rm -f "remove"
fpf-install-package --prefix="." "remove.fpf"
fpf-remove --prefix="." "remove"
test ! -d "lib/fpf/remove.git" -a ! -f "remove"
