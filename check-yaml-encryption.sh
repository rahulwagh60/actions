#!/bin/bash

# Debug script to test encryption detection on a specific file
# Usage: ./debug-encryption.sh path/to/file.yaml

if [ $# -eq 0 ]; then
    echo "Usage: $0 <file_path>"
    echo "Example: $0 secret/secret2.yaml"
    exit 1
fi

FILE="$1"

if [ ! -f "$FILE" ]; then
    echo "❌ File not found: $FILE"
    exit 1
fi

echo "🔍 Debugging encryption detection for: $FILE"
echo "================================================"

# Check file size
FILE_SIZE=$(wc -c < "$FILE")
echo "📊 File size: $FILE_SIZE bytes"

# Check file type
FILE_TYPE=$(file -b "$FILE" 2>/dev/null || echo "unknown")
echo "📄 File type: $FILE_TYPE"

# Check if file type indicates encryption
echo ""
echo "🔍 File Type Analysis:"
if echo "$FILE_TYPE" | grep -qi "data"; then
    echo "   ✅ Contains 'data' - likely encrypted"
elif echo "$FILE_TYPE" | grep -qi "encrypted"; then
    echo "   ✅ Contains 'encrypted' - definitely encrypted"
elif echo "$FILE_TYPE" | grep -qi "binary"; then
    echo "   ✅ Contains 'binary' - likely encrypted"
elif echo "$FILE_TYPE" | grep -qi "gzip\|compressed"; then
    echo "   ✅ Contains compression indicators - likely encrypted"
else
    echo "   ⚠️  File type doesn't indicate encryption"
fi

echo ""
echo "🔍 Encryption Marker Analysis:"

# Check for Ansible Vault
if grep -q "^\$ANSIBLE_VAULT" "$FILE" 2>/dev/null; then
    echo "   ✅ Ansible Vault marker found (\$ANSIBLE_VAULT)"
elif grep -q "ansible-vault" "$FILE" 2>/dev/null; then
    echo "   ✅ Ansible Vault reference found (ansible-vault)"
else
    echo "   ❌ No Ansible Vault markers"
fi

# Check for SOPS
if grep -q "sops:" "$FILE" 2>/dev/null; then
    echo "   ✅ SOPS marker found (sops:)"
else
    echo "   ❌ No SOPS markers"
fi

# Check for AGE
if grep -q "age:" "$FILE" 2>/dev/null; then
    echo "   ✅ AGE marker found (age:)"
else
    echo "   ❌ No AGE markers"
fi

# Check for PGP
if grep -q "pgp:" "$FILE" 2>/dev/null; then
    echo "   ✅ PGP marker found (pgp:)"
elif grep -q "BEGIN PGP MESSAGE" "$FILE" 2>/dev/null; then
    echo "   ✅ PGP message block found (BEGIN PGP MESSAGE)"
elif grep -q "-----BEGIN PGP MESSAGE-----" "$FILE" 2>/dev/null; then
    echo "   ✅ PGP message block found (-----BEGIN PGP MESSAGE-----)"
else
    echo "   ❌ No PGP markers"
fi

# Check for ENC markers
if grep -q "ENC\[" "$FILE" 2>/dev/null; then
    echo "   ✅ ENC[] marker found"
else
    echo "   ❌ No ENC[] markers"
fi

echo ""
echo "🔍 Content Analysis:"

# Sample first 200 characters safely
echo "   First 200 characters (safe preview):"
SAMPLE=$(head -c 200 "$FILE" 2>/dev/null | cat -v)
echo "   '$SAMPLE'"

# Check printable character ratio
FULL_SAMPLE=$(head -c 1000 "$FILE" 2>/dev/null || true)
if [ -n "$FULL_SAMPLE" ]; then
    PRINTABLE_COUNT=$(echo -n "$FULL_SAMPLE" | tr -cd '[:print:][:space:]' | wc -c)
    TOTAL_COUNT=$(echo -n "$FULL_SAMPLE" | wc -c)
    
    if [ "$TOTAL_COUNT" -gt 0 ]; then
        PRINTABLE_RATIO=$((PRINTABLE_COUNT * 100 / TOTAL_COUNT))
        echo "   📊 Printable character ratio: ${PRINTABLE_RATIO}% (${PRINTABLE_COUNT}/${TOTAL_COUNT})"
        
        if [ "$PRINTABLE_RATIO" -lt 80 ]; then
            echo "   ✅ Low printable ratio suggests encryption"
        else
            echo "   ⚠️  High printable ratio suggests plain text"
        fi
    fi
fi

echo ""
echo "🏁 Final Assessment:"

# Apply the same logic as the GitHub Action
IS_ENCRYPTED=false

# File type check
if echo "$FILE_TYPE" | grep -qi "data\|encrypted\|binary\|gzip\|compressed"; then
    echo "   ✅ ENCRYPTED by file type"
    IS_ENCRYPTED=true
fi

# Marker checks
if grep -q "^\$ANSIBLE_VAULT\|^ansible-vault\|sops:\|age:\|pgp:\|BEGIN.*MESSAGE\|ENC\[" "$FILE" 2>/dev/null; then
    echo "   ✅ ENCRYPTED by content markers"
    IS_ENCRYPTED=true
fi

# Printable ratio check
if [ -n "$FULL_SAMPLE" ] && [ "$TOTAL_COUNT" -gt 0 ]; then
    if [ "$PRINTABLE_RATIO" -lt 80 ]; then
        echo "   ✅ ENCRYPTED by character analysis"
        IS_ENCRYPTED=true
    fi
fi

echo ""
if [ "$IS_ENCRYPTED" = true ]; then
    echo "🎉 RESULT: File appears to be ENCRYPTED ✅"
    exit 0
else
    echo "⚠️  RESULT: File appears to be UNENCRYPTED ❌"
    echo ""
    echo "💡 Suggestions:"
    echo "   1. If this file IS encrypted, it might be using a format not recognized by this script"
    echo "   2. Check if your encryption tool has specific format requirements"
    echo "   3. Verify the encryption was applied correctly"
    echo "   4. Consider adding custom detection patterns to the GitHub Action"
    exit 1
fi