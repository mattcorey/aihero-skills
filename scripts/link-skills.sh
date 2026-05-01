#!/usr/bin/env bash
set -euo pipefail

# Links all skills in the repository to local agent skill directories, so that
# they can be used by Claude Code and Codex.

REPO="$(cd "$(dirname "$0")/.." && pwd)"
DESTS=(
  "$HOME/.claude/skills"
  "$HOME/.codex/skills"
)

link_skills_into() {
  local dest="$1"
  local backup=""

  # If the destination is a symlink that resolves into this repo, we'd end up
  # writing the per-skill symlinks back into the repo's own skills/ tree. Detect
  # and bail out instead of polluting the working copy.
  if [ -L "$dest" ]; then
    resolved="$(readlink -f "$dest")"
    case "$resolved" in
      "$REPO"|"$REPO"/*)
        echo "error: $dest is a symlink into this repo ($resolved)." >&2
        echo "Remove it (rm \"$dest\") and re-run; the script will recreate it as a real dir." >&2
        exit 1
        ;;
    esac
  fi

  mkdir -p "$dest"

  while IFS= read -r -d '' skill_md; do
    src="$(dirname "$skill_md")"
    name="$(basename "$src")"
    target="$dest/$name"

    if [ -e "$target" ] && [ ! -L "$target" ]; then
      if [ -z "$backup" ]; then
        backup="$dest/.backup-link-skills-$(date +%Y%m%d-%H%M%S)"
        mkdir -p "$backup"
      fi
      mv "$target" "$backup/$name"
    fi

    ln -sfn "$src" "$target"
    echo "linked $name -> $src in $dest"
  done < <(find "$REPO/skills" -name SKILL.md -not -path '*/node_modules/*' -print0)

  if [ -n "$backup" ]; then
    echo "backed up replaced skills to $backup"
  fi
}

for dest in "${DESTS[@]}"; do
  link_skills_into "$dest"
done
