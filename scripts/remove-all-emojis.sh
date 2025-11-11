#!/bin/bash
# Comprehensive Emoji Removal Script
# Removes ALL emojis from the entire codebase

set -e

echo "=== COMPREHENSIVE EMOJI REMOVAL TOOL ==="
echo ""
echo "This script will remove ALL emojis from the entire repository"
echo ""

# Comprehensive emoji pattern - covers all common emojis
EMOJI_PATTERNS=(
    # Common emojis in documentation
    's/ //g' 's/ //g' 's/ //g' 's/ //g' 's/ //g' 's/ //g'
    's/ //g' 's/ //g' 's/ //g' 's/ //g' 's/ //g' 's/ //g'
    's/ //g' 's/ //g' 's/️ //g' 's/ //g' 's/ //g' 's/️ //g'
    's/ //g' 's/ //g' 's/️ //g' 's/ //g' 's/️ //g' 's/ //g'
    's/ //g' 's/🆘 //g' 's/ //g' 's/ //g' 's/ //g' 's/⏰ //g'
    's/ //g' 's/⏳ //g' 's/ //g' 's/ //g' 's/ //g' 's/ //g'
    
    # Remove emojis without spaces
    's///g' 's///g' 's///g' 's///g' 's///g' 's///g'
    's///g' 's///g' 's///g' 's///g' 's///g' 's///g'
    's///g' 's///g' 's/️//g' 's///g' 's///g' 's/️//g'
    's///g' 's///g' 's/️//g' 's///g' 's/️//g' 's///g'
    's///g' 's/🆘//g' 's///g' 's///g' 's///g' 's/⏰//g'
    's///g' 's/⏳//g' 's///g' 's///g' 's///g' 's///g'
)

# Find all text files (excluding binary files and git)
find . -type f \
    ! -path './.git/*' \
    ! -path './node_modules/*' \
    ! -path './.venv/*' \
    ! -path './venv/*' \
    ! -path './__pycache__/*' \
    ! -path './*.pyc' \
    ! -path './*.pyo' \
    ! -name '*.png' \
    ! -name '*.jpg' \
    ! -name '*.jpeg' \
    ! -name '*.gif' \
    ! -name '*.ico' \
    ! -name '*.svg' \
    ! -name '*.woff' \
    ! -name '*.woff2' \
    ! -name '*.ttf' \
    ! -name '*.eot' \
    ! -name '*.pdf' \
    ! -name '*.zip' \
    ! -name '*.tar' \
    ! -name '*.gz' \
    | while read -r file; do
    # Check if file is text and contains emojis
    if file "$file" | grep -q "text"; then
        # Build sed command with all patterns
        SED_CMD=""
        for pattern in "${EMOJI_PATTERNS[@]}"; do
            SED_CMD="$SED_CMD -e '$pattern'"
        done
        
        # Apply sed command
        if eval "sed -i $SED_CMD \"$file\"" 2>/dev/null; then
            echo "Processed: $file"
        fi
    fi
done

echo ""
echo "=== EMOJI REMOVAL COMPLETE ==="
echo ""
echo "Run 'git diff' to see what changed"
echo "Run 'git status' to see modified files"
echo ""

