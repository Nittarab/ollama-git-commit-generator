#!/bin/bash

# Test runner for ollama-git-commit-generator unit tests
# This script sets up the environment and runs all bats tests

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo -e "${BLUE}🧪 Ollama Git Commit Generator - Unit Test Runner${NC}"
echo "=================================================="

# Check if bats is available
if ! command -v bats &> /dev/null; then
    echo -e "${YELLOW}⚠️  bats not found in PATH, using local installation...${NC}"
    
    # Check if we have bats-core in /tmp
    if [[ -d "/tmp/bats-core" ]]; then
        export PATH="/tmp/bats-core/bin:$PATH"
        echo -e "${GREEN}✅ Using bats from /tmp/bats-core${NC}"
    else
        echo -e "${RED}❌ bats testing framework not found${NC}"
        echo "Please install bats or run the setup in the parent directory"
        exit 1
    fi
fi

# Verify dependencies for tests
echo -e "${BLUE}🔍 Checking test dependencies...${NC}"

dependencies=("jq" "git")
missing_deps=()

for dep in "${dependencies[@]}"; do
    if command -v "$dep" &> /dev/null; then
        echo -e "${GREEN}✅ $dep found${NC}"
    else
        echo -e "${RED}❌ $dep not found${NC}"
        missing_deps+=("$dep")
    fi
done

if [[ ${#missing_deps[@]} -gt 0 ]]; then
    echo -e "${RED}❌ Missing dependencies: ${missing_deps[*]}${NC}"
    echo "Please install missing dependencies before running tests"
    exit 1
fi

# Set up test environment
export BATS_TEST_DIRNAME="$SCRIPT_DIR"
export PROJECT_ROOT="$PROJECT_ROOT"

# Find all test files
test_files=("$SCRIPT_DIR"/test_*.bats)

if [[ ${#test_files[@]} -eq 0 ]]; then
    echo -e "${RED}❌ No test files found in $SCRIPT_DIR${NC}"
    exit 1
fi

echo -e "${BLUE}📁 Found ${#test_files[@]} test files:${NC}"
for file in "${test_files[@]}"; do
    echo "  - $(basename "$file")"
done

echo ""

# Run tests
total_tests=0
passed_tests=0
failed_tests=0
test_results=()

for test_file in "${test_files[@]}"; do
    if [[ -f "$test_file" ]]; then
        echo -e "${BLUE}🧪 Running $(basename "$test_file")...${NC}"
        
        if bats "$test_file"; then
            # Count tests in this file
            test_count=$(grep -c "^@test" "$test_file" 2>/dev/null || echo "0")
            total_tests=$((total_tests + test_count))
            passed_tests=$((passed_tests + test_count))
            test_results+=("✅ $(basename "$test_file") - All tests passed")
            echo -e "${GREEN}✅ All tests in $(basename "$test_file") passed${NC}"
        else
            # Count tests in this file
            test_count=$(grep -c "^@test" "$test_file" 2>/dev/null || echo "0")
            total_tests=$((total_tests + test_count))
            failed_tests=$((failed_tests + test_count))
            test_results+=("❌ $(basename "$test_file") - Some tests failed")
            echo -e "${RED}❌ Some tests in $(basename "$test_file") failed${NC}"
        fi
        echo ""
    fi
done

# Summary
echo "=================================================="
echo -e "${BLUE}📊 Test Summary${NC}"
echo "=================================================="

for result in "${test_results[@]}"; do
    echo "$result"
done

echo ""
echo -e "Total tests: ${BLUE}$total_tests${NC}"
echo -e "Passed: ${GREEN}$passed_tests${NC}"
echo -e "Failed: ${RED}$failed_tests${NC}"

if [[ $failed_tests -eq 0 ]]; then
    echo ""
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo ""
    echo -e "${RED}💥 Some tests failed!${NC}"
    exit 1
fi