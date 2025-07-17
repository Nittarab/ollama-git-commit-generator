#!/usr/bin/env bash

# Test helper functions for the ollama-git-commit-generator tests

# Setup test environment
setup_test_git_repo() {
    local repo_dir="$1"
    mkdir -p "$repo_dir"
    cd "$repo_dir"
    git init --quiet
    git config user.name "Test User"
    git config user.email "test@example.com"
}

# Mock functions for external dependencies
mock_ollama() {
    local response="$1"
    function ollama() {
        echo "$response"
    }
    export -f ollama
}

mock_git() {
    local behavior="$1"
    case "$behavior" in
        "success")
            function git() {
                return 0
            }
            ;;
        "failure")
            function git() {
                return 1
            }
            ;;
        "in_repo")
            function git() {
                if [[ "$1" == "rev-parse" && "$2" == "--git-dir" ]]; then
                    return 0
                fi
                return 0
            }
            ;;
        "not_in_repo")
            function git() {
                if [[ "$1" == "rev-parse" && "$2" == "--git-dir" ]]; then
                    return 1
                fi
                return 0
            }
            ;;
    esac
    export -f git
}

mock_jq() {
    local behavior="$1"
    case "$behavior" in
        "success")
            function jq() {
                # Simple mock that processes basic JSON
                if [[ "$1" == "." ]]; then
                    cat
                elif [[ "$1" == "-r" && "$2" == ".summary" ]]; then
                    echo "Test summary"
                elif [[ "$1" == "-c" && "$2" == "." ]]; then
                    cat | tr -d '\n' | tr -s ' '
                else
                    return 0
                fi
            }
            ;;
        "failure")
            function jq() {
                return 1
            }
            ;;
    esac
    export -f jq
}

# Create test files with specific content
create_test_file() {
    local filepath="$1"
    local content="$2"
    
    mkdir -p "$(dirname "$filepath")"
    echo "$content" > "$filepath"
}

# Create test diff content
create_test_diff() {
    local diff_type="$1"
    
    case "$diff_type" in
        "simple")
            cat << 'EOF'
diff --git a/src/test.js b/src/test.js
new file mode 100644
index 0000000..e69de29
--- /dev/null
+++ b/src/test.js
@@ -0,0 +1,3 @@
+function test() {
+    return "hello world";
+}
EOF
            ;;
        "complex")
            cat << 'EOF'
diff --git a/src/auth.js b/src/auth.js
index abc123..def456 100644
--- a/src/auth.js
+++ b/src/auth.js
@@ -1,5 +1,10 @@
 function authenticate(user) {
-    return user.isValid;
+    if (!user) {
+        throw new Error('User is required');
+    }
+    return user.isValid && user.hasPermission;
 }
 
+function logout(user) {
+    user.token = null;
+}
EOF
            ;;
        "empty")
            echo ""
            ;;
    esac
}

# Verify JSON structure
verify_json_structure() {
    local json="$1"
    local expected_fields="$2"
    
    for field in $expected_fields; do
        if ! echo "$json" | jq -e ".$field" > /dev/null 2>&1; then
            return 1
        fi
    done
    return 0
}

# Clean up mock functions
cleanup_mocks() {
    unset -f ollama git jq
}

# Assertion helpers
assert_contains() {
    local text="$1"
    local substring="$2"
    
    if [[ "$text" != *"$substring"* ]]; then
        echo "Expected '$text' to contain '$substring'"
        return 1
    fi
}

assert_json_valid() {
    local json="$1"
    
    if ! echo "$json" | jq . > /dev/null 2>&1; then
        echo "Expected valid JSON, got: $json"
        return 1
    fi
}

assert_file_exists() {
    local filepath="$1"
    
    if [[ ! -f "$filepath" ]]; then
        echo "Expected file to exist: $filepath"
        return 1
    fi
}

# Test data generators
generate_test_summaries() {
    cat << 'EOF'
- src/auth.js (Staged): Add user authentication with validation
- src/utils.js (Unstaged): Fix utility function error handling
- tests/auth.test.js (Untracked): Add comprehensive auth tests
- README.md (Staged): Update documentation for new auth features
EOF
}

generate_valid_commit_plan() {
    cat << 'EOF'
{
  "plan": "Implement user authentication system with proper testing and documentation",
  "commits": [
    {
      "files": ["src/auth.js", "src/utils.js"],
      "message": "feat: implement user authentication with validation"
    },
    {
      "files": ["tests/auth.test.js"],
      "message": "test: add comprehensive authentication tests"
    },
    {
      "files": ["README.md"],
      "message": "docs: update documentation for authentication features"
    }
  ]
}
EOF
}

generate_invalid_commit_plan() {
    cat << 'EOF'
{
  "plan": "Implement user authentication system",
  "commits": [
    {
      "files": ["src/auth.js"],
      "message": "feat: implement user authentication"
    }
  # Missing closing brace
EOF
}