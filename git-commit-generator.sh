#!/bin/bash

# Advanced AI-powered git commit agent
# Usage: ./git-commit-generator.sh [optional hint message]

# --- Configuration ---
USER_HINT="$*"
MODEL_NAME="git-commit-fast"

# --- Helper Functions ---
print_header() {
    echo "🤖 AI Git Commit Agent"
    echo "====================="
}

# Extract JSON from markdown code fences
extract_json() {
    local input="$1"
    # Greedily find the largest JSON object in the input.
    # This is more robust than just looking for markdown fences.
    if echo "$input" | grep -o '{.*}' | jq . >/dev/null 2>&1; then
        echo "$input" | grep -o '{.*}' | jq -c . | head -n 1
    # Fallback for simple cases or when grep fails
    elif echo "$input" | grep -q '```json'; then
        echo "$input" | sed -n '/```json/,/```/p' | sed '1d;$d'
    else
        echo "$input"
    fi
}

check_dependencies() {
    if ! command -v git &> /dev/null; then
        echo "❌ Error: git is not installed."
        exit 1
    fi
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo "❌ Error: Not in a git repository."
        exit 1
    fi
    if ! command -v jq &> /dev/null; then
        echo "❌ Error: jq is not installed. Please install it to continue."
        exit 1
    fi
    if ! command -v ollama &> /dev/null; then
        echo "❌ Error: ollama is not installed."
        exit 1
    fi
}

# --- Core AI Functions ---

# Step 1: Analyze a single file's changes and return a summary.
analyze_file_change() {
    local file_path="$1"
    local file_status="$2" # (e.g., "STAGED", "UNSTAGED", "UNTRACKED")
    local diff_content=""

    if [ "$file_status" == "UNTRACKED" ]; then
        diff_content=$(head -n 200 "$file_path")
    elif [ "$file_status" == "STAGED" ]; then
        diff_content=$(git diff --staged -- "$file_path" | head -n 200)
    else # UNSTAGED
        diff_content=$(git diff -- "$file_path" | head -n 200)
    fi

    # If diff is empty, no need to analyze
    if [ -z "$diff_content" ]; then
        return
    fi

    local analysis_prompt="You are a code analysis AI. Analyze the following change and respond with a single JSON object: {\"summary\": \"A concise, one-line summary of the change.\"}.

File: $file_path
Status: $file_status
Diff:
$diff_content"

    local ai_response
    ai_response=$(echo -e "$analysis_prompt" | ollama run "$MODEL_NAME" 2>/dev/null)
    
    # Extract JSON from potential markdown and then get the summary
    local clean_json
    clean_json=$(extract_json "$ai_response")
    
    # Extract the summary from the JSON response.
    if echo "$clean_json" | jq -e .summary > /dev/null 2>&1; then
        echo "$clean_json" | jq -r .summary
    else
        echo "Could not summarize." # Fallback
    fi
}

# Step 2: Take summaries and generate the final JSON commit plan.
generate_commit_plan() {
    local summaries="$1"
    local hint="$2"

    local plan_prompt="You are an expert git commit message generator. Your task is to analyze the following file change summaries and create a commit plan as a JSON object.

INSTRUCTIONS:
1.  Review the file summaries.
2.  Group related changes into logical commits.
3.  For each commit, provide files to stage and a conventional commit message.
4.  Respond with ONLY a valid JSON object. Do not add any other text.

---FILE SUMMARIES---
$summaries
---END OF SUMMARIES---"

    if [ -n "$hint" ]; then
        plan_prompt+="\n\nUSER HINT: $hint"
    fi

    plan_prompt+="\n\nREQUIRED JSON RESPONSE FORMAT:
{
  \"plan\": \"Brief explanation of the commit strategy.\",
  \"commits\": [
    { \"files\": [\"file1.js\"], \"message\": \"feat: add new feature\" }
  ]
}"

    # The ollama call is now the only thing here to avoid capturing other text
    echo -e "$plan_prompt" | ollama run "$MODEL_NAME"
}

# --- Execution Logic ---

execute_plan() {
    local plan_json="$1"
    echo "🚀 Executing plan..."
    
    local commit_count
    commit_count=$(echo "$plan_json" | jq '.commits | length')
    
    if [ "$commit_count" -eq 0 ]; then
        echo "❌ No commits found in the plan."
        exit 1
    fi

    for i in $(seq 0 $((commit_count - 1))); do
        local commit_info files_to_stage commit_message
        commit_info=$(echo "$plan_json" | jq -c ".commits[$i]")
        files_to_stage=$(echo "$commit_info" | jq -r '.files | .[]')
        commit_message=$(echo "$commit_info" | jq -r '.message')

        execute_commit "$files_to_stage" "$commit_message" $((i + 1))
    done
    
    echo "✅ All commits completed successfully!"
}

