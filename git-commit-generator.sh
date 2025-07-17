#!/bin/bash

# Initialize flags
ONLY_MESSAGE=false
VERBOSE=false
HELP=false
UPDATE=false

# Parse command line arguments
for arg in "$@"; do
    case "$arg" in
        "--only-message")
            ONLY_MESSAGE=true
            ;;
        "--verbose")
            VERBOSE=true
            ;;
        "-h"|"--help")
            HELP=true
            ;;
        "--update")
            UPDATE=true
            ;;
    esac
done

# Display help if requested
if [ "$HELP" == "true" ]; then
    echo -e "\033[1;34mGit Commit Message Generator\033[0m"
    echo -e "\033[1;34m======================\033[0m"
    echo -e "This script generates intelligent git commit messages based on staged changes."
    echo -e "\n\033[1mUsage:\033[0m"
    echo -e "  ./git-commit-generator.sh [options]"
    echo -e "\n\033[1mOptions:\033[0m"
    echo -e "  --only-message    Output only the final commit message without UI"
    echo -e "  --verbose         Print detailed steps including chunks and diffs"
    echo -e "  -h, --help        Display this help message"
    echo -e "  --update          Update the Ollama model before running"
    echo -e "\n\033[1mDescription:\033[0m"
    echo -e "  - Analyzes staged git changes (git diff --staged)"
    echo -e "  - Splits changes into chunks for better analysis"
    echo -e "  - Generates micro commit messages for each chunk"
    echo -e "  - Combines them into a final cohesive commit message"
    echo -e "  - Allows review and editing before committing"
    exit 0
fi

# Update Ollama model if requested
if [ "$UPDATE" == "true" ]; then
    echo -e "\033[1;33mUpdating Ollama model...\033[0m"
    ollama pull git-commit-fast
    echo -e "\033[1;32mModel updated successfully!\033[0m"
fi

# Welcome Header
if [ "$ONLY_MESSAGE" == "false" ]; then
    echo -e "\033[1;34m╔═════════════════════════════════════════════════════════════════╗\033[0m"
    echo -e "\033[1;34m║                 Git Commit Message Generator                    ║\033[0m"
    echo -e "\033[1;34m╚═════════════════════════════════════════════════════════════════╝\033[0m"
fi

# Check git status and handle unstaged changes
check_and_stage_files() {
    local staged_diff=$(git diff --staged)
    local unstaged_diff=$(git diff)
    local untracked_files=$(git ls-files --others --exclude-standard)
    
    if [ -n "$staged_diff" ]; then
        echo -e "\033[1;32m✅ Found staged changes ready for commit.\033[0m"
        return 0
    fi
    
    if [ -z "$unstaged_diff" ] && [ -z "$untracked_files" ]; then
        echo -e "\033[1;31m⚠️ No changes detected in this repository.\033[0m"
        exit 0
    fi
    
    echo -e "\033[1;33m📋 Found unstaged changes:\033[0m"
    
    if [ -n "$unstaged_diff" ]; then
        echo -e "\033[1;36mModified files:\033[0m"
        git diff --name-only | sed 's/^/  - /'
    fi
    
    if [ -n "$untracked_files" ]; then
        echo -e "\033[1;36mUntracked files:\033[0m"
        echo "$untracked_files" | sed 's/^/  - /'
    fi
    
    echo ""
    echo -e "\033[1;34mOptions:\033[0m"
    echo -e "  \033[1m(a)\033[0m Add all changes and continue"
    echo -e "  \033[1m(s)\033[0m Select files to stage interactively"
    echo -e "  \033[1m(m)\033[0m Let AI decide on multiple commits"
    echo -e "  \033[1m(q)\033[0m Quit"
    
    read -p $'\033[1;33mChoose: \033[0m' stage_choice
    
    case "$stage_choice" in
        "a")
            git add .
            echo -e "\033[1;32m✅ All changes staged.\033[0m"
            return 0
            ;;
        "s")
            git add -i
            local new_staged=$(git diff --staged)
            if [ -z "$new_staged" ]; then
                echo -e "\033[1;31m⚠️ No files were staged. Exiting.\033[0m"
                exit 0
            fi
            echo -e "\033[1;32m✅ Selected files staged.\033[0m"
            return 0
            ;;
        "m")
            return 1  # Signal for AI multi-commit mode
            ;;
        "q")
            echo -e "\033[1;31m❌ Operation cancelled.\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Please try again.\033[0m"
            check_and_stage_files
            ;;
    esac
}

