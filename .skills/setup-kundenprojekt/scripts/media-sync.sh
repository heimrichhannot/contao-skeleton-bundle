#!/usr/bin/env bash
# Sync one Nextcloud folder into ~/ownCloud using nextcloudcmd, without touching the desktop client.
# Usage: media-sync.sh <remote-path> [--exclude <rel/path/>]... [--dry-run]
#   remote-path   e.g. /Kunden/mwike/innovationspreis-nrw/produkte/contao/files/media/mwike
#   --exclude     subfolder relative to remote-path, no leading slash, trailing slash (e.g. preistraeger/)
# The app password is read from the desktop client's keyring entry and only passed via environment.
set -euo pipefail

remote="${1:?usage: media-sync.sh <remote-path> [--exclude rel/] [--dry-run]}"; shift
excludes=(); dry=0
while [ $# -gt 0 ]; do
  case "$1" in
    --exclude) excludes+=("${2:?}"); shift 2;;
    --dry-run) dry=1; shift;;
    *) echo "unknown option $1" >&2; exit 2;;
  esac
done
remote="/${remote#/}"; remote="${remote%/}"

cfg="$HOME/.config/Nextcloud/nextcloud.cfg"
url="$(grep -m1 -E '^0\\url=' "$cfg" | cut -d= -f2-)"
user="$(grep -m1 -E '^0\\dav_user=' "$cfg" | cut -d= -f2-)"
[ -n "$url" ] && [ -n "$user" ] || { echo "cannot read server/user from $cfg" >&2; exit 1; }
local_dir="$HOME/ownCloud$remote"

work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT
args=(--non-interactive --silent --confdir "$work/conf")
if [ ${#excludes[@]} -gt 0 ]; then
  printf '%s\n' "${excludes[@]}" > "$work/unsynced.txt"
  args+=(--unsyncedfolders "$work/unsynced.txt")
fi
args+=(--path "$remote" "$local_dir" "${url%/}")

echo "server:  ${url%/}"; echo "user:    $user"; echo "remote:  $remote"; echo "local:   $local_dir"
[ ${#excludes[@]} -gt 0 ] && printf 'exclude: %s\n' "${excludes[@]}"
if [ "$dry" = 1 ]; then echo "dry-run: would run nextcloudcmd ${args[*]}"; exit 0; fi

pw="$(secret-tool lookup user "$user:${url%/}/:0" server Nextcloud type plaintext || true)"
[ -n "$pw" ] || { echo "no app password in keyring for $user" >&2; exit 1; }
mkdir -p "$local_dir"
NC_USER="$user" NC_PASSWORD="$pw" nextcloudcmd "${args[@]}"
echo "done: $(du -sh "$local_dir" | cut -f1) in $local_dir"
