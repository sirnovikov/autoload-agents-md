#!/usr/bin/env bash
# enable.sh — opt-in: creates relative symlinks from <project>/.claude/skills/<name>
# to <project>/.agents/skills/<name> for each valid skill found, writes the
# per-project manifest, and updates .gitignore.
#
# Run from the project root (or any directory within it). Idempotent.

set -euo pipefail

# Dereference symlinks so this works when called via ~/.claude/bin/agents-skills-setup
_self="$0"
while [[ -L "$_self" ]]; do _self="$(readlink "$_self")"; done
SCRIPT_DIR="$(cd "$(dirname "$_self")" && pwd)"
unset _self
LIB_DIR="${SCRIPT_DIR}/lib"
source "${LIB_DIR}/parse-frontmatter.sh"
source "${LIB_DIR}/manifest.sh"
source "${LIB_DIR}/gitignore.sh"

# Walk up from $PWD to $HOME looking for .agents/skills/
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

PROJECT_ROOT=""
if ! PROJECT_ROOT="$(find_agents_skills_root)"; then
    printf 'No .agents/skills/ directory found in this project hierarchy.\n' >&2
    exit 1
fi

SKILLS_SRC="${PROJECT_ROOT}/.agents/skills"
CLAUDE_SKILLS="${PROJECT_ROOT}/.claude/skills"
MANIFEST="${PROJECT_ROOT}/.claude/.agents-skills-managed.json"

# Compute the relative path from CLAUDE_SKILLS to SKILLS_SRC.
# e.g. <project>/.claude/skills -> <project>/.agents/skills  =>  ../../.agents/skills
compute_relative_prefix() {
    # We need the path from the symlink's directory ($CLAUDE_SKILLS) to the
    # target base directory ($SKILLS_SRC).  Python's os.path.relpath is the
    # most portable, but we're staying pure-bash.  Since both paths share the
    # same project root, we can derive this structurally.
    local from_dir="$1"
    local to_dir="$2"
    # Strip common prefix
    local from="$from_dir"
    local to="$to_dir"
    local rel=""
    while [[ "$from" != "/" && "$to" != "$from"* ]]; do
        from="$(dirname "$from")"
        rel="../${rel}"
    done
    local suffix="${to_dir#$from/}"
    printf '%s%s' "$rel" "$suffix"
}

REL_PREFIX="$(compute_relative_prefix "$CLAUDE_SKILLS" "$SKILLS_SRC")"

mkdir -p "$CLAUDE_SKILLS"

# Read existing manifest
manifest_read "$MANIFEST"

# Track results
created=()
skipped=()
warnings=()

for skill_dir in "${SKILLS_SRC}"/*/; do
    [[ -d "$skill_dir" ]] || continue
    skill_name="$(basename "$skill_dir")"
    skill_md="${skill_dir}SKILL.md"

    if [[ ! -f "$skill_md" ]]; then
        warnings+=("  skip ${skill_name}: no SKILL.md found")
        continue
    fi

    if ! parse_frontmatter "$skill_md"; then
        warnings+=("  skip ${skill_name}: invalid/missing frontmatter name or description")
        continue
    fi

    if [[ "$SKILL_NAME" != "$skill_name" ]]; then
        warnings+=("  skip ${skill_name}: frontmatter name '${SKILL_NAME}' does not match directory name")
        continue
    fi

    link_path="${CLAUDE_SKILLS}/${skill_name}"
    rel_target="${REL_PREFIX}/${skill_name}"

    if [[ -e "$link_path" && ! -L "$link_path" ]]; then
        warnings+=("  skip ${skill_name}: ${link_path} exists as a real file/directory — not overwriting")
        continue
    fi

    if [[ -L "$link_path" ]] && ! manifest_has "$skill_name"; then
        warnings+=("  skip ${skill_name}: ${link_path} is a symlink not managed by this plugin — not overwriting")
        continue
    fi

    # Create or refresh symlink
    ln -sfn "$rel_target" "$link_path"
    created+=("$skill_name")
done

# Rebuild manifest from current state (all already-managed + newly created)
new_names=()
new_sources=()
# Keep previously managed entries that still exist (weren't processed above = already there)
for i in "${!MANIFEST_NAMES[@]}"; do
    n="${MANIFEST_NAMES[$i]}"
    s="${MANIFEST_SOURCES[$i]}"
    already_in_created=0
    for c in "${created[@]+"${created[@]}"}"; do
        [[ "$c" == "$n" ]] && already_in_created=1 && break
    done
    if [[ $already_in_created -eq 0 ]]; then
        new_names+=("$n")
        new_sources+=("$s")
    fi
done
# Add newly created entries
for c in "${created[@]+"${created[@]}"}"; do
    new_names+=("$c")
    new_sources+=(".agents/skills/${c}")
done

# Write manifest using interleaved pairs
interleaved=()
for i in "${!new_names[@]}"; do
    interleaved+=("${new_names[$i]}" "${new_sources[$i]}")
done
manifest_write "$MANIFEST" "${interleaved[@]+"${interleaved[@]}"}"

# Update .gitignore if git-adjacent
gitignore_path="${PROJECT_ROOT}/.gitignore"
if [[ -d "${PROJECT_ROOT}/.git" || -f "$gitignore_path" ]]; then
    gi_entries=()
    for n in "${new_names[@]+"${new_names[@]}"}"; do
        gi_entries+=("/.claude/skills/${n}")
    done
    gi_entries+=("/.claude/.agents-skills-managed.json")
    gitignore_update "$gitignore_path" "${gi_entries[@]+"${gi_entries[@]}"}"
fi

# Report
if [[ ${#created[@]} -gt 0 ]]; then
    printf 'Enabled %d skill(s):\n' "${#created[@]}"
    for c in "${created[@]}"; do
        printf '  + %s\n' "$c"
    done
else
    printf 'No new skills to enable (already up to date).\n'
fi

for w in "${warnings[@]+"${warnings[@]}"}"; do
    printf 'Warning: %s\n' "$w"
done

if [[ ${#created[@]} -gt 0 ]]; then
    printf '\nSkills are active in the next fresh Claude Code session.\n'
fi
