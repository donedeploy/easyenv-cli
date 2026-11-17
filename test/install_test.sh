#!/bin/sh
# Tests for install.sh. They install real releases from GitHub, so they need
# the network, and they write to /usr/local/bin: run them on a throwaway
# machine. CI runs them on Linux x64, Linux arm64, macOS arm64 and Alpine
# (busybox sh and wget). Locally, in a container:
#
#   docker run --rm -v "$PWD":/src:ro debian:12 sh -c \
#     'apt-get update -qq && apt-get install -qq -y curl >/dev/null && sh /src/test/install_test.sh'

set -eu

here=$(cd "$(dirname "$0")/.." && pwd)
installer=$here/install.sh
releases=https://github.com/donedeploy/easyenv-cli/releases
older=0.6.0 # any earlier release that has the raw binaries

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
failures=0

pass() { printf 'ok   %s\n' "$1"; }
fail() {
	printf 'FAIL %s\n' "$1"
	[ ! -s "$work/out" ] || sed 's/^/     | /' "$work/out"
	failures=$((failures + 1))
}
# run [VAR=value ...]: install.sh with those variables, output in $work/out.
run() { env "$@" sh "$installer" >"$work/out" 2>&1; }
version_of() { "$1" --version 2>/dev/null | awk '{ print $3 }'; }

fetch() {
	if command -v curl >/dev/null 2>&1; then curl -fsSL -o "$2" "$1"; else wget -q -O "$2" "$1"; fi
}
fetch "$releases/latest/download/checksums.txt" "$work/sums"
latest=$(awk 'NR == 1 { f = $2; sub(/^easyenv_/, "", f); sub(/_.*/, "", f); print f }' "$work/sums")
case $(uname -s) in Darwin) os=darwin ;; *) os=linux ;; esac
case $(uname -m) in x86_64 | amd64) arch=amd64 ;; *) arch=arm64 ;; esac
echo "latest release: $latest, this machine: $os/$arch, sh: $(readlink -f /bin/sh 2>/dev/null || echo /bin/sh)"

# 1. Into a chosen folder, latest release.
if run EASYENV_INSTALL_DIR="$work/a" && [ "$(version_of "$work/a/easyenv")" = "$latest" ]; then
	pass "installs the latest release ($latest) into EASYENV_INSTALL_DIR"
else
	fail "installs the latest release ($latest) into EASYENV_INSTALL_DIR"
fi

# 2. A pinned older release, then the latest over it: the upgrade path.
if run EASYENV_INSTALL_DIR="$work/b" EASYENV_VERSION="$older" && [ "$(version_of "$work/b/easyenv")" = "$older" ]; then
	pass "EASYENV_VERSION=$older installs that release"
else
	fail "EASYENV_VERSION=$older installs that release"
fi
if run PATH="$work/b:$PATH" && [ "$(version_of "$work/b/easyenv")" = "$latest" ]; then
	pass "running it again upgrades the easyenv already on PATH in place ($older -> $latest)"
else
	fail "running it again upgrades the easyenv already on PATH in place ($older -> $latest)"
fi

# 3. The default place, twice, and one copy only. Needs root, a writable
#    /usr/local/bin or sudo without a password (CI runners have that).
if [ "$(id -u)" -ne 0 ] && [ ! -w /usr/local/bin ] && ! sudo -n true 2>/dev/null; then
	echo "skip /usr/local/bin case: not root and no sudo without a password"
elif run && [ "$(version_of /usr/local/bin/easyenv)" = "$latest" ] \
	&& run && [ "$(version_of /usr/local/bin/easyenv)" = "$latest" ] && [ ! -e "$HOME/.local/bin/easyenv" ]; then
	pass "installs to /usr/local/bin, and a second run keeps the one copy"
else
	fail "installs to /usr/local/bin, and a second run keeps the one copy"
fi

# 4. A checksum that does not match stops the install. The fake release is a
#    folder read over file://, which only curl can do.
if command -v curl >/dev/null 2>&1; then
	fake=$work/fake
	mkdir -p "$fake/latest/download" "$fake/download/9.9.9"
	printf 'not the real binary\n' >"$fake/download/9.9.9/easyenv_9.9.9_${os}_${arch}"
	printf '%064d  easyenv_9.9.9_%s_%s\n' 0 "$os" "$arch" >"$fake/latest/download/checksums.txt"
	if ! run EASYENV_RELEASES_URL="file://$fake" EASYENV_INSTALL_DIR="$work/c" && grep -q 'checksum mismatch' "$work/out" && [ ! -e "$work/c/easyenv" ]; then
		pass "a wrong checksum stops the install, with a clear message, and installs nothing"
	else
		fail "a wrong checksum stops the install, with a clear message, and installs nothing"
	fi
	if ! run EASYENV_RELEASES_URL="file://$fake" EASYENV_VERSION=1.2.3 EASYENV_INSTALL_DIR="$work/c" && grep -q 'could not download' "$work/out"; then
		pass "a release that does not exist fails with a clear message"
	else
		fail "a release that does not exist fails with a clear message"
	fi
else
	echo "skip wrong-checksum case: needs curl for file:// URLs"
fi

# 5. A CPU there is no build for fails clearly instead of installing the wrong one.
mkdir -p "$work/fakebin"
real_uname=$(command -v uname)
cat >"$work/fakebin/uname" <<EOF
#!/bin/sh
if [ "\$1" = -m ]; then echo armv7l; else exec $real_uname "\$@"; fi
EOF
chmod +x "$work/fakebin/uname"
if ! run PATH="$work/fakebin:$PATH" EASYENV_INSTALL_DIR="$work/d" && grep -q 'no easyenv build for armv7l' "$work/out" && [ ! -e "$work/d/easyenv" ]; then
	pass "an unsupported CPU (armv7l) fails with a clear message"
else
	fail "an unsupported CPU (armv7l) fails with a clear message"
fi

# 6. No sudo and /usr/local/bin not writable: ~/.local/bin. Only meaningful
#    when not root; the fake sudo refuses, and there is no terminal here.
if [ "$(id -u)" -ne 0 ]; then
	printf '#!/bin/sh\nexit 1\n' >"$work/fakebin/sudo"
	chmod +x "$work/fakebin/sudo"
	rm -f "$work/fakebin/uname"
	mkdir -p "$work/home"
	if [ -w /usr/local/bin ]; then
		echo "skip no-sudo case: /usr/local/bin is writable here"
	elif run HOME="$work/home" PATH="$work/fakebin:/usr/bin:/bin" </dev/null && [ "$(version_of "$work/home/.local/bin/easyenv")" = "$latest" ] \
		&& grep -q 'not on your PATH' "$work/out"; then
		pass "without sudo it installs to ~/.local/bin and says how to put it on PATH"
	else
		fail "without sudo it installs to ~/.local/bin and says how to put it on PATH"
	fi
else
	echo "skip no-sudo case: running as root"
fi

if [ "$failures" -ne 0 ]; then
	echo "$failures failed"
	exit 1
fi
echo "all passed"
