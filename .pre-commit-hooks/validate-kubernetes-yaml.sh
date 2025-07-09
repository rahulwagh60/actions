#!/bin/bash
# .pre-commit-hooks/validate-kubernetes-yaml.sh
# Pre-commit hook to validate Kubernetes YAML files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if kubeval is installed
if ! command -v kubeval &> /dev/null; then
    echo -e "${RED}❌ kubeval is not installed${NC}"
    echo "Please install kubeval:"
    echo "  macOS: brew install kubeval"
    echo "  Linux: wget https://github.com/instrumenta/kubeval/releases/latest/download/kubeval-linux-amd64.tar.gz"
    echo "         tar xf kubeval-linux-amd64.tar.gz && sudo mv kubeval /usr/local/bin/"
    exit 1
fi

# Initialize counters
TOTAL_FILES=0
VALID_FILES=0
INVALID_FILES=0
INVALID_FILE_LIST=()
VALID_FILE_LIST=()
K8S_FILES=()

echo -e "${BLUE}⚓ Validating Kubernetes YAML files...${NC}"

# Check each file to see if it's a Kubernetes resource
for file in "$@"; do
    # Skip non-YAML files
    if [[ ! "$file" =~ \.(yaml|yml)$ ]]; then
        continue
    fi

    if [ ! -f "$file" ] || [ ! -r "$file" ]; then
        echo -e "${YELLOW}⚠️  Skipping unreadable file: $file${NC}"
        continue
    fi

    # Check if file contains Kubernetes resource indicators
    is_k8s_file=false

    # Check path patterns
    if echo "$file" | grep -qE "(k8s|kubernetes|manifests|deployment|service|ingress|configmap|secret)"; then
        is_k8s_file=true
    fi

    # Check content for Kubernetes fields
    if [ "$is_k8s_file" = false ] && [ -r "$file" ]; then
        if grep -l "apiVersion:\|kind:" "$file" >/dev/null 2>&1; then
            is_k8s_file=true
        fi
    fi

    if [ "$is_k8s_file" = true ]; then
        K8S_FILES+=("$file")
    fi
done

# If no Kubernetes files found, exit successfully
if [ ${#K8S_FILES[@]} -eq 0 ]; then
    echo -e "${YELLOW}ℹ️  No Kubernetes YAML files to validate${NC}"
    exit 0
fi

echo -e "${BLUE}Found ${#K8S_FILES[@]} Kubernetes YAML file(s) to validate${NC}"

# Validate each Kubernetes file
for file in "${K8S_FILES[@]}"; do
    TOTAL_FILES=$((TOTAL_FILES + 1))
    echo -e "\n${BLUE}📄 Validating: $file${NC}"
    echo "----------------------------------------"

    # Run kubeval on the file and capture output
    if kubeval_output=$(kubeval "$file" 2>&1); then
        echo -e "${GREEN}✅ VALID: $file${NC}"
        VALID_FILES=$((VALID_FILES + 1))
        VALID_FILE_LIST+=("$file")

        # Show kubeval output for valid files (usually just confirmation)
        if [ -n "$kubeval_output" ]; then
            echo "$kubeval_output" | sed 's/^/   /'
        fi
    else
        echo -e "${RED}❌ INVALID: $file${NC}"
        INVALID_FILES=$((INVALID_FILES + 1))
        INVALID_FILE_LIST+=("$file")

        # Show kubeval error output
        echo "$kubeval_output" | sed 's/^/   /' | while IFS= read -r line; do
            echo -e "${RED}   $line${NC}"
        done
    fi
done

# Print summary
echo -e "\n${BLUE}=== Kubernetes YAML Validation Results ===${NC}"
echo "Total Kubernetes files: $TOTAL_FILES"
echo -e "Valid files: ${GREEN}$VALID_FILES${NC}"
echo -e "Invalid files: ${RED}$INVALID_FILES${NC}"

# Show file lists
if [ ${#VALID_FILE_LIST[@]} -gt 0 ]; then
    echo -e "\n${GREEN}✅ Valid files:${NC}"
    for file in "${VALID_FILE_LIST[@]}"; do
        echo -e "  - ${GREEN}$file${NC}"
    done
fi

if [ ${#INVALID_FILE_LIST[@]} -gt 0 ]; then
    echo -e "\n${RED}❌ Invalid files:${NC}"
    for file in "${INVALID_FILE_LIST[@]}"; do
        echo -e "  - ${RED}$file${NC}"
    done
fi

# Decide whether to block commit or just warn
# Set BLOCK_ON_K8S_VALIDATION=true to block commits on validation failures
BLOCK_ON_K8S_VALIDATION=${BLOCK_ON_K8S_VALIDATION:-false}

if [ $INVALID_FILES -gt 0 ]; then
    if [ "$BLOCK_ON_K8S_VALIDATION" = "true" ]; then
        echo -e "\n${RED}❌ COMMIT BLOCKED: Kubernetes YAML validation failed${NC}"
        echo -e "${YELLOW}How to fix:${NC}"
        echo "1. Review the kubeval output above for specific errors"
        echo "2. Common issues:"
        echo "   - Incorrect apiVersion for your cluster"
        echo "   - Missing required fields"
        echo "   - Invalid resource specifications"
        echo "   - YAML syntax errors"
        echo "3. Fix the issues and try committing again"
        echo "4. Or use --no-verify to skip validation (NOT RECOMMENDED)"
        echo -e "\n${BLUE}Resources:${NC}"
        echo "- Kubernetes API Reference: https://kubernetes.io/docs/reference/"
        echo "- Kubeval Documentation: https://github.com/instrumenta/kubeval"
        exit 1
    else
        echo -e "\n${YELLOW}⚠️  WARNING: Some Kubernetes YAML files failed validation${NC}"
        echo -e "${YELLOW}Consider fixing these issues before deploying to prevent runtime errors${NC}"
        echo -e "${YELLOW}To make this check blocking, set: export BLOCK_ON_K8S_VALIDATION=true${NC}"
        exit 0
    fi
else
    echo -e "\n${GREEN}✅ All Kubernetes YAML files are valid!${NC}"
    exit 0
fi
