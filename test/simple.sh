cd "$(mktemp -d)"
trap "cd && rm -rf \"$PWD\"" EXIT INT TERM

touch "simple"
fpf-build -A -d"." -n"simple" -v"0.0.0-0" "simple.fpf"
rm -f "simple"
fpf-install-package --prefix="." "simple.fpf"
test -f "simple"
