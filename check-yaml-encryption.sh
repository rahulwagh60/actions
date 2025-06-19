#!/bin/bash

# Script to check if YAML files in secret folder are encrypted
# Exit codes: 0 = all encrypted, 1 = some unencrypted files found

set -e

FOLDER_PATH="secret"
UNENCRYPTED_FILES=()
ENCRYPTED_FILES=()
EXIT_CODE=0

echo "🔍 Checking YAML files in '$FOLDER_PATH' folder for encryption..."

# Check if secret folder exists
if [ ! -d "$FOLDER_PATH" ]; then
    echo "❌ Error: '$FOLDER_PATH' folder not found!"
    exit 1
fi

# Find all YAML files in the secret folder
YAML_FILES=$(find "$FOLDER_PATH" -name "*.yaml" -o -name "*.yml" 2>/dev/null || true)

if [ -z "$YAML_FILES" ]; then
    echo "ℹ️  No YAML files found in '$FOLDER_PATH' folder"
    exit 0
fi

echo "📁 Found YAML files:"
echo "$YAML_FILES" | while read -r file; do echo "  - $file"; done
echo ""

# Check each YAML file
while IFS= read -r file; do
    if [ -f "$file" ]; then
        echo "🔍 Checking: $file"
        
        # Use file command to detect file type
        FILE_TYPE=$(file -b "$file")
        
        # Check various indicators of encryption
        if echo "$FILE_TYPE" | grep -qi "data\|encrypted\|binary\|gzip\|compressed"; then
            echo "✅ ENCRYPTED: $file ($FILE_TYPE)"
            ENCRYPTED_FILES+=("$file")
        elif head -c 100 "$file" 2>/dev/null | grep -q "^[[:print:]]*$" && \
             ! grep -q "BEGIN PGP MESSAGE\|BEGIN ENCRYPTED MESSAGE\|ansible-vault\|ENC\[" "$file" 2>/dev/null; then
            # File contains readable text and doesn't have encryption markers
            echo "❌ NOT ENCRYPTED: $file ($FILE_TYPE)"
            UNENCRYPTED_FILES+=("$file")
            EXIT_CODE=1
        else
            # File might be encrypted (contains encryption markers or non-printable chars)
            echo "✅ LIKELY ENCRYPTED: $file ($FILE_TYPE)"
            ENCRYPTED_FILES+=("$file")
        fi
        echo ""
    fi
done <<< "$YAML_FILES"

# Summary
echo "📊 SUMMARY:"
echo "============"
echo "Total YAML files checked: $((${#ENCRYPTED_FILES[@]} + ${#UNENCRYPTED_FILES[@]}))"
echo "Encrypted files: ${#ENCRYPTED_FILES[@]}"
echo "Unencrypted files: ${#UNENCRYPTED_FILES[@]}"
echo ""

if [ ${#ENCRYPTED_FILES[@]} -gt 0 ]; then
    echo "✅ Encrypted files:"
    for file in "${ENCRYPTED_FILES[@]}"; do
        echo "  - $file"
    done
    echo ""
fi

if [ ${#UNENCRYPTED_FILES[@]} -gt 0 ]; then
    echo "❌ Unencrypted files found:"
    for file in "${UNENCRYPTED_FILES[@]}"; do
        echo "  - $file"
    done
    echo ""
    echo "⚠️  Security Warning: Unencrypted files detected in secret folder!"
fi

# Export results for GitHub Actions
if [ -n "$GITHUB_ENV" ]; then
    echo "ENCRYPTED_COUNT=${#ENCRYPTED_FILES[@]}" >> "$GITHUB_ENV"
    echo "UNENCRYPTED_COUNT=${#UNENCRYPTED_FILES[@]}" >> "$GITHUB_ENV"
    
    # Create multiline environment variable for unencrypted files
    if [ ${#UNENCRYPTED_FILES[@]} -gt 0 ]; then
        echo "UNENCRYPTED_FILES<<EOF" >> "$GITHUB_ENV"
        printf '%s\n' "${UNENCRYPTED_FILES[@]}" >> "$GITHUB_ENV"
        echo "EOF" >> "$GITHUB_ENV"
    fi
fi

exit $EXIT_CODE