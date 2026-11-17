#!/bin/sh
# Install the easyenv CLI on macOS or Linux:
#
#   curl -fsSL https://get.easyenv.io/cli | sh
#
# It picks the build for this machine, takes the latest release, checks the
# download against that release's checksums.txt, and puts `easyenv` in
# /usr/local/bin (with sudo only when that folder is not writable), or in
# ~/.local/bin when there is no sudo. Run it again to upgrade: an easyenv that
# is already on your PATH is replaced where it is.
#
# Optional settings:
#   EASYENV_VERSION=0.6.1      install that release instead of the latest
#   EASYENV_INSTALL_DIR=DIR    install into DIR (no sudo is tried)
#   EASYENV_RELEASES_URL=URL   a mirror laid out like the GitHub releases
#
# Everything happens in main(), which is called on the last line, so a
# download that is cut off halfway runs nothing.

set -eu

say() { printf '%s\n' "$*"; }
err() {
	printf 'easyenv install: %s\n' "$*" >&2
	exit 1
}
has() { command -v "$1" >/dev/null 2>&1; }

# fetch URL FILE
fetch() {
	if has curl; then
		case $1 in
		# --proto keeps every hop, redirects included, on https.
		https://*) curl -fsSL --retry 3 --proto =https -o "$2" "$1" ;;
		*) curl -fsSL --retry 3 -o "$2" "$1" ;;
		esac
	else
		wget -q -O "$2" "$1"
	fi
}

# sha256 FILE: prints the lowercase hex digest.
sha256() {
	if has sha256sum; then
		sha256sum "$1" | awk '{ print $1 }'
	elif has shasum; then
		shasum -a 256 "$1" | awk '{ print $1 }'
	elif has openssl; then
		openssl dgst -sha256 "$1" | awk '{ print $NF }'
	fi
}

# Whether sudo can run here: without a password, or with a terminal to ask it
# on. With `curl | sh` stdin is the script, but sudo asks on /dev/tty.
can_sudo() {
	[ "$(id -u)" -ne 0 ] || return 1
	has sudo || return 1
	sudo -n true 2>/dev/null && return 0
	(: </dev/tty) 2>/dev/null
}