# AI-powered multi-commit logic
ai_multi_commit_mode() {
    local all_changes=$(git diff HEAD)
    
    if [ -z "$all_changes" ]; then
        echo -e "\033[1;31m⚠️ No changes to analyze.\033[0m"
        exit 0
    fi
    
    echo -e "\033[1;34m🤖 AI Multi-Commit Mode\033[0m"
    echo -e "\033[1;34m────────────────────────\033[0m"
    echo -e "\033[1;33mAnalyzing all changes to suggest optimal commit groupings...\033[0m"
    
    # Enhanced prompt for AI to analyze and suggest commit strategy
    local ai_analysis_prompt="TASK: Split git changes into logical commits.

FORMAT REQUIRED (follow exactly):
STRATEGY: [one sentence]
COMMITS:
1. feat: [description]
   FILES: file1, file2
2. docs: [description]
   FILES: file3

RULES:
- Use: feat, fix, docs, style, refactor, test, chore
- Only list files that exist in the diff
- Be concise
- Follow format exactly

DIFF:
$all_changes"
    
    local ai_response=$(echo "$ai_analysis_prompt" | ollama run git-commit-fast)
    
    echo -e "\033[1;36m🧠 AI Analysis:\033[0m"
    echo "$ai_response"
    
    echo ""
    echo -e "\033[1;34mHuman-in-the-Loop Options:\033[0m"
    echo -e "  \033[1m(i)\033[0m Interactive commit-by-commit (recommended)"
    echo -e "  \033[1m(c)\033[0m Create all suggested commits automatically"
    echo -e "  \033[1m(e)\033[0m Edit AI suggestions before proceeding"
    echo -e "  \033[1m(s)\033[0m Switch to manual staging mode"
    echo -e "  \033[1m(b)\033[0m Back to file selection"
    
    read -p $'\033[1;33mChoose: \033[0m' ai_choice
    
    case "$ai_choice" in
        "i")
            interactive_commit_mode "$ai_response"
            ;;
        "c")
            auto_commit_mode "$ai_response"
            ;;
        "e")
            edit_ai_suggestions "$ai_response"
            ;;
        "s")
            echo -e "\033[1;33m📝 Manual staging mode:\033[0m"
            echo -e "Use 'git add <files>' to stage specific files, then run this script again."
            echo -e "Example: git add file1.js file2.js && ./git-commit-generator.sh"
            exit 0
            ;;
        "b")
            check_and_stage_files
            return $?
            ;;
        *)
            echo -e "\033[1;31mInvalid option.\033[0m"
            ai_multi_commit_mode
            ;;
    esac
}

# Interactive commit-by-commit mode with human oversight
interactive_commit_mode() {
    local ai_suggestions="$1"
    echo -e "\033[1;34m👤 Interactive Commit Mode\033[0m"
    echo -e "\033[1;34m─────────────────────────\033[0m"
    echo -e "\033[1;33mWe'll go through each suggested commit one by one.\033[0m"
    echo -e "\033[1;33mYou can approve, modify, or skip each suggestion.\033[0m"
    echo ""
    
    # Parse AI suggestions more robustly
    local in_commits_section=false
    local current_commit=""
    local current_files=""
    local commit_count=0
    
    while IFS= read -r line; do
        # Check if we're entering the COMMITS section
        if [[ "$line" =~ ^COMMITS: ]]; then
            in_commits_section=true
            continue
        fi
        
        # If we're in commits section, process numbered commits
        if [ "$in_commits_section" = true ]; then
            if [[ "$line" =~ ^[0-9]+\. ]]; then
                # Process previous commit if exists
                if [ -n "$current_commit" ] && [ -n "$current_files" ]; then
                    process_individual_commit "$current_commit" "$current_files" $((commit_count + 1))
                    ((commit_count++))
                fi
                
                # Start new commit
                current_commit="$line"
                current_files=""
            elif [[ "$line" =~ ^[[:space:]]*FILES: ]]; then
                current_files="$line"
            fi
        fi
    done <<< "$ai_suggestions"
    
    # Process the last commit
    if [ -n "$current_commit" ] && [ -n "$current_files" ]; then
        process_individual_commit "$current_commit" "$current_files" $((commit_count + 1))
        ((commit_count++))
    fi
    
    if [ $commit_count -eq 0 ]; then
        echo -e "\033[1;31m❌ No valid commit suggestions found in AI response.\033[0m"
        echo -e "\033[1;33mLet's try a different approach...\033[0m"
        echo ""
        echo -e "\033[1;34mOptions:\033[0m"
        echo -e "  \033[1m(a)\033[0m Add all changes and create single commit"
        echo -e "  \033[1m(s)\033[0m Manual staging mode"
        echo -e "  \033[1m(r)\033[0m Retry AI analysis"
        
        read -p $'\033[1;33mChoose: \033[0m' fallback_choice
        
        case "$fallback_choice" in
            "a")
                git add .
                return 0
                ;;
            "s")
                echo -e "\033[1;33m📝 Manual staging mode:\033[0m"
                echo -e "Use 'git add <files>' to stage specific files, then run this script again."
                exit 0
                ;;
            "r")
                ai_multi_commit_mode
                return $?
                ;;
            *)
                echo -e "\033[1;31mInvalid option. Using simple approach...\033[0m"
                simple_file_grouping
                ;;
        esac
    else
        echo -e "\033[1;32m✅ Multi-commit process completed!\033[0m"
    fi
}

