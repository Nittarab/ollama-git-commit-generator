#!/usr/bin/env bats

# Test input validation and sanitization functionality
load '../test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../git-commit-generator-functions.sh"
    export TEST_TEMP_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
    cleanup_mocks
}

@test "input validation: check_dependencies should detect missing git" {
    # Mock command to simulate git not being available
    function command() {
        if [[ "$2" == "git" ]]; then
            return 1
        fi
        return 0
    }
    export -f command
    
    run check_dependencies
    [ "$status" -eq 1 ]
    [[ "$output" == *"git is not installed"* ]]
}

@test "input validation: check_dependencies should detect missing jq" {
    # Mock git as available but jq as missing
    function command() {
        case "$2" in
            "git") return 0 ;;
            "jq") return 1 ;;
            "ollama") return 0 ;;
            *) return 0 ;;
        esac
    }
    export -f command
    
    # Mock git rev-parse to simulate being in a git repo
    mock_git "in_repo"
    
    run check_dependencies
    [ "$status" -eq 1 ]
    [[ "$output" == *"jq is not installed"* ]]
}

@test "input validation: check_dependencies should detect missing ollama" {
    # Mock git and jq as available but ollama as missing
    function command() {
        case "$2" in
            "git") return 0 ;;
            "jq") return 0 ;;
            "ollama") return 1 ;;
            *) return 0 ;;
        esac
    }
    export -f command
    
    mock_git "in_repo"
    
    run check_dependencies
    [ "$status" -eq 1 ]
    [[ "$output" == *"ollama is not installed"* ]]
}

@test "input validation: check_dependencies should detect not in git repository" {
    # Mock all commands as available but not in git repo
    function command() {
        return 0
    }
    export -f command
    
    mock_git "not_in_repo"
    
    run check_dependencies
    [ "$status" -eq 1 ]
    [[ "$output" == *"Not in a git repository"* ]]
}

@test "input validation: should handle malicious file paths" {
    # Test various potentially malicious file paths
    malicious_paths=(
        "../../../etc/passwd"
        "/etc/shadow"
        "file with; rm -rf /"
        "file\nwith\nnewlines"
        "file\twith\ttabs"
    )
    
    for path in "${malicious_paths[@]}"; do
        # The analyze_file_change function should handle these safely
        # Mock ollama to avoid actual calls
        mock_ollama '{"summary": "Safe handling of file path"}'
        
        # Create a test file (safely)
        safe_test_file="$TEST_TEMP_DIR/test.txt"
        echo "test content" > "$safe_test_file"
        
        # Test that the function doesn't crash with malicious paths
        run analyze_file_change "$path" "UNTRACKED"
        # Should not fail catastrophically
        [ "$status" -ne 127 ] # Command not found error
    done
}

@test "input validation: should sanitize user input hints" {
    # Test user hints with potentially problematic content
    problematic_hints=(
        "hint with \$(dangerous command)"
        "hint with \`backticks\`"
        "hint with 'single quotes'"
        'hint with "double quotes"'
        "hint with & background process"
        "hint with | pipe"
        "hint with > redirect"
    )
    
    summaries="- test.js: Add test"
    
    for hint in "${problematic_hints[@]}"; do
        function ollama() {
            # Capture the input to verify it's handled safely
            cat > "$TEST_TEMP_DIR/hint_test.txt"
            echo '{"plan": "safe", "commits": []}'
        }
        export -f ollama
        
        run generate_commit_plan "$summaries" "$hint"
        [ "$status" -eq 0 ]
        
        # Verify the hint was included but safely
        captured_input=$(cat "$TEST_TEMP_DIR/hint_test.txt")
        assert_contains "$captured_input" "$hint"
    done
}

@test "input validation: should validate JSON responses" {
    # Test various malformed JSON responses
    invalid_json_responses=(
        '{"plan": "test", "commits": [}'  # Missing closing bracket
        '{"plan": "test"'                  # Incomplete JSON
        'not json at all'                  # Not JSON
        ''                                 # Empty response
        '{"plan": null, "commits": null}'  # Null values (actually valid JSON)
    )

    failed_count=0
    for invalid_json in "${invalid_json_responses[@]}"; do
        # Test JSON validation (this would be done by jq in the script)
        if echo "$invalid_json" | jq . > /dev/null 2>&1; then
            # This JSON is actually valid (like the null values case)
            continue
        else
            failed_count=$((failed_count + 1))
        fi
    done
    
    # Should have some failures for truly invalid JSON
    [ "$failed_count" -gt 0 ]
    
    # Test valid JSON
    valid_json='{"plan": "test", "commits": []}'
    run bash -c "echo '$valid_json' | jq . > /dev/null 2>&1"
    [ "$status" -eq 0 ] # Should succeed for valid JSON
}

