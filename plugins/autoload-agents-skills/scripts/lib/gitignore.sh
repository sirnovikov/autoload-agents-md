#!/usr/bin/env bash
# Manages an autoload-agents-skills marker block in a .gitignore file.
# Usage: source this file, then call:
#   gitignore_update <gitignore_path> <entry1> <entry2> ...
#   gitignore_remove <gitignore_path>

MARKER_START="# === autoload-agents-skills (managed) ==="
MARKER_END="# === end autoload-agents-skills ==="

# Replace or append our managed block with the given entries.
# If entries list is empty, removes the block entirely.
gitignore_update() {
    local gi_path="$1"
    shift
    local -a entries=("$@")

    if [[ ${#entries[@]} -eq 0 ]]; then
        gitignore_remove "$gi_path"
        return
    fi

    local block="$MARKER_START"$'\n'
    local e
    for e in "${entries[@]}"; do
        block="${block}${e}"$'\n'
    done
    block="${block}${MARKER_END}"

    if [[ ! -f "$gi_path" ]]; then
        printf '%s\n' "$block" > "$gi_path"
        return
    fi

    local content
    content="$(cat "$gi_path")"

    if grep -qF "$MARKER_START" "$gi_path" 2>/dev/null; then
        # Replace existing block
        local before after in_block=0 new_content=""
        while IFS= read -r line; do
            if [[ "$line" == "$MARKER_START" ]]; then
                in_block=1
                continue
            fi
            if [[ $in_block -eq 1 ]]; then
                if [[ "$line" == "$MARKER_END" ]]; then
                    in_block=0
                fi
                continue
            fi
            new_content="${new_content}${line}"$'\n'
        done <<< "$content"
        # Remove trailing newline, then append block
        new_content="${new_content%$'\n'}"
        printf '%s\n%s\n' "$new_content" "$block" > "$gi_path"
    else
        # Append block
        printf '\n%s\n' "$block" >> "$gi_path"
    fi
}

# Remove our managed block from the gitignore entirely.
gitignore_remove() {
    local gi_path="$1"
    [[ ! -f "$gi_path" ]] && return 0
    grep -qF "$MARKER_START" "$gi_path" 2>/dev/null || return 0

    local content in_block=0 new_content=""
    content="$(cat "$gi_path")"
    while IFS= read -r line; do
        if [[ "$line" == "$MARKER_START" ]]; then
            in_block=1
            continue
        fi
        if [[ $in_block -eq 1 ]]; then
            if [[ "$line" == "$MARKER_END" ]]; then
                in_block=0
            fi
            continue
        fi
        new_content="${new_content}${line}"$'\n'
    done <<< "$content"
    # Strip leading/trailing blank lines introduced by removal
    new_content="${new_content%$'\n'}"
    printf '%s\n' "$new_content" > "$gi_path"
}