# Process individual commit suggestion
process_individual_commit() {
    local commit_desc="$1"
    local files_line="$2"
    local commit_num="$3"
    
    echo -e "\033[1;36m📝 Commit $commit_num suggestion:\033[0m"
    echo -e "   $commit_desc"
    echo -e "   $files_line"
    
    echo ""
    echo -e "\033[1;34mOptions for this commit:\033[0m"
    echo -e "  \033[1m(y)\033[0m Accept and create this commit"
    echo -e "  \033[1m(m)\033[0m Modify files or message"
    echo -e "  \033[1m(s)\033[0m Skip this commit"
    echo -e "  \033[1m(q)\033[0m Quit multi-commit mode"
    
    read -p $'\033[1;33mChoose: \033[0m' commit_choice
    
    case "$commit_choice" in
        "y")
            handle_commit_creation "$commit_desc" "$files_line"
            ;;
        "m")
            modify_commit_suggestion "$commit_desc" "$files_line"
            ;;
        "s")
            echo -e "\033[1;33m⏭️  Skipping commit $commit_num\033[0m"
            ;;
        "q")
            echo -e "\033[1;31m❌ Exiting multi-commit mode\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Skipping this commit.\033[0m"
            ;;
    esac
    
    echo ""
}

# Handle creation of individual commits with human oversight
handle_commit_creation() {
    local commit_desc="$1"
    local files_line="$2"
    
    # Extract files from the FILES: line (simplified)
    local files=$(echo "$files_line" | sed 's/.*FILES: *//' | tr ',' ' ')
    
    echo -e "\033[1;33m📦 Staging files: $files\033[0m"
    
    # Reset staging area
    git reset HEAD -- . 2>/dev/null || true
    
    # Stage the suggested files
    for file in $files; do
        file=$(echo "$file" | xargs) # trim whitespace
        if [ -f "$file" ] || git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            git add "$file"
            echo -e "   ✅ Staged: $file"
        else
            echo -e "   ⚠️  File not found: $file"
        fi
    done
    
    # Check if anything was actually staged
    local staged_diff=$(git diff --staged)
    if [ -z "$staged_diff" ]; then
        echo -e "\033[1;31m❌ No files were successfully staged for this commit.\033[0m"
        return
    fi
    
    # Generate commit message for these specific changes
    echo -e "\033[1;33m🤖 Generating commit message for staged changes...\033[0m"
    local commit_message=$(echo "$staged_diff" | ollama run git-commit-fast)
    commit_message=$(echo "$commit_message" | sed '/^$/d' | head -n 1)
    
    echo -e "\033[1;32m📝 Generated message: $commit_message\033[0m"
    echo ""
    echo -e "\033[1;34mFinal confirmation:\033[0m"
    echo -e "  \033[1m(c)\033[0m Commit with this message"
    echo -e "  \033[1m(e)\033[0m Edit the message"
    echo -e "  \033[1m(s)\033[0m Skip this commit (unstage files)"
    
    read -p $'\033[1;33mChoose: \033[0m' final_choice
    
    case "$final_choice" in
        "c")
            if git commit -m "$commit_message"; then
                echo -e "\033[1;32m✅ Commit created successfully!\033[0m"
            else
                echo -e "\033[1;31m❌ Commit failed\033[0m"
            fi
            ;;
        "e")
            echo "$commit_message" > /tmp/commit_msg_edit
            ${EDITOR:-nano} /tmp/commit_msg_edit
            local edited_message=$(cat /tmp/commit_msg_edit)
            rm /tmp/commit_msg_edit
            
            if git commit -m "$edited_message"; then
                echo -e "\033[1;32m✅ Commit created with edited message!\033[0m"
            else
                echo -e "\033[1;31m❌ Commit failed\033[0m"
            fi
            ;;
        "s")
            git reset HEAD -- . 2>/dev/null || true
            echo -e "\033[1;33m⏭️  Skipped commit, files unstaged\033[0m"
            ;;
    esac
}

