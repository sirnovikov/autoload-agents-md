#!/usr/bin/env bash
# Parses name and description from a SKILL.md YAML frontmatter block.
# Usage: source this file, then call parse_frontmatter <path/to/SKILL.md>
# Sets globals: SKILL_NAME, SKILL_DESCRIPTION
# Returns 1 if either field is missing or parsing fails.

parse_frontmatter() {
    local file="$1"
    SKILL_NAME=""
    SKILL_DESCRIPTION=""

    local in_frontmatter=0
    local found_open=0

    while IFS= read -r line; do
        if [[ $found_open -eq 0 ]]; then
            if [[ "$line" == "---" ]]; then
                found_open=1
                in_frontmatter=1
            else
                # First non-empty line is not ---: no frontmatter
                [[ -z "$line" ]] && continue
                return 1
            fi
            continue
        fi

        if [[ $in_frontmatter -eq 1 ]]; then
            if [[ "$line" == "---" ]]; then
                in_frontmatter=0
                break
            fi

            if [[ "$line" =~ ^name:[[:space:]]*(.+)$ ]]; then
                local raw="${BASH_REMATCH[1]}"
                # Strip surrounding quotes if present
                raw="${raw#\"}"
                raw="${raw%\"}"
                raw="${raw#\'}"
                raw="${raw%\'}"
                SKILL_NAME="$raw"
            fi

            if [[ "$line" =~ ^description:[[:space:]]*(.+)$ ]]; then
                local raw="${BASH_REMATCH[1]}"
                raw="${raw#\"}"
                raw="${raw%\"}"
                raw="${raw#\'}"
                raw="${raw%\'}"
                SKILL_DESCRIPTION="$raw"
            fi
        fi
    done < "$file"

    [[ -n "$SKILL_NAME" && -n "$SKILL_DESCRIPTION" ]]
}
