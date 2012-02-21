cd "$(mktemp -d)"
trap "cd && rm -rf \"$PWD\"" EXIT INT TERM

fpf-build -A --apt="build-essential" --gem="json" --npm="underscore" --pear="Http_OAuth" --pecl="memcached" --pip="Django" -d"." -n"deps" -v"0.0.0-0" "deps.fpf"
fpf-install-package --no-deps --prefix="." "deps.fpf"
cat >"control" <<EOF
apt build-essential 0
gem json 0
npm underscore 0
pear Http_OAuth 0
pecl memcached 0
pip Django 0
EOF
fpf-ls-deps --prefix="." "deps" >"test"
diff "control" "test"
