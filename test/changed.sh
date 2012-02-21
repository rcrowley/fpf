cd "$(mktemp -d)"
trap "cd && rm -rf \"$PWD\"" EXIT INT TERM

touch "changed"
fpf-build -A -d"." -n"changed" -v"0.0.0-0" "changed.fpf"
rm -f "changed"
fpf-install-package --prefix="." "changed.fpf"
chmod +t "changed"
fpf-check --prefix="." "changed" && exit 1
exit 0
