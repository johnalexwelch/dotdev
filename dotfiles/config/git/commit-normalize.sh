#!/bin/bash
# commit-normalize.sh — Normalize commit messages to Conventional Commits format
# Usage: commit-normalize.sh <commit-msg-file>
#
# Handles:
#   - Emoji-prefixed messages -> maps to conventional type
#   - Hybrid emoji+conventional -> strips emoji, keeps type
#   - Already-valid conventional commits -> pass-through
#   - Bare verb messages -> infers type from verb
#   - Merge/fixup/amend commits -> pass-through
#   - Validates subject line <= 72 chars
#
# Install as a commit-msg hook or invoke directly.

set -euo pipefail

COMMIT_MSG_FILE="${1:?Usage: commit-normalize.sh <commit-msg-file>}"

if [ ! -f "$COMMIT_MSG_FILE" ]; then
    echo "Error: commit message file not found: $COMMIT_MSG_FILE" >&2
    exit 1
fi

# Read first non-comment, non-empty line as the subject
subject=""
while IFS= read -r line; do
    [[ "$line" =~ ^# ]] && continue
    [[ -z "${line// /}" ]] && continue
    subject="$line"
    break
done <"$COMMIT_MSG_FILE"

# Empty message — let git handle it
if [ -z "$subject" ]; then
    exit 0
fi

# Pass-through: merge commits, fixup, squash, amend, revert
if [[ "$subject" =~ ^(Merge\ |fixup!\ |squash!\ |amend!\ |Revert\ ) ]]; then
    exit 0
fi

# Check if subject is already a valid conventional commit
is_conventional() {
    [[ "$1" =~ ^[a-z]+(\([a-zA-Z0-9_/-]+\))?!?:\ .+ ]]
}

# Map verb to conventional type
verb_to_type() {
    case "$(echo "$1" | tr '[:upper:]' '[:lower:]')" in
        add | create | implement | introduce) echo "feat" ;;
        fix | repair | patch | resolve | correct) echo "fix" ;;
        update | change | modify | adjust | tweak | improve | enhance) echo "feat" ;;
        remove | delete | drop | clean | cleanup) echo "chore" ;;
        refactor | reorganize | restructure | simplify | extract | move | rename) echo "refactor" ;;
        document | docs) echo "docs" ;;
        test | spec) echo "test" ;;
        configure | config | setup | install | bump | upgrade) echo "chore" ;;
        optimize | speed | perf) echo "perf" ;;
        deploy | release | publish) echo "chore" ;;
        *) echo "" ;;
    esac
}

