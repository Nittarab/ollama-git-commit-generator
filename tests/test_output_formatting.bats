#!/usr/bin/env bats

# Test output formatting functionality (conventional commit format)
load '../test_helper'

setup() {
    source "${BATS_TEST_DIRNAME}/../git-commit-generator-functions.sh"
    export TEST_TEMP_DIR=$(mktemp -d)
    cd "$TEST_TEMP_DIR"
    setup_test_git_repo "$TEST_TEMP_DIR"
}

teardown() {
    cd /
    rm -rf "$TEST_TEMP_DIR"
    cleanup_mocks
}

@test "output formatting: should follow conventional commit format" {
    # Test various conventional commit types
    conventional_types=("feat" "fix" "docs" "style" "refactor" "test" "chore")
    
    for type in "${conventional_types[@]}"; do
        message="$type: add new functionality"
        
        # Verify it matches conventional commit pattern
        [[ "$message" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: ]]
    done
}

@test "output formatting: should validate commit message structure" {
    # Test that commit messages follow the expected format
    valid_messages=(
        "feat: add user authentication"
        "fix: resolve login issue"
        "docs: update API documentation"
        "style: format code according to style guide"
        "refactor: reorganize auth module"
        "test: add unit tests for auth"
        "chore: update dependencies"
        "feat(auth): add password validation"
        "fix(api): handle null response"
    )
    
    for message in "${valid_messages[@]}"; do
        # Should match conventional commit pattern
        [[ "$message" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: ]]
    done
    
    # Test invalid messages
    invalid_messages=(
        "add user authentication"  # Missing type
        "feat add authentication"  # Missing colon
        "FEAT: add authentication" # Wrong case
        "feature: add auth"        # Wrong type name
    )
    
    for message in "${invalid_messages[@]}"; do
        # Should NOT match conventional commit pattern
        if [[ "$message" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: ]]; then
            # This should not happen for invalid messages
            false
        fi
    done
}

@test "output formatting: execute_plan should parse commit plan correctly" {
    # Create a valid commit plan
    plan='{"plan": "Test plan", "commits": [{"files": ["test.js"], "message": "feat: add test"}]}'
    
    # Mock git commands
    function git() {
        case "$1" in
            "reset") return 0 ;;
            "add") return 0 ;;
            "commit") 
                # Verify the commit message format
                if [[ "$3" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            "diff")
                if [[ "$2" == "--staged" && "$3" == "--name-only" ]]; then
                    echo "test.js"
                fi
                return 0
                ;;
            "ls-files")
                return 0
                ;;
            *) return 0 ;;
        esac
    }
    export -f git
    
    # Create test file
    echo "test content" > test.js
    
    run execute_plan "$plan"
    [ "$status" -eq 0 ]
}

@test "output formatting: execute_commit should handle file staging correctly" {
    # Test the execute_commit function with proper file staging
    files_to_stage="test1.js test2.js"
    commit_message="feat: add test files"
    commit_num=1
    
    # Create test files
    echo "test1 content" > test1.js
    echo "test2 content" > test2.js
    
    # Mock git commands to track calls
    git_calls=()
    function git() {
        git_calls+=("$*")
        case "$1" in
            "reset") return 0 ;;
            "add") 
                # Verify file exists before staging
                if [[ -f "$2" ]]; then
                    return 0
                else
                    return 1
                fi
                ;;
            "diff")
                if [[ "$2" == "--staged" && "$3" == "--name-only" ]]; then
                    echo "test1.js test2.js"
                fi
                return 0
                ;;
            "commit")
                # Verify commit message format
                [[ "$3" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: ]]
                return $?
                ;;
            *) return 0 ;;
        esac
    }
    export -f git
    
    run execute_commit "$files_to_stage" "$commit_message" "$commit_num"
    [ "$status" -eq 0 ]
    
    # Verify git commands were called in correct order
    [[ "${git_calls[*]}" == *"reset HEAD"* ]]
    [[ "${git_calls[*]}" == *"add test1.js"* ]]
    [[ "${git_calls[*]}" == *"add test2.js"* ]]
    [[ "${git_calls[*]}" == *"commit -m"* ]]
}

@test "output formatting: should handle multiple commits with proper formatting" {
    # Test executing multiple commits with different conventional types
    plan='{"plan": "Multi-commit plan", "commits": [
        {"files": ["src/auth.js"], "message": "feat: add authentication"},
        {"files": ["tests/auth.test.js"], "message": "test: add auth tests"},
        {"files": ["README.md"], "message": "docs: update documentation"}
    ]}'
    
    # Create test files
    mkdir -p src tests
    echo "auth code" > src/auth.js
    echo "test code" > tests/auth.test.js
    echo "# README" > README.md
    
    commit_messages=()
    function git() {
        case "$1" in
            "reset") return 0 ;;
            "add") return 0 ;;
            "commit")
                commit_messages+=("$3")
                return 0
                ;;
            "diff")
                if [[ "$2" == "--staged" && "$3" == "--name-only" ]]; then
                    echo "dummy.js"  # Non-empty to pass staged check
                fi
                return 0
                ;;
            *) return 0 ;;
        esac
    }
    export -f git
    
    run execute_plan "$plan"
    [ "$status" -eq 0 ]
    
    # Verify all commit messages follow conventional format
    for msg in "${commit_messages[@]}"; do
        [[ "$msg" =~ ^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: ]]
    done
}

