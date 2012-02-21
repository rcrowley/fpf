cd "$(mktemp -d)"
trap "cd && rm -rf \"$PWD\"" EXIT INT TERM

touch "modified"
fpf-build -A -d"." -n"modified" -v"0.0.0-0" "modified.fpf"
rm -f "modified"
fpf-install-package --prefix="." "modified.fpf"
echo "modified" >"modified"
fpf-check --prefix="." "modified" && exit 1
exit 0
