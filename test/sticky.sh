cd "$(mktemp -d)"
trap "cd && rm -rf \"$PWD\"" EXIT INT TERM

touch "sticky"
chmod +t "sticky"
fpf-build -A -d"." -n"sticky" -v"0.0.0-0" "sticky.fpf"
rm -f "sticky"
fpf-install-package --prefix="." "sticky.fpf"
test -k "sticky"
