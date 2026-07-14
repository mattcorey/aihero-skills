#!/usr/bin/env bash
set -euo pipefail

# NOTE: This is a dev-only script for this customized fork, not a supported
# installer for upstream mattpocock/skills.
#
# Link the published skills into the local directories used by Claude Code and
# Codex. Personal skills are retained for this fork; deprecated and in-progress
# skills are intentionally excluded.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTS=(
  "$HOME/.claude/skills"
  "$HOME/.agents/skills"
  "$HOME/.codex/skills"
)

names=()
srcs=()
while IFS= read -r -d '' skill_md; do
  src="$(dirname "$skill_md")"
  names+=("$(basename "$src")")
  srcs+=("$src")
done < <(
  find \
    "$REPO/skills/engineering" \
    "$REPO/skills/productivity" \
    "$REPO/skills/misc" \
    "$REPO/skills/personal" \
    -name SKILL.md -not -path '*/node_modules/*' -print0
)

is_active_skill() {
  local candidate="$1"
  local name

  for name in "${names[@]}"; do
    if [ "$name" = "$candidate" ]; then
      return 0
    fi
  done

  return 1
}

link_skills_into() {
  local dest="$1"
  local backup=""
  local resolved=""
  local target=""
  local link_target=""
  local name=""
  local src=""
  local i

  # Avoid writing per-skill links back into this repository if an entire skill
  # directory was previously linked to it.
  if [ -L "$dest" ]; then
    resolved="$(readlink -f "$dest")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $dest is a symlink into this repo ($resolved)." >&2
        echo "Replace it with a real directory and re-run this script." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$dest"

  # Remove only stale symlinks owned by this repository. Unrelated skills and
  # real directories are left untouched.
  while IFS= read -r -d '' target; do
    link_target="$(readlink "$target")"
    case "$link_target" in
      "$REPO"/skills/*)
        name="$(basename "$target")"
        if ! is_active_skill "$name"; then
          unlink "$target"
          echo "unlinked retired skill $name ($dest)"
        fi
        ;;
    esac
  done < <(find "$dest" -maxdepth 1 -type l -print0)

  for i in "${!names[@]}"; do
    name="${names[$i]}"
    src="${srcs[$i]}"
    target="$dest/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      if [ -z "$backup" ]; then
        backup="$dest/.backup-link-skills-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup"
      fi
      mv "$target" "$backup/$name"
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $src ($dest)"
  done

  if [ -n "$backup" ]; then
    echo "backed up replaced skills to $backup"
  fi
}

for dest in "${DESTS[@]}"; do
  link_skills_into "$dest"
done
