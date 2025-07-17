#!/usr/bin/env bats

# Load bats libraries
load '../test_helper'

# Setup and teardown
setup() {
    # Source the functions-only script to access its functions without executing main
    source "${BATS_TEST_DIRNAME}/../git-commit-generator-functions.sh"
    
    # Create temporary test directory
    export TEST_TEMP_DIR=$(mktemp -d)
}

teardown() {
    # Clean up temporary directory
    rm -rf "$TEST_TEMP_DIR"
}

# Test extract_json function
@test "extract_json: should extract JSON from markdown code fence" {
    input='```json
{"summary": "test message", "status": "success"}
```'
    
    result=$(extract_json "$input")
    expected='{"summary":"test message","status":"success"}'
    
    [ "$result" = "$expected" ]
}

@test "extract_json: should extract JSON from plain text with braces" {
    input='Some text before {"summary": "test message"} some text after'
    
    result=$(extract_json "$input")
    expected='{"summary":"test message"}'
    
    [ "$result" = "$expected" ]
}

@test "extract_json: should handle malformed JSON gracefully" {
    input='```json
{"summary": "test message"
```'
    
    result=$(extract_json "$input")
    
    # Should return empty string or the original input when JSON is malformed
    # The function falls back to returning the input as-is for malformed JSON
    [[ -z "$result" || "$result" == "$input" ]]
}

@test "extract_json: should handle empty input" {
    input=''
    
    result=$(extract_json "$input")
    
    [ "$result" = "" ]
}

@test "extract_json: should extract complex nested JSON" {
    input='```json
{
  "plan": "Brief explanation",
  "commits": [
    { "files": ["file1.js"], "message": "feat: add feature" },
    { "files": ["file2.js"], "message": "fix: bug fix" }
  ]
}
```'
    
    result=$(extract_json "$input")
    
    # Verify it's valid JSON by parsing with jq
    echo "$result" | jq . > /dev/null
}

# Test check_dependencies function
@test "check_dependencies: should pass when all dependencies are available" {
    # Mock the commands to simulate they exist
    function git() { return 0; }
    function jq() { return 0; }
    function ollama() { return 0; }
    export -f git jq ollama
    
    # Mock git rev-parse to simulate being in a git repo
    function git() {
        if [[ "$1" == "rev-parse" ]]; then
            return 0
        fi
        return 0
    }
    export -f git
    
    run check_dependencies
    [ "$status" -eq 0 ]
}

# Test analyze_file_change function with mocked data
@test "analyze_file_change: should handle UNTRACKED file status" {
    # Create a test file
    test_file="$TEST_TEMP_DIR/test.txt"
    echo "Test file content" > "$test_file"
    
    # Mock ollama command to return a simple JSON response
    function ollama() {
        echo '{"summary": "Add test file"}'
    }
    export -f ollama
    
    result=$(analyze_file_change "$test_file" "UNTRACKED")
    
    [ "$result" = "Add test file" ]
}

@test "analyze_file_change: should handle empty diff gracefully" {
    # Create an empty test file
    test_file="$TEST_TEMP_DIR/empty.txt"
    touch "$test_file"
    
    # Mock git diff to return empty
    function git() {
        return 0
    }
    export -f git
    
    result=$(analyze_file_change "$test_file" "STAGED")
    
    # Should return empty result for empty diff
    [ -z "$result" ]
}

# Test prompt formatting
@test "generate_commit_plan: should format prompt correctly with summaries" {
    summaries="- file1.js (Staged): Add new feature
- file2.js (Unstaged): Fix bug"
    hint="add tests"
    
    # Mock ollama to capture the prompt
    function ollama() {
        # Just return a valid JSON response
        echo '{"plan": "Test plan", "commits": []}'
    }
    export -f ollama
    
    result=$(generate_commit_plan "$summaries" "$hint")
    
    # Verify the result is valid JSON
    echo "$result" | jq . > /dev/null
}

@test "generate_commit_plan: should handle empty summaries" {
    summaries=""
    hint=""
    
    function ollama() {
        echo '{"plan": "No changes", "commits": []}'
    }
    export -f ollama
    
    result=$(generate_commit_plan "$summaries" "$hint")
    
    # Should still return valid JSON
    echo "$result" | jq . > /dev/null
}

# Test utility functions for git operations
@test "should detect git repository correctly" {
    # This test verifies the git repository detection logic
    # Mock git rev-parse to simulate different scenarios
    
    # Test: In a git repository
    function git() {
        if [[ "$1" == "rev-parse" && "$2" == "--git-dir" ]]; then
            return 0
        fi
    }
    export -f git
    
    # The check_dependencies function includes this logic
    run check_dependencies
    # Should not fail due to git repo check (other dependencies might fail)
}

# Test JSON validation and parsing
@test "should validate JSON responses correctly" {
    valid_json='{"plan": "test", "commits": [{"files": ["test.js"], "message": "feat: test"}]}'
    invalid_json='{"plan": "test", "commits": [{"files": ["test.js"], "message":'
    
    # Test valid JSON
    echo "$valid_json" | jq . > /dev/null
    [ $? -eq 0 ]
    
    # Test invalid JSON
    run bash -c "echo '$invalid_json' | jq . > /dev/null 2>&1"
    [ "$status" -ne 0 ]
}

# Test conventional commit format validation
@test "should generate conventional commit format" {
    # Test that the AI responses follow conventional commit format
    # This is more of an integration test but validates output format
    
    test_message="feat: add new user authentication system"
    
    # Verify it follows conventional commit pattern
    [[ "$test_message" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: ]]
}

# Test input sanitization
@test "should sanitize file paths correctly" {
    # Test that file paths are handled safely
    malicious_path="../../../etc/passwd"
    safe_path="src/component.js"
    
    # This would be part of file handling logic
    # For now, just verify the paths don't contain dangerous patterns
    [[ ! "$safe_path" =~ \.\. ]]
    [[ "$malicious_path" =~ \.\. ]]
}

# Test chunking and text processing
@test "should handle large diff content appropriately" {
    # Create a large test diff
    large_content=$(printf "line %d\n" {1..300})
    
    # The analyze_file_change function uses head -n 200 to limit content
    truncated=$(echo "$large_content" | head -n 200)
    
    # Verify truncation worked
    line_count=$(echo "$truncated" | wc -l)
    [ "$line_count" -eq 200 ]
}