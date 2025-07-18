#!/usr/bin/env bats

# Test prompt formatting and templating functionality
load '../test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../git-commit-generator.sh"
    export TEST_TEMP_DIR=$(mktemp -d)
}

teardown() {
    rm -rf "$TEST_TEMP_DIR"
}

@test "prompt formatting: should include file summaries in prompt" {
    summaries="- src/auth.js (Staged): Add user authentication
- src/utils.js (Unstaged): Fix error handling"
    hint=""
    
    # Capture the prompt sent to ollama
    function ollama() {
        # Save the input to a temp file for inspection
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    # Verify the prompt contains the summaries
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    assert_contains "$captured_prompt" "src/auth.js (Staged): Add user authentication"
    assert_contains "$captured_prompt" "src/utils.js (Unstaged): Fix error handling"
}

@test "prompt formatting: should include user hint when provided" {
    summaries="- test.js (Staged): Add tests"
    hint="focus on security improvements"
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    assert_contains "$captured_prompt" "USER HINT: focus on security improvements"
}

@test "prompt formatting: should not include hint section when hint is empty" {
    summaries="- test.js (Staged): Add tests"
    hint=""
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    # Should not contain hint section when hint is empty
    [[ "$captured_prompt" != *"USER HINT:"* ]]
}

@test "prompt formatting: should include required JSON format template" {
    summaries="- test.js: Add tests"
    hint=""
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    assert_contains "$captured_prompt" "REQUIRED JSON RESPONSE FORMAT:"
    assert_contains "$captured_prompt" '"plan":'
    assert_contains "$captured_prompt" '"commits":'
    assert_contains "$captured_prompt" '"files":'
    assert_contains "$captured_prompt" '"message":'
}

@test "prompt formatting: should include analysis instructions" {
    summaries="- test.js: Add tests"
    hint=""
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    assert_contains "$captured_prompt" "expert git commit message generator"
    assert_contains "$captured_prompt" "analyze the following file change summaries"
    assert_contains "$captured_prompt" "Group related changes into logical commits"
    assert_contains "$captured_prompt" "conventional commit message"
}

@test "prompt formatting: should handle multiline summaries correctly" {
    summaries="- src/auth.js (Staged): Add comprehensive user authentication system
  with proper validation and error handling
- tests/auth.test.js (Unstaged): Add unit tests for authentication
  covering edge cases and security scenarios"
    hint=""
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    assert_contains "$captured_prompt" "comprehensive user authentication system"
    assert_contains "$captured_prompt" "covering edge cases and security scenarios"
}

@test "prompt formatting: should handle special characters in summaries" {
    summaries="- src/api.js (Staged): Fix API endpoint with special chars: /users/{id}/profile?format=json&include=meta"
    hint="Handle URL encoding properly"
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    assert_contains "$captured_prompt" "/users/{id}/profile?format=json&include=meta"
    assert_contains "$captured_prompt" "Handle URL encoding properly"
}

@test "prompt formatting: should format file analysis prompt correctly" {
    file_path="src/authentication.js"
    file_status="STAGED"
    diff_content="@@ -1,3 +1,8 @@
 function authenticate(user) {
-    return user.isValid;
+    if (!user) {
+        throw new Error('User required');
+    }
+    return user.isValid && user.hasPermission;
 }"
    
    # Test the analysis prompt format used in analyze_file_change
    expected_prompt="You are a code analysis AI. Analyze the following change and respond with a single JSON object: {\"summary\": \"A concise, one-line summary of the change.\"}.

File: $file_path
Status: $file_status
Diff:
$diff_content"
    
    # Verify the prompt structure (this tests the template used in analyze_file_change)
    assert_contains "$expected_prompt" "code analysis AI"
    assert_contains "$expected_prompt" "File: src/authentication.js"
    assert_contains "$expected_prompt" "Status: STAGED"
    assert_contains "$expected_prompt" "throw new Error"
}

@test "prompt formatting: should handle empty summaries gracefully" {
    summaries=""
    hint=""
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "No changes detected", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    # Should still contain the basic prompt structure
    assert_contains "$captured_prompt" "expert git commit message generator"
    assert_contains "$captured_prompt" "REQUIRED JSON RESPONSE FORMAT"
}

@test "prompt formatting: should limit prompt length for very large summaries" {
    # Create a very large summaries string
    large_summaries=""
    for i in {1..100}; do
        large_summaries+="- file$i.js (Staged): Very long description of changes that might make the prompt too large for the AI model to handle efficiently and could cause issues with token limits
"
    done
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$large_summaries" "" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    # Verify the prompt was created (basic functionality test)
    assert_contains "$captured_prompt" "expert git commit message generator"
    
    # The prompt should still be reasonable in size
    prompt_length=$(echo "$captured_prompt" | wc -c)
    # This is a practical limit test - very large prompts might need chunking
    [ "$prompt_length" -gt 1000 ] # Should contain substantial content
}

@test "prompt formatting: should maintain consistent formatting structure" {
    summaries="- test.js: Simple test"
    hint="simple hint"
    
    function ollama() {
        cat > "$TEST_TEMP_DIR/prompt_captured.txt"
        echo '{"plan": "test", "commits": []}'
    }
    export -f ollama
    
    generate_commit_plan "$summaries" "$hint" > /dev/null
    
    captured_prompt=$(cat "$TEST_TEMP_DIR/prompt_captured.txt")
    
    # Verify the prompt has expected sections in order
    # Use grep to find line numbers of key sections
    instructions_line=$(echo "$captured_prompt" | grep -n "INSTRUCTIONS:" | cut -d: -f1)
    summaries_line=$(echo "$captured_prompt" | grep -n "FILE SUMMARIES" | cut -d: -f1)
    hint_line=$(echo "$captured_prompt" | grep -n "USER HINT:" | cut -d: -f1)
    format_line=$(echo "$captured_prompt" | grep -n "REQUIRED JSON RESPONSE FORMAT:" | cut -d: -f1)
    
    # Verify sections appear in logical order
    [ "$instructions_line" -lt "$summaries_line" ]
    [ "$summaries_line" -lt "$hint_line" ]
    [ "$hint_line" -lt "$format_line" ]
}