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

# Get staged diff
DIFF=$(git diff --staged)

if [ -z "$DIFF" ]; then
    echo -e "\033[1;31m⚠️ No changes detected. Please stage your changes first.\033[0m"
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
