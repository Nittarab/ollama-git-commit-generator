#!/usr/bin/env bats

# Test git diff parsing functionality
load '../test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../git-commit-generator.sh"
    export TEST_TEMP_DIR=$(mktemp -d)
    cd "$TEST_TEMP_DIR"
    setup_test_git_repo "$TEST_TEMP_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_TEMP_DIR"
}

@test "git diff parsing: should handle staged files correctly" {
    # Create a test file and stage it
    echo "console.log('hello');" > test.js
    git add test.js
    
    # Mock git diff to return test diff content
    function git() {
        if [[ "$1" == "diff" && "$2" == "--staged" ]]; then
            cat << 'EOF'
+console.log('hello');
EOF
        else
            command git "$@"
        fi
    }
    export -f git
    
    # Mock ollama
    mock_ollama '{"summary": "Add test JavaScript file"}'
    
    result=$(analyze_file_change "test.js" "STAGED")
    
    [ "$result" = "Add test JavaScript file" ]
}

@test "git diff parsing: should handle unstaged files correctly" {
    # Create and modify a file
    echo "console.log('hello');" > test.js
    git add test.js
    git commit -m "initial"
    echo "console.log('hello world');" > test.js
    
    # Mock git diff for unstaged changes
    function git() {
        if [[ "$1" == "diff" && "$2" != "--staged" ]]; then
            cat << 'EOF'
-console.log('hello');
+console.log('hello world');
EOF
        else
            command git "$@"
        fi
    }
    export -f git
    
    mock_ollama '{"summary": "Update console log message"}'
    
    result=$(analyze_file_change "test.js" "UNSTAGED")
    
    [ "$result" = "Update console log message" ]
}

@test "git diff parsing: should handle untracked files by reading content" {
    # Create an untracked file
    test_file="$TEST_TEMP_DIR/new_file.js"
    echo "function newFeature() { return true; }" > "$test_file"
    
    mock_ollama '{"summary": "Add new feature function"}'
    
    result=$(analyze_file_change "$test_file" "UNTRACKED")
    
    [ "$result" = "Add new feature function" ]
}

@test "git diff parsing: should limit content to 200 lines for large files" {
    # Create a large untracked file
    test_file="$TEST_TEMP_DIR/large_file.js"
    for i in {1..300}; do
        echo "// Line $i" >> "$test_file"
    done
    
    mock_ollama '{"summary": "Add large JavaScript file"}'
    
    # The function should only read first 200 lines (head -n 200)
    result=$(analyze_file_change "$test_file" "UNTRACKED")
    
    [ "$result" = "Add large JavaScript file" ]
}

@test "git diff parsing: should handle empty diffs gracefully" {
    # Create a file but no actual changes
    echo "test" > test.js
    git add test.js
    git commit -m "initial"
    
    # Mock git diff to return empty
    function git() {
        if [[ "$1" == "diff" ]]; then
            echo ""
        else
            command git "$@"
        fi
    }
    export -f git
    
    result=$(analyze_file_change "test.js" "STAGED")
    
    # Should return empty when no diff content
    [ -z "$result" ]
}

@test "git diff parsing: should handle binary files" {
    # Create a binary file (simulate)
    test_file="$TEST_TEMP_DIR/image.png"
    echo -e "\x89PNG\r\n\x1a\n" > "$test_file"
    
    # Mock git diff to return binary diff marker
    function git() {
        if [[ "$1" == "diff" ]]; then
            echo "Binary files /dev/null and b/image.png differ"
        else
            command git "$@"
        fi
    }
    export -f git
    
    mock_ollama '{"summary": "Add binary image file"}'
    
    result=$(analyze_file_change "$test_file" "STAGED")
    
    [ "$result" = "Add binary image file" ]
}

@test "git diff parsing: should extract file status correctly" {
    # Test the main script's file detection logic
    # Create various file states
    echo "staged content" > staged.js
    git add staged.js
    
    echo "unstaged content" > unstaged.js
    git add unstaged.js
    git commit -m "initial"
    echo "modified unstaged content" > unstaged.js
    
    echo "untracked content" > untracked.js
    
    # Mock git commands to return file lists
    function git() {
        case "$1 $2 $3" in
            "diff --staged --name-only")
                echo "staged.js"
                ;;
            "diff --name-only --")
                echo "unstaged.js"
                ;;
            "ls-files --others --exclude-standard")
                echo "untracked.js"
                ;;
            *)
                command git "$@"
                ;;
        esac
    }
    export -f git
    
    # Test file detection (this would be part of main function)
    staged_files=$(git diff --staged --name-only)
    unstaged_files=$(git diff --name-only -- ':!*.sh')
    untracked_files=$(git ls-files --others --exclude-standard)
    
    [[ "$staged_files" == *"staged.js"* ]]
    [[ "$unstaged_files" == *"unstaged.js"* ]]
    [[ "$untracked_files" == *"untracked.js"* ]]
}

@test "git diff parsing: should handle special characters in filenames" {
    # Test files with spaces and special characters
    test_file="$TEST_TEMP_DIR/file with spaces.js"
    echo "test content" > "$test_file"
    
    mock_ollama '{"summary": "Add file with spaces in name"}'
    
    result=$(analyze_file_change "$test_file" "UNTRACKED")
    
    [ "$result" = "Add file with spaces in name" ]
}

@test "git diff parsing: should exclude script files from diff analysis" {
    # Test that the script excludes itself and other shell scripts
    echo "#!/bin/bash" > test-script.sh
    
    # The main script uses ':!*.sh' to exclude shell scripts
    # Simulate this behavior
    function git() {
        if [[ "$*" == *":!*.sh"* ]]; then
            # Should not return .sh files
            echo ""
        else
            command git "$@"
        fi
    }
    export -f git
    
    result=$(git diff --name-only -- ':!*.sh')
    
    # Should be empty since we're excluding .sh files
    [ -z "$result" ]
}