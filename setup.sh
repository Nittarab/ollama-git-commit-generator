#!/bin/bash

echo "🚀 Setting up Git Commit Generator..."

# Check if Ollama is installed
if ! command -v ollama &> /dev/null; then
    echo "❌ Ollama is not installed. Please install it first:"
    echo "   Visit: https://ollama.ai"
    exit 1
fi

echo "� Pulling base model (gemma3:4b)..."
if ollama pull gemma3:4b; then
    echo "✅ Base model downloaded successfully!"
else
    echo "❌ Failed to download base model. Please check your internet connection."
    exit 1
fi

echo "�📦 Building custom git-commit-fast model..."

# Build the custom model
if ollama create git-commit-fast -f Modelfile; then
    echo "✅ Model 'git-commit-fast' created successfully!"
else
    echo "❌ Failed to create model. Please check the Modelfile."
    exit 1
fi

echo "🔍 Testing the model..."
echo "feat: add new feature" | ollama run git-commit-fast > /dev/null

if [ $? -eq 0 ]; then
    echo "✅ Model is working correctly!"
else
    echo "⚠️  Model created but may have issues. Please test manually."
fi

# Ask user if they want global installation
echo ""
echo "� Would you like to install git-commit-fast globally? (y/n)"
echo "   This will allow you to run 'git commit-ai' from any git repository"
read -r install_global

if [[ "$install_global" =~ ^[Yy]$ ]]; then
    echo "📥 Installing globally..."
    
    # Make the script executable
    chmod +x git-commit-generator.sh
    
    # Create the global script
    sudo tee /usr/local/bin/git-commit-ai > /dev/null << 'EOF'
#!/bin/bash

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Error: Not in a git repository"
    exit 1
fi

# Check if git-commit-fast model exists
if ! ollama list | grep -q "git-commit-fast"; then
    echo "❌ Error: git-commit-fast model not found"
    echo "   Please run the setup script first"
    exit 1
fi

# Smart staging check
STAGED_DIFF=$(git diff --staged)
UNSTAGED_DIFF=$(git diff)
UNTRACKED_FILES=$(git ls-files --others --exclude-standard)

if [ -n "$STAGED_DIFF" ]; then
    echo "✅ Found staged changes ready for commit."
elif [ -z "$UNSTAGED_DIFF" ] && [ -z "$UNTRACKED_FILES" ]; then
    echo "⚠️ No changes detected in this repository."
    exit 0
else
    echo "📋 Found unstaged changes. Adding all files..."
    git add .
    STAGED_DIFF=$(git diff --staged)
    if [ -z "$STAGED_DIFF" ]; then
        echo "❌ No changes were staged."
        exit 0
    fi
    echo "✅ All changes staged."
fi

# Generate commit message
echo "🤖 Analyzing your changes..."
COMMIT_MESSAGE=$(echo "$STAGED_DIFF" | ollama run git-commit-fast)

# Clean up the message
COMMIT_MESSAGE=$(echo "$COMMIT_MESSAGE" | sed '/^$/d' | head -n 1)

if [ -z "$COMMIT_MESSAGE" ]; then
    echo "❌ Failed to generate commit message"
    exit 1
fi

echo ""
echo "📝 Generated commit message:"
echo "   $COMMIT_MESSAGE"
echo ""

# Ask user what to do
echo "Options:"
echo "  (c) Commit with this message"
echo "  (e) Edit this message"  
echo "  (s) Show message only"
echo "  (d) Discard"
read -p "Choose: " choice

case "$choice" in
    "c")
        if git commit -m "$COMMIT_MESSAGE"; then
            echo "✅ Commit created successfully!"
        else
            echo "❌ Commit failed"
            exit 1
        fi
        ;;
    "e")
        echo "$COMMIT_MESSAGE" > /tmp/commit_msg_edit
        ${EDITOR:-nano} /tmp/commit_msg_edit
        EDITED_MESSAGE=$(cat /tmp/commit_msg_edit)
        rm /tmp/commit_msg_edit
        
        if git commit -m "$EDITED_MESSAGE"; then
            echo "✅ Commit created successfully!"
        else
            echo "❌ Commit failed"
            exit 1
        fi
        ;;
    "s")
        echo "$COMMIT_MESSAGE"
        ;;
    "d")
        echo "❌ Commit discarded"
        ;;
    *)
        echo "❌ Invalid option"
        ;;
esac
EOF

    # Make the global script executable
    sudo chmod +x /usr/local/bin/git-commit-ai
    
    echo "✅ Global installation complete!"
    echo ""
    echo "🎉 You can now use 'git commit-ai' from any git repository!"
    echo ""
    echo "💡 Quick usage:"
    echo "   cd your-git-repo"
    echo "   git add ."
    echo "   git commit-ai"
    echo ""
    echo "🔧 Optional: Add an alias to your ~/.zshrc or ~/.bashrc:"
    echo "   alias gcai='git commit-ai'"
    
else
    # Make the local script executable
    chmod +x git-commit-generator.sh
    
    echo "✅ Local setup complete!"
    echo ""
    echo "🎉 You can now use:"
    echo "   ./git-commit-generator.sh"
fi

echo ""
echo "💡 Tips:"
echo "   - No need to stage files first - the script will handle it!"
echo "   - Use --help for all options (local script only)"
echo "   - The model uses Gemma3 4B for fast, accurate results"