# Function to modify commit suggestions
modify_commit_suggestion() {
    local commit_desc="$1"
    local files_line="$2"
    
    echo -e "\033[1;33m✏️  Modify mode:\033[0m"
    echo -e "Current: $commit_desc"
    echo -e "Current: $files_line"
    echo ""
    
    # Extract current files
    local current_files=$(echo "$files_line" | sed 's/.*FILES: *//' | tr ',' ' ')
    
    echo -e "\033[1;34mWhat would you like to modify?\033[0m"
    echo -e "  \033[1m(f)\033[0m Change files to include"
    echo -e "  \033[1m(m)\033[0m Change commit message"
    echo -e "  \033[1m(b)\033[0m Both files and message"
    echo -e "  \033[1m(c)\033[0m Cancel modification"
    
    read -p $'\033[1;33mChoose: \033[0m' modify_choice
    
    case "$modify_choice" in
        "f")
            echo -e "\033[1;33mCurrent files: $current_files\033[0m"
            echo -e "\033[1;33mEnter new files (space-separated):\033[0m"
            read -r new_files
            files_line="   FILES: $new_files"
            handle_commit_creation "$commit_desc" "$files_line"
            ;;
        "b")
            echo -e "\033[1;33mCurrent files: $current_files\033[0m"
            echo -e "\033[1;33mEnter new files (space-separated):\033[0m"
            read -r new_files
            files_line="   FILES: $new_files"
            
            echo -e "\033[1;33mCurrent message: $commit_desc\033[0m"
            echo -e "\033[1;33mEnter new commit description:\033[0m"
            read -r new_desc
            commit_desc="$new_desc"
            handle_commit_creation "$commit_desc" "$files_line"
            ;;
        "m")
            echo -e "\033[1;33mCurrent message: $commit_desc\033[0m"
            echo -e "\033[1;33mEnter new commit description:\033[0m"
            read -r new_desc
            commit_desc="$new_desc"
            handle_commit_creation "$commit_desc" "$files_line"
            ;;
        "c")
            echo -e "\033[1;33m❌ Modification cancelled\033[0m"
            ;;
        *)
            echo -e "\033[1;31mInvalid option\033[0m"
            ;;
    esac
}