# Replace subject line in commit message file
replace_subject() {
    local new_subject="$1"
    local tmpfile
    tmpfile=$(mktemp)
    local replaced=0
    while IFS= read -r line; do
        if [ $replaced -eq 0 ] && [[ ! "$line" =~ ^# ]] && [ -n "${line// /}" ]; then
            echo "$new_subject" >>"$tmpfile"
            replaced=1
        else
            echo "$line" >>"$tmpfile"
        fi
    done <"$COMMIT_MSG_FILE"
    mv "$tmpfile" "$COMMIT_MSG_FILE"
}

# Warn if subject exceeds max length
warn_length() {
    local msg="$1"
    if [ ${#msg} -gt 72 ]; then
        echo "Warning: subject line is ${#msg} chars (max 72): $msg" >&2
    fi
}

# --- Emoji detection via hex encoding ---
# Convert subject to hex, check for known emoji byte sequences,
# and extract the text after the emoji.

detect_emoji_type() {
    local text="$1"
    local hex
    hex=$(printf '%s' "$text" | LC_ALL=C od -An -tx1 | tr -d ' \n')

    local emoji_type=""
    local skip_bytes=0

    # 4-byte emoji patterns (f0 9f xx xx)
    case "${hex:0:8}" in
        f09f8c9f)
            emoji_type="feat"
            skip_bytes=4
            ;; # star2
        f09f8e89)
            emoji_type="feat"
            skip_bytes=4
            ;; # tada
        f09f909b)
            emoji_type="fix"
            skip_bytes=4
            ;; # bug
        f09f9a91)
            emoji_type="fix"
            skip_bytes=4
            ;; # ambulance
        f09f939d)
            emoji_type="docs"
            skip_bytes=4
            ;; # memo
        f09f9396)
            emoji_type="docs"
            skip_bytes=4
            ;; # book
        f09f8ea8)
            emoji_type="refactor"
            skip_bytes=4
            ;; # art
        f09f94a8)
            emoji_type="refactor"
            skip_bytes=4
            ;; # hammer
        f09f94a7)
            emoji_type="chore"
            skip_bytes=4
            ;; # wrench
        f09f93a6)
            emoji_type="chore"
            skip_bytes=4
            ;; # package
        f09f91b7)
            emoji_type="ci"
            skip_bytes=4
            ;; # construction_worker
        f09f929a)
            emoji_type="ci"
            skip_bytes=4
            ;; # green_heart
        f09fa7aa)
            emoji_type="test"
            skip_bytes=4
            ;; # test_tube
        f09f9a80)
            emoji_type="perf"
            skip_bytes=4
            ;; # rocket
        f09f94a5)
            emoji_type="chore"
            skip_bytes=4
            ;; # fire
        f09fa496)
            emoji_type="feat"
            skip_bytes=4
            ;; # robot
        f09f9492)
            emoji_type="fix"
            skip_bytes=4
            ;; # lock
        f09f9aa7)
            emoji_type="wip"
            skip_bytes=4
            ;; # construction
        f09f9284)
            emoji_type="refactor"
            skip_bytes=4
            ;; # lipstick
        f09f8f97)
            emoji_type="chore"
            skip_bytes=4
            ;; # building_construction
    esac

    # 3-byte emoji patterns (e2 xx xx / ef xx xx)
    if [ -z "$emoji_type" ]; then
        case "${hex:0:6}" in
            e29ca8)
                emoji_type="feat"
                skip_bytes=3
                ;; # sparkles
            e29c8f)
                emoji_type="docs"
                skip_bytes=3
                ;; # pencil
            e299bb)
                emoji_type="refactor"
                skip_bytes=3
                ;; # recycle
            e29a99)
                emoji_type="chore"
                skip_bytes=3
                ;; # gear
            e29c85)
                emoji_type="test"
                skip_bytes=3
                ;; # white_check_mark
            e29aa1)
                emoji_type="perf"
                skip_bytes=3
                ;; # zap
            e2ac86)
                emoji_type="chore"
                skip_bytes=3
                ;; # arrow_up
        esac
    fi

    if [ -z "$emoji_type" ]; then
        echo ""
        return
    fi

    # Skip emoji bytes + optional fe0f variation selector (ef b8 8f = 3 bytes)
    local rest_hex="${hex:$((skip_bytes * 2))}"
    if [[ "$rest_hex" == efb88f* ]]; then
        rest_hex="${rest_hex:6}"
    fi
    # Strip leading spaces (20 = space)
    while [[ "$rest_hex" == 20* ]]; do
        rest_hex="${rest_hex:2}"
    done

    # Convert remaining hex back to text
    local rest_text=""
    if [ -n "$rest_hex" ]; then
        rest_text=$(printf "$(echo "$rest_hex" | sed 's/\(..\)/\\x\1/g')")
    fi

    echo "${emoji_type}|${rest_text}"
}

# --- Main normalization logic ---

# 1. Already valid conventional commit — pass through
if is_conventional "$subject"; then
    warn_length "$subject"
    exit 0
fi

# 2. Try emoji detection
emoji_result=$(detect_emoji_type "$subject")

if [ -n "$emoji_result" ]; then
    detected_type="${emoji_result%%|*}"
    rest="${emoji_result#*|}"

    # 3. Hybrid: emoji + already-conventional text
    if [ -n "$rest" ] && is_conventional "$rest"; then
        replace_subject "$rest"
        warn_length "$rest"
        exit 0
    fi

    # Build conventional format from emoji type + remaining text
    if [ -n "$rest" ]; then
        new_subject="${detected_type}: ${rest}"
        replace_subject "$new_subject"
        warn_length "$new_subject"
        exit 0
    fi
fi

# 4. No emoji — try verb inference
first_word=$(echo "$subject" | awk '{print $1}')
detected_type=$(verb_to_type "$first_word")

if [ -n "$detected_type" ]; then
    new_subject="${detected_type}: ${subject}"
    replace_subject "$new_subject"
    warn_length "$new_subject"
    exit 0
fi

# 5. No mapping found — leave as-is, just validate length
warn_length "$subject"
exit 0