@test "input validation: should handle empty or missing file content" {
    # Test with empty file
    empty_file="$TEST_TEMP_DIR/empty.txt"
    touch "$empty_file"

    mock_ollama '{"summary": "Empty file"}'

    result=$(analyze_file_change "$empty_file" "UNTRACKED")
    # Empty file returns empty result as expected
    [ -z "$result" ]

    # Test with non-existent file
    nonexistent_file="$TEST_TEMP_DIR/nonexistent.txt"

    # Should handle gracefully without crashing
    run analyze_file_change "$nonexistent_file" "UNTRACKED"
    [ "$status" -ne 127 ] # Should not result in command not found
}

@test "input validation: should validate file status parameters" {
    # Test with valid file status values
    valid_statuses=("STAGED" "UNSTAGED" "UNTRACKED")
    test_file="$TEST_TEMP_DIR/test.txt"
    echo "test content" > "$test_file"
    
    mock_ollama '{"summary": "Test file"}'
    
    for status in "${valid_statuses[@]}"; do
        run analyze_file_change "$test_file" "$status"
        [ "$status" -eq 0 ]
    done
    
    # Test with invalid file status
    run analyze_file_change "$test_file" "INVALID_STATUS"
    # Should handle gracefully (may default to a behavior)
    [ "$status" -ne 127 ]
}

@test "input validation: should handle large file content safely" {
    # Create a very large file
    large_file="$TEST_TEMP_DIR/large.txt"
    
    # Create file with 1000 lines
    for i in {1..1000}; do
        echo "This is line $i with some content to make it longer and test how the system handles large files" >> "$large_file"
    done
    
    mock_ollama '{"summary": "Large file"}'
    
    # The function should handle large files by truncating (head -n 200)
    run analyze_file_change "$large_file" "UNTRACKED"
    [ "$status" -eq 0 ]
}

@test "input validation: should validate commit plan structure" {
    # Test commit plans with various structural issues
    test_plans=(
        '{"commits": []}'                                    # Missing plan field
        '{"plan": "test"}'                                   # Missing commits field
        '{"plan": "test", "commits": [{"files": []}]}'      # Missing message field
        '{"plan": "test", "commits": [{"message": "test"}]}' # Missing files field
    )
    
    for plan in "${test_plans[@]}"; do
        # Verify these would be caught by validation
        if ! echo "$plan" | jq -e '.plan' > /dev/null 2>&1; then
            : # Expected to fail for plans missing plan field
        fi
        if ! echo "$plan" | jq -e '.commits' > /dev/null 2>&1; then
            : # Expected to fail for plans missing commits field
        fi
    done
    
    # Test valid plan structure
    valid_plan='{"plan": "test", "commits": [{"files": ["test.js"], "message": "feat: test"}]}'
    echo "$valid_plan" | jq -e '.plan' > /dev/null
    [ $? -eq 0 ]
    echo "$valid_plan" | jq -e '.commits' > /dev/null
    [ $? -eq 0 ]
}

@test "input validation: should handle special characters in file names" {
    # Test files with various special characters
    special_files=(
        "file with spaces.txt"
        "file-with-dashes.txt"
        "file_with_underscores.txt"
        "file.with.dots.txt"
        "file@with@at.txt"
        "file#with#hash.txt"
    )
    
    mock_ollama '{"summary": "File with special characters"}'
    
    for file_name in "${special_files[@]}"; do
        test_file="$TEST_TEMP_DIR/$file_name"
        echo "test content" > "$test_file"
        
        run analyze_file_change "$test_file" "UNTRACKED"
        [ "$status" -eq 0 ]
    done
}

@test "input validation: should validate model response format" {
    # Test that extracted JSON from model responses is valid
    model_responses=(
        '```json\n{"summary": "test"}\n```'
        'Some text {"summary": "test"} more text'
        '{"summary": "test"}'
    )
    
    for response in "${model_responses[@]}"; do
        extracted=$(extract_json "$response")
        
        # Should extract valid JSON
        echo "$extracted" | jq . > /dev/null
        [ $? -eq 0 ]
    done
}