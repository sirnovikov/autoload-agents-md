#!/usr/bin/env bash
# disable.sh — removes all managed symlinks, the gitignore block, and the
# manifest for this project.  Run from anywhere within the project.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/lib"
source "${LIB_DIR}/manifest.sh"
source "${LIB_DIR}/gitignore.sh"

find_agents_skills_root() {
    local dir="$PWD"
    local home="${HOME:-/}"
    while true; do
        if [[ -d "${dir}/.agents/skills" ]]; then
            printf '%s' "$dir"
            return 0
        fi
        if [[ "$dir" == "$home" || "$dir" == "/" ]]; then
            break
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

# Also accept a project with a manifest but no .agents/skills (e.g. post-migration)
find_project_with_manifest() {
    local dir="$PWD"
    local home="${HOME:-/}"
    while true; do
        if [[ -f "${dir}/.claude/.agents-skills-managed.json" ]]; then
            printf '%s' "$dir"
            return 0
        fi
        if [[ "$dir" == "$home" || "$dir" == "/" ]]; then
            break
        fi
        dir="$(dirname "$dir")"
    done
    return 1
}

PROJECT_ROOT=""
if ! PROJECT_ROOT="$(find_agents_skills_root 2>/dev/null)" && \
   ! PROJECT_ROOT="$(find_project_with_manifest 2>/dev/null)"; then
    printf 'No managed project found (no .agents/skills/ or manifest in hierarchy).\n' >&2
    exit 1
fi

MANIFEST="${PROJECT_ROOT}/.claude/.agents-skills-managed.json"
CLAUDE_SKILLS="${PROJECT_ROOT}/.claude/skills"

manifest_read "$MANIFEST"

removed=()
for i in "${!MANIFEST_NAMES[@]}"; do
    n="${MANIFEST_NAMES[$i]}"
    link="${CLAUDE_SKILLS}/${n}"
    if [[ -L "$link" ]]; then
        rm "$link"
        removed+=("$n")
    fi
done

# Remove gitignore block
gitignore_path="${PROJECT_ROOT}/.gitignore"
if [[ -f "$gitignore_path" ]]; then
    gitignore_remove "$gitignore_path"
fi

# Remove manifest
[[ -f "$MANIFEST" ]] && rm "$MANIFEST"

if [[ ${#removed[@]} -gt 0 ]]; then
    printf 'Removed %d skill symlink(s):\n' "${#removed[@]}"
    for r in "${removed[@]}"; do
        printf '  - %s\n' "$r"
    done
else
    printf 'Nothing to remove.\n'
fi
printf 'autoload-agents-skills disabled for this project.\n'
