#!/usr/bin/env bash
# Pure-bash JSON manifest read/write for autoload-agents-skills.
# Manifest path: <project-root>/.claude/.agents-skills-managed.json
# Schema: { "version": 1, "managed": [ { "name": "...", "source": "...", "createdAt": "..." } ] }
#
# Usage: source this file, then use:
#   manifest_read  <manifest_path>  -> populates MANIFEST_NAMES[] and MANIFEST_SOURCES[]
#   manifest_write <manifest_path> <names[]> <sources[]>  -> writes updated manifest
#   manifest_has   <name>           -> returns 0 if name is in manifest

MANIFEST_NAMES=()
MANIFEST_SOURCES=()

manifest_read() {
    local path="$1"
    MANIFEST_NAMES=()
    MANIFEST_SOURCES=()
    [[ ! -f "$path" ]] && return 0

    local content
    content="$(cat "$path" 2>/dev/null)" || return 0

    local current_name=""
    while IFS= read -r line; do
        line="${line#"${line%%[![:space:]]*}"}"  # ltrim

        if [[ "$line" =~ \"name\":[[:space:]]*\"([^\"]+)\" ]]; then
            current_name="${BASH_REMATCH[1]}"
        fi
        if [[ "$line" =~ \"source\":[[:space:]]*\"([^\"]+)\" && -n "$current_name" ]]; then
            MANIFEST_NAMES+=("$current_name")
            MANIFEST_SOURCES+=("${BASH_REMATCH[1]}")
            current_name=""
        fi
    done <<< "$content"
}

manifest_has() {
    local name="$1"
    local n
    for n in "${MANIFEST_NAMES[@]+"${MANIFEST_NAMES[@]}"}"; do
        [[ "$n" == "$name" ]] && return 0
    done
    return 1
}

manifest_write() {
    local path="$1"
    shift
    local -a names=("$@")
    # names and sources are interleaved: name1 source1 name2 source2 ...
    # Actually caller passes parallel arrays; we receive them as flat interleaved pairs.
    # Caller format: manifest_write <path> <n1> <s1> <n2> <s2> ...

    local now
    now="$(date -u +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u +%Y-%m-%dT%H:%M:%SZ)"

    local entries=""
    local i=0
    while [[ $i -lt ${#names[@]} ]]; do
        local n="${names[$i]}"
        local s="${names[$((i+1))]}"
        [[ -n "$entries" ]] && entries="${entries},"$'\n'
        entries="${entries}    { \"name\": \"${n}\", \"source\": \"${s}\", \"createdAt\": \"${now}\" }"
        i=$((i+2))
    done

    local dir
    dir="$(dirname "$path")"
    mkdir -p "$dir"

    printf '{\n  "version": 1,\n  "managed": [\n%s\n  ]\n}\n' "$entries" > "$path"
}