main() {
	releases=${EASYENV_RELEASES_URL:-https://github.com/donedeploy/easyenv-cli/releases}
	releases=${releases%/}

	case $(uname -s) in
	Linux) os=linux ;;
	Darwin) os=darwin ;;
	MINGW* | MSYS* | CYGWIN*) err "this is Windows. In PowerShell, run: irm https://get.easyenv.io/cli.ps1 | iex" ;;
	*) err "there is no easyenv build for $(uname -s). Builds exist for macOS, Linux and Windows." ;;
	esac

	cpu=$(uname -m)
	case $cpu in
	x86_64 | amd64) arch=amd64 ;;
	aarch64 | arm64) arch=arm64 ;;
	*) err "there is no easyenv build for $cpu CPUs. Builds exist for x86_64 (amd64) and arm64 (aarch64)." ;;
	esac
	# A shell running under Rosetta on Apple silicon reports x86_64; the arm64
	# build is the native one there.
	if [ "$os" = darwin ] && [ "$arch" = amd64 ] && [ "$(sysctl -n sysctl.proc_translated 2>/dev/null || true)" = 1 ]; then
		arch=arm64
	fi

	has curl || has wget || err "needs curl or wget to download the CLI"

	# Where it goes, settled before anything is downloaded: EASYENV_INSTALL_DIR,
	# else wherever easyenv already is (an upgrade must replace that copy, not
	# leave a second one earlier or later on PATH), else /usr/local/bin.
	sudo=
	current=$(command -v easyenv 2>/dev/null || true)
	if [ -n "${EASYENV_INSTALL_DIR:-}" ]; then
		dir=${EASYENV_INSTALL_DIR%/}
		mkdir -p "$dir" || err "cannot create $dir"
		[ -w "$dir" ] || err "cannot write to $dir"
	elif [ -n "$current" ] && [ -f "$current" ]; then
		dir=$(dirname "$current")
		if [ ! -w "$dir" ]; then
			can_sudo || err "easyenv is installed in $dir, which needs sudo to change, and sudo is not available. Set EASYENV_INSTALL_DIR to a folder you own, or remove $current first."
			sudo=sudo
		fi
	else
		dir=/usr/local/bin
		mkdir -p "$dir" 2>/dev/null || true
		if [ -d "$dir" ] && [ -w "$dir" ]; then
			:
		elif can_sudo; then
			sudo=sudo
		else
			dir=$HOME/.local/bin
			mkdir -p "$dir" || err "cannot create $dir"
		fi
	fi
	target=$dir/easyenv

	tmp=$(mktemp -d 2>/dev/null || mktemp -d -t easyenv)
	trap 'rm -rf "$tmp"' EXIT
	trap 'rm -rf "$tmp"; exit 1' HUP INT TERM

	# The checksums name every build, version included, so they answer which
	# release is the latest without the GitHub API and its rate limit. The
	# binary is then fetched from that exact release, so a release published
	# in between cannot pair one version's binary with another's checksum.
	version=${EASYENV_VERSION:-latest}
	version=${version#v}
	if [ "$version" = latest ]; then
		sums_url=$releases/latest/download/checksums.txt
	else
		sums_url=$releases/download/$version/checksums.txt
	fi
	fetch "$sums_url" "$tmp/checksums.txt" || err "could not download $sums_url"

	line=$(awk -v suffix="_${os}_${arch}" '{
		f = $2; sub(/^\*/, "", f)
		if (f ~ /^easyenv_/ && length(f) > length(suffix) && substr(f, length(f) - length(suffix) + 1) == suffix) {
			print $1, f; exit
		}
	}' "$tmp/checksums.txt")
	[ -n "$line" ] || err "release $version has no build for $os/$arch"
	want=$(printf '%s' "${line%% *}" | tr 'A-F' 'a-f')
	name=${line#* }
	ver=${name#easyenv_}
	ver=${ver%"_${os}_${arch}"}

	url=$releases/download/$ver/$name
	say "Downloading easyenv $ver for $os/$arch"
	fetch "$url" "$tmp/easyenv" || err "could not download $url"

	got=$(sha256 "$tmp/easyenv" || true)
	[ -n "$got" ] || err "found no sha256sum, shasum or openssl to check the download with, so nothing was installed"
	if [ "$got" != "$want" ]; then
		err "checksum mismatch for $name: checksums.txt says $want, the download is $got. The file is damaged or is not the one that was released, so nothing was installed. Try again; if it happens again, report it at https://github.com/donedeploy/easyenv-cli/issues"
	fi


	[ -z "$sudo" ] || say "Installing to $dir needs sudo; it may ask for your password."
	$sudo mkdir -p "$dir"
	# Copy next to the target, then rename over it: a rename is atomic, and it
	# works while the old binary is running.
	$sudo cp "$tmp/easyenv" "$dir/.easyenv.new.$$"
	$sudo chmod 755 "$dir/.easyenv.new.$$"
	$sudo mv -f "$dir/.easyenv.new.$$" "$target"

	say "Installed $target"
	"$target" --version || err "$target was installed but does not run on this machine"

	case ":$PATH:" in
	*":$dir:"*)
		found=$(command -v easyenv 2>/dev/null || true)
		if [ -n "$found" ] && [ "$found" != "$target" ]; then
			say ""
			say "Note: 'easyenv' on your PATH is $found, which comes before $target. Remove it, or run $target directly."
		fi
		;;
	*)
		case ${SHELL:-} in
		*/zsh) rc=$HOME/.zshrc ;;
		*/bash) rc=$HOME/.bashrc ;;
		*) rc=$HOME/.profile ;;
		esac
		say ""
		say "$dir is not on your PATH yet. Add it, then open a new terminal:"
		case ${SHELL:-} in
		*/fish) say "  fish_add_path $dir" ;;
		*) say "  echo 'export PATH=\"$dir:\$PATH\"' >> $rc" ;;
		esac
		;;
	esac
}

main "$@"