# Simple file-based grouping when AI format fails
simple_file_grouping() {
    echo -e "\033[1;34m📁 Simple File Grouping\033[0m"
    echo -e "\033[1;34m─────────────────────\033[0m"
    echo -e "\033[1;33mGrouping files by type for logical commits...\033[0m"
    echo ""
    
    # Get list of modified files
    local modified_files=($(git diff --name-only HEAD))
    
    # Group files by type
    local docs_files=()
    local config_files=()
    local script_files=()
    local other_files=()
    
    for file in "${modified_files[@]}"; do
        case "$file" in
            *.md|*.txt|*.rst|*.adoc)
                docs_files+=("$file")
                ;;
            Modelfile|*.json|*.yaml|*.yml|*.toml|*.ini|*.conf)
                config_files+=("$file")
                ;;
            *.sh|*.py|*.js|*.ts|*.rb|*.go)
                script_files+=("$file")
                ;;
            *)
                other_files+=("$file")
                ;;
        esac
    done
    
    # Present grouped commits
    local commit_num=1
    
    if [ ${#docs_files[@]} -gt 0 ]; then
        echo -e "\033[1;36m📝 Commit $commit_num: Documentation changes\033[0m"
        echo -e "   docs: update documentation"
        echo -e "   FILES: ${docs_files[*]}"
        echo ""
        if ask_commit_approval; then
            create_file_group_commit "docs: update documentation" "${docs_files[@]}"
        fi
        ((commit_num++))
    fi
    
    if [ ${#config_files[@]} -gt 0 ]; then
        echo -e "\033[1;36m⚙️  Commit $commit_num: Configuration changes\033[0m"
        echo -e "   chore: update configuration"
        echo -e "   FILES: ${config_files[*]}"
        echo ""
        if ask_commit_approval; then
            create_file_group_commit "chore: update configuration" "${config_files[@]}"
        fi
        ((commit_num++))
    fi
    
    if [ ${#script_files[@]} -gt 0 ]; then
        echo -e "\033[1;36m🔧 Commit $commit_num: Script changes\033[0m"
        echo -e "   feat: enhance script functionality"
        echo -e "   FILES: ${script_files[*]}"
        echo ""
        if ask_commit_approval; then
            create_file_group_commit "feat: enhance script functionality" "${script_files[@]}"
        fi
        ((commit_num++))
    fi
    
    if [ ${#other_files[@]} -gt 0 ]; then
        echo -e "\033[1;36m📦 Commit $commit_num: Other changes\033[0m"
        echo -e "   chore: update miscellaneous files"
        echo -e "   FILES: ${other_files[*]}"
        echo ""
        if ask_commit_approval; then
            create_file_group_commit "chore: update miscellaneous files" "${other_files[@]}"
        fi
    fi
    
    echo -e "\033[1;32m✅ File grouping completed!\033[0m"
}

# Helper function to ask for commit approval
ask_commit_approval() {
    echo -e "\033[1;34mCreate this commit?\033[0m"
    echo -e "  \033[1m(y)\033[0m Yes, create this commit"
    echo -e "  \033[1m(s)\033[0m Skip this group"
    
    read -p $'\033[1;33mChoose: \033[0m' approval
    
    case "$approval" in
        "y"|"Y"|"")
            return 0
            ;;
        *)
            echo -e "\033[1;33m⏭️  Skipping this group\033[0m"
            return 1
            ;;
    esac
}

# Helper function to create commits from file groups
create_file_group_commit() {
    local commit_message="$1"
    shift
    local files=("$@")
    
    # Reset staging
    git reset HEAD -- . 2>/dev/null || true
    
    # Stage the group files
    for file in "${files[@]}"; do
        if [ -f "$file" ] || git ls-files --error-unmatch "$file" >/dev/null 2>&1; then
            git add "$file"
            echo -e "   ✅ Staged: $file"
        fi
    done
    
    # Create commit
    if git commit -m "$commit_message"; then
        echo -e "\033[1;32m✅ Commit created: $commit_message\033[0m"
    else
        echo -e "\033[1;31m❌ Failed to create commit\033[0m"
    fi
    echo ""
}

# Check and handle staging
if ! check_and_stage_files; then
    ai_multi_commit_mode
fi

# Get staged diff (after potential staging)
DIFF=$(git diff --staged)

if [ -z "$DIFF" ]; then
    echo -e "\033[1;31m⚠️ No staged changes found.\033[0m"
    exit 0
fi

# Function to colorize diff output
colorize_diff() {
    while IFS= read -r line; do
        if [[ $line == "+"* ]]; then
            echo -e "\033[32m$line\033[0m"  # Green for additions
        elif [[ $line == "-"* ]]; then
            echo -e "\033[31m$line\033[0m"  # Red for deletions
        else
            echo -e "\033[90m$line\033[0m"  # Gray for context
        fi
    done <<< "$1"
}

# Function to simulate typing effect
type_effect() {
    local text="$1"
    local color="$2"
    local indent="$3"
    local delay=0.002

    text=$(echo "$text" | sed 's/\\033\[[0-9;]*m//g')
    printf "%s%s" "$indent" "$color"
    for ((i = 0; i < ${#text}; i++)); do
        printf "%s" "${text:$i:1}"
        sleep "$delay"
    done
    echo -e "\033[0m"
}

# Display diff in a box if not in only-message mode
if [ "$ONLY_MESSAGE" == "false" ]; then
    echo -e "\n\033[1;34m┌─────────────────────────────────────────────────────────────────┐\033[0m"
    echo -e "\033[1;34m│ Diff                                                            │\033[0m"
    echo -e "\033[1;34m└─────────────────────────────────────────────────────────────────┘\033[0m"
    colorize_diff "$DIFF"
    echo -e "\n\033[1;34m──────────────────────────────────────────────────────────────\033[0m"
fi

# Ask for additional context (optional)
global_context=""
request_for_context() {
    if [ "$ONLY_MESSAGE" == "false" ]; then
        echo -e "\033[1;33mProvide additional context for the commit (optional, press Enter to skip):\033[0m"
        read -r global_context
    fi
}

request_for_context

# Function to split diff into chunks
split_diff() {
    local diff_content="$1"
    local chunk=""
    chunks=()
    while IFS= read -r line; do
        if [[ "$line" =~ ^diff\ --git ]]; then
            if [ -n "$chunk" ]; then
                chunks+=("$chunk")
            fi
            chunk="$line"$'\n'
        else
            chunk+="$line"$'\n'
        fi
    done <<< "$diff_content"
    if [ -n "$chunk" ]; then
        chunks+=("$chunk")
    fi
}

# Split diff into chunks
split_diff "$DIFF"

# Variable to aggregate micro commit messages
FINAL_MICRO_MESSAGES=""

# Display header for micro commits reasoning if not in only-message mode
if [ "$ONLY_MESSAGE" == "false" ]; then
    echo -e "\n\033[1;34m──────────────────────────────────────────────────────────────\033[0m"
    echo -e "\033[1;34mAnalyzing Changes\033[0m"
    echo -e "\033[1;34m──────────────────────────────────────────────────────────────\033[0m"
fi

chunk_index=1
total_chunks=${#chunks[@]}

# Process each chunk
for chunk in "${chunks[@]}"; do
    if [ "$ONLY_MESSAGE" == "false" ]; then
        echo -e " "
    fi
    
    # Verbose output: Show chunk diff
    if [ "$VERBOSE" == "true" ]; then
        echo -e "\033[1;36mChunk $chunk_index/$total_chunks:\033[0m"
        colorize_diff "$chunk"
        echo -e "\033[1;34m----------------\033[0m"
    fi
    
    # Prepare input for Ollama with global context if provided
    if [ -n "$global_context" ]; then
        INPUT_FOR_CHUNK="Context: $global_context\n\nDiff:\n$chunk"
    else
        INPUT_FOR_CHUNK="$chunk"
    fi

    # Generate micro message for chunk
    if [ "$ONLY_MESSAGE" == "false" ]; then
        echo -e "\033[1;36mAnalyzing chunk $chunk_index/$total_chunks...\033[0m"
    fi
    
    chunk_message=$(echo -e "$INPUT_FOR_CHUNK" | ollama run git-commit-fast)

    # Verbose output: Show generated micro message
    if [ "$VERBOSE" == "true" ]; then
        echo -e "\033[1;36mGenerated Message for Chunk $chunk_index:\033[0m"
        echo -e "$chunk_message"
        echo -e "\033[1;34m----------------\033[0m"
    fi

    # Aggregate micro message for final commit
    FINAL_MICRO_MESSAGES+="$chunk_message"$'\n'

    ((chunk_index++))
done

# Variables for option control
available_options="c e g d"

display_options() {
    echo -e "\n\033[1;34mOptions:\033[0m"
    if [[ "$available_options" == *"c"* ]]; then
        echo -e "  \033[1m(c)\033[0m Commit with this message"
    fi
    if [[ "$available_options" == *"e"* ]]; then
        echo -e "  \033[1m(e)\033[0m Edit this message"
    fi
    if [[ "$available_options" == *"g"* ]]; then
        echo -e "  \033[1m(g)\033[0m Generate again with context"
    fi
    if [[ "$available_options" == *"d"* ]]; then
        echo -e "  \033[1m(d)\033[0m Discard"
    fi
    read -p $'\033[1;33mChoose: \033[0m' final_choice
}

generate_final_commit_message() {
    available_options="c e g d"
    
    # Prepare final input for Ollama
    FINAL_INPUT="Generate a single, concise git commit message based on these changes:"
    if [ -n "$global_context" ]; then
        FINAL_INPUT+="\n\nContext: $global_context"
    fi
    FINAL_INPUT+="\n\nChanges:\n$FINAL_MICRO_MESSAGES"

    if [ "$VERBOSE" == "true" ]; then
        echo -e "\033[1;36mFinal Input to Ollama:\033[0m"
        echo -e "$FINAL_INPUT"
    fi

    echo ""

    # Generate final commit message with retry mechanism
    MAX_RETRIES=3
    retry_count=0
    FINAL_COMMIT_MESSAGE=""

    while [ -z "$FINAL_COMMIT_MESSAGE" ] && [ $retry_count -lt $MAX_RETRIES ]; do
        if [ "$ONLY_MESSAGE" == "false" ] && [ $retry_count -gt 0 ]; then
            echo -e "\033[1;33mRetrying generation...\033[0m"
        fi
        
        FINAL_COMMIT_MESSAGE=$(echo -e "$FINAL_INPUT" | ollama run git-commit-fast)
        
        # Clean up the message (remove extra whitespace, empty lines)
        FINAL_COMMIT_MESSAGE=$(echo "$FINAL_COMMIT_MESSAGE" | sed '/^$/d' | head -n 1)

        if [ -z "$FINAL_COMMIT_MESSAGE" ]; then
            ((retry_count++))
            if [ $retry_count -lt $MAX_RETRIES ]; then
                sleep 1
            else
                echo -e "\033[1;31m❌ Failed to generate a commit message after $MAX_RETRIES attempts.\033[0m"
                available_options="g d"
            fi
        fi
    done

    if [ "$ONLY_MESSAGE" == "true" ]; then
        echo "$FINAL_COMMIT_MESSAGE"
        exit 0
    fi

    # Display proposed commit message
    if [ "$ONLY_MESSAGE" == "false" ] && [ -n "$FINAL_COMMIT_MESSAGE" ]; then
        echo -e "\n\033[1;34m──────────────────────────────────────────────────────────────\033[0m"
        echo -e "\033[1;34mGenerated Commit Message\033[0m"
        echo -e "\033[1;34m──────────────────────────────────────────────────────────────\033[0m"
        echo -e "\033[1;32m$FINAL_COMMIT_MESSAGE\033[0m"
    fi

    # Present options to the user
    if [ "$ONLY_MESSAGE" == "false" ]; then
        display_options
        process_choice "$final_choice"
    fi
}

process_choice() {
    local choice="$1"
    case "$choice" in
        "c")
            if [[ "$available_options" == *"c"* ]]; then
                echo -e "\033[1;33mCommitting with message:\033[0m"
                echo -e "$FINAL_COMMIT_MESSAGE"
                
                if git commit -m "$FINAL_COMMIT_MESSAGE"; then
                    echo -e "\033[1;32m✅ Commit created successfully!\033[0m"
                else
                    echo -e "\033[1;31m❌ Commit failed. Please check the errors above.\033[0m"
                    display_options
                    process_choice "$final_choice"
                fi
            else
                echo -e "\033[1;31mOption not available. Please choose from the available options.\033[0m"
                display_options
                process_choice "$final_choice"
            fi
            ;;
        "e")
            if [[ "$available_options" == *"e"* ]]; then
                echo -e "\033[1;33mOpening editor to edit the commit message...\033[0m"
                TEMP_FINAL=$(mktemp)
                echo "$FINAL_COMMIT_MESSAGE" > "$TEMP_FINAL"
                ${EDITOR:-nano} "$TEMP_FINAL"
                FINAL_COMMIT_MESSAGE=$(cat "$TEMP_FINAL")
                rm "$TEMP_FINAL"
                
                echo -e "\n\033[1;34m──────────────────────────────────────────────────────────────\033[0m"
                echo -e "\033[1;34mUpdated Commit Message\033[0m"
                echo -e "\033[1;34m──────────────────────────────────────────────────────────────\033[0m"
                echo -e "\033[1;32m$FINAL_COMMIT_MESSAGE\033[0m"
                
                display_options
                process_choice "$final_choice"
            else
                echo -e "\033[1;31mOption not available. Please choose from the available options.\033[0m"
                display_options
                process_choice "$final_choice"
            fi
            ;;
        "g")
            if [[ "$available_options" == *"g"* ]]; then
                echo -e "\033[1;33mGenerating again with additional context...\033[0m"
                request_for_context
                generate_final_commit_message
            else
                echo -e "\033[1;31mOption not available. Please choose from the available options.\033[0m"
                display_options
                process_choice "$final_choice"
            fi
            ;;
        "d")
            echo -e "\033[1;31m❌ Commit discarded.\033[0m"
            exit 0
            ;;
        *)
            echo -e "\033[1;31mInvalid option. Please choose from the available options.\033[0m"
            display_options
            process_choice "$final_choice"
            ;;
    esac
}

generate_final_commit_message