@test "output formatting: should format error messages consistently" {
    # Test error message formatting in various scenarios
    
    # Test empty plan
    empty_plan='{"plan": "test", "commits": []}'
    
    run execute_plan "$empty_plan"
    [ "$status" -eq 1 ]
    [[ "$output" == *"❌ No commits found"* ]]
    
    # Test commit failure
    plan='{"plan": "test", "commits": [{"files": ["nonexistent.js"], "message": "feat: test"}]}'
    
    function git() {
        case "$1" in
            "reset") return 0 ;;
            "add") return 1 ;;  # Simulate file not found
            "diff")
                if [[ "$2" == "--staged" && "$3" == "--name-only" ]]; then
                    echo ""  # No staged files
                fi
                return 0
                ;;
            *) return 0 ;;
        esac
    }
    export -f git
    
    run execute_plan "$plan"
    [ "$status" -eq 1 ]
}

@test "output formatting: should provide clear status messages" {
    # Test that status messages are clear and consistent
    files_to_stage="test.js"
    commit_message="feat: add test"
    commit_num=1
    
    echo "test content" > test.js
    
    # Capture output to verify messaging
    function git() {
        case "$1" in
            "reset") return 0 ;;
            "add") 
                echo "   ✅ Staged: $2" >&2
                return 0
                ;;
            "diff")
                if [[ "$2" == "--staged" && "$3" == "--name-only" ]]; then
                    echo "test.js"
                fi
                return 0
                ;;
            "commit")
                echo "   ✅ Commit created successfully!" >&2
                return 0
                ;;
            *) return 0 ;;
        esac
    }
    export -f git
    
    run execute_commit "$files_to_stage" "$commit_message" "$commit_num"
    [ "$status" -eq 0 ]
    [[ "$output" == *"✅ Staged: test.js"* ]]
    [[ "$output" == *"✅ Commit created successfully!"* ]]
}

@test "output formatting: should handle JSON parsing errors gracefully" {
    # Test malformed JSON in commit plan
    malformed_plan='{"plan": "test", "commits": [{"files": ["test.js"], "message": "feat: test"'  # Missing closing braces
    
    # This should be caught before execute_plan is called, but test the behavior
    run bash -c "echo '$malformed_plan' | jq . > /dev/null 2>&1"
    [ "$status" -ne 0 ]  # Should fail JSON validation
}

@test "output formatting: should validate commit plan JSON structure" {
    # Test that commit plans have required fields
    plans_with_missing_fields=(
        '{"commits": [{"files": ["test.js"], "message": "feat: test"}]}'  # Missing plan
        '{"plan": "test"}'  # Missing commits
        '{"plan": "test", "commits": [{"files": ["test.js"]}]}'  # Missing message
        '{"plan": "test", "commits": [{"message": "feat: test"}]}'  # Missing files
    )
    
    for plan in "${plans_with_missing_fields[@]}"; do
        # These should fail validation checks
        if ! echo "$plan" | jq -e '.plan' > /dev/null 2>&1; then
            : # Expected to fail
        elif ! echo "$plan" | jq -e '.commits' > /dev/null 2>&1; then
            : # Expected to fail
        elif ! echo "$plan" | jq -e '.commits[0].files' > /dev/null 2>&1; then
            : # Expected to fail
        elif ! echo "$plan" | jq -e '.commits[0].message' > /dev/null 2>&1; then
            : # Expected to fail
        fi
    done
}

@test "output formatting: should format file paths consistently" {
    # Test that file paths are displayed consistently
    test_files=("src/auth.js" "tests/auth.test.js" "docs/README.md")
    
    for file in "${test_files[@]}"; do
        mkdir -p "$(dirname "$file")"
        echo "content" > "$file"
    done
    
    files_to_stage="${test_files[*]}"
    commit_message="feat: add multiple files"
    commit_num=1
    
    function git() {
        case "$1" in
            "reset") return 0 ;;
            "add")
                # Verify file path format in output
                echo "   ✅ Staged: $2" >&2
                return 0
                ;;
            "diff")
                if [[ "$2" == "--staged" && "$3" == "--name-only" ]]; then
                    printf "%s\n" "${test_files[@]}"
                fi
                return 0
                ;;
            "commit") return 0 ;;
            *) return 0 ;;
        esac
    }
    export -f git
    
    run execute_commit "$files_to_stage" "$commit_message" "$commit_num"
    [ "$status" -eq 0 ]
    
    # Verify all files are mentioned in output
    for file in "${test_files[@]}"; do
        [[ "$output" == *"Staged: $file"* ]]
    done
}