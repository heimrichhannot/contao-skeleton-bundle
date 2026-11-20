#!/usr/bin/env bash
# Register every skill in this directory for the local agents by symlink.
# Idempotent: existing correct links are kept; foreign entries are reported, never replaced.
# Antigravity is intentionally not registered yet (skills path not confirmed).
set -euo pipefail

src_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
targets=("$HOME/.claude/skills" "$HOME/.codex/skills")

for target in "${targets[@]}"; do
  mkdir -p "$target"
  for skill in "$src_root"/*/; do
    [ -f "$skill/SKILL.md" ] || continue
    name="$(basename "$skill")"
    link="$target/$name"
    want="${skill%/}"
    if [ -L "$link" ] && [ "$(readlink -f "$link")" = "$(readlink -f "$want")" ]; then
      echo "ok       $link"
    elif [ -e "$link" ] || [ -L "$link" ]; then
      echo "SKIPPED  $link exists and points elsewhere ($(readlink -f "$link")); resolve manually" >&2
    else
      ln -s "$want" "$link"
      echo "linked   $link -> $want"
    fi
  done
done