execute_commit() {
    local stage_files="$1"
    local commit_message="$2"
    local commit_num="$3"
    
    echo ""
    echo "📝 Commit $commit_num: $commit_message"
    
    git reset HEAD -- . 2>/dev/null || true
    
    for file in $stage_files; do
        if [ -f "$file" ] || git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            git add "$file"
            echo "   ✅ Staged: $file"
        else
            echo "   ⚠️  File not found, skipping: $file"
        fi
    done
    
    local staged
    staged=$(git diff --staged --name-only)
    if [ -z "$staged" ]; then
        echo "   ❌ No files were staged for this commit."
        return 1
    fi
    
    if git commit -m "$commit_message"; then
        echo "   ✅ Commit created successfully!"
    else
        echo "   ❌ Commit failed"
        return 1
    fi
}

# --- Main Script ---

main() {
    print_header
    check_dependencies

    # Get lists of changed files
    STAGED_FILES=$(git diff --staged --name-only)
    UNSTAGED_FILES=$(git diff --name-only -- ':!*.sh') # Exclude self
    UNTRACKED_FILES=$(git ls-files --others --exclude-standard)

    if [ -z "$STAGED_FILES" ] && [ -z "$UNSTAGED_FILES" ] && [ -z "$UNTRACKED_FILES" ]; then
        echo "✅ No changes detected. Nothing to commit."
        exit 0
    fi

    echo "🔍 Analyzing file changes (this may take a moment)..."
    
    # Step 1: Analyze all changes and collect summaries
    ALL_SUMMARIES=""
    for file in $STAGED_FILES; do
        summary=$(analyze_file_change "$file" "STAGED")
        [ -n "$summary" ] && ALL_SUMMARIES+="- $file (Staged): $summary\n"
    done
    for file in $UNSTAGED_FILES; do
        summary=$(analyze_file_change "$file" "UNSTAGED")
        [ -n "$summary" ] && ALL_SUMMARIES+="- $file (Unstaged): $summary\n"
    done
    for file in $UNTRACKED_FILES; do
        summary=$(analyze_file_change "$file" "UNTRACKED")
        [ -n "$summary" ] && ALL_SUMMARIES+="- $file (Untracked): $summary\n"
    done

    if [ -z "$ALL_SUMMARIES" ]; then
        echo "✅ No significant changes found to commit."
        exit 0
    fi

    echo -e "Change Summaries:\n$ALL_SUMMARIES"

    # Step 2: Generate the final plan
    echo "🧠 Generating commit plan from summaries..."
    AI_RESPONSE=$(generate_commit_plan "$ALL_SUMMARIES" "$USER_HINT")
    
    # Extract JSON from potential markdown
    AI_RESPONSE=$(extract_json "$AI_RESPONSE")

    if ! echo "$AI_RESPONSE" | jq . > /dev/null 2>&1; then
        echo "❌ Error: AI response is not valid JSON."
        echo "Raw response:"
        echo "$AI_RESPONSE"
        exit 1
    fi

    echo ""
    echo "🧠 AI Plan:"
    echo "────────────"
    echo "$AI_RESPONSE" | jq .
    echo ""

    # Interactive loop
    while true; do
        echo "Options: (a) Accept, (m) Modify with feedback, (r) Regenerate, (q) Quit"
        read -p "Choose: " choice
        
        case "$choice" in
            "a")
                execute_plan "$AI_RESPONSE"
                break
                ;;
            "m")
                echo "Enter your feedback to the AI:"
                read -r user_message
                echo "🧠 Generating revised plan..."
                AI_RESPONSE=$(generate_commit_plan "$ALL_SUMMARIES" "$user_message")
                AI_RESPONSE=$(extract_json "$AI_RESPONSE")
                echo "🧠 Revised AI Plan:"
                echo "─────────────────"
                echo "$AI_RESPONSE" | jq .
                ;;
            "r")
                echo "🧠 Regenerating plan..."
                AI_RESPONSE=$(generate_commit_plan "$ALL_SUMMARIES" "$USER_HINT")
                AI_RESPONSE=$(extract_json "$AI_RESPONSE")
                echo "🧠 Regenerated AI Plan:"
                echo "───────────────────"
                echo "$AI_RESPONSE" | jq .
                ;;
            "q")
                echo "❌ Operation cancelled"
                exit 0
                ;;
            *) echo "Invalid option" ;;
        esac
    done
}

main "$@"
