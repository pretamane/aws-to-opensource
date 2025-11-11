#!/bin/bash
# Emoji Detection Script
# Prevents emojis from being committed to the repository

echo "Checking for emojis in staged files..."

# Find all staged files
STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACM)

if [ -z "$STAGED_FILES" ]; then
    echo "No files to check"
    exit 0
fi

# Emoji regex pattern
EMOJI_PATTERN='[-🿿🀀-🿽]|||️||||||️||||||️||||||🆘||||⏰||⏳|'

# Check each staged file for emojis
EMOJI_FOUND=0
for FILE in $STAGED_FILES; do
    if [ -f "$FILE" ]; then
        if grep -qP "$EMOJI_PATTERN" "$FILE" 2>/dev/null; then
            echo "ERROR: Emoji found in: $FILE"
            grep -nP "$EMOJI_PATTERN" "$FILE" 2>/dev/null | head -5
            EMOJI_FOUND=1
        fi
    fi
done

if [ $EMOJI_FOUND -eq 1 ]; then
    echo ""
    echo "COMMIT BLOCKED: Emojis detected in files"
    echo "Please remove all emojis before committing"
    echo ""
    echo "To remove emojis automatically, run:"
    echo "  ./scripts/remove-emojis.sh"
    exit 1
fi

echo "No emojis detected - OK to commit"
exit 0


