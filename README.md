# Git Commit Message Generator

An intelligent git commit message generator powered by Ollama and Gemma3 4B, optimized for speed and accuracy.

## 🚀 Quick Installation

You can install the git commit generator with a simple one-line command:

```bash
curl -sSL https://raw.githubusercontent.com/your-username/ollama-scripts/main/setup.sh | bash
```

Or clone and run locally:

```bash
git clone https://github.com/your-username/ollama-scripts.git
cd ollama-scripts
./setup.sh
```

## Usage

**Global installation** (recommended):
```bash
# From any git repository
git add .
git commit-ai
```

**Local installation**:
```bash
# From the script directory
git add .
./git-commit-generator.sh
```

### Add a Shortcut (Optional)

Add this to your `~/.zshrc` or `~/.bashrc`:
```bash
alias gcai="git commit-ai"
```

Then reload and use:
```bash
gcai
```

## Features

- 🤖 **AI-powered**: Uses Gemma3 4B for superior code understanding
- ⚡ **Lightning Fast**: Optimized for quick responses and smooth workflow
- 📝 **Conventional Commits**: Automatic conventional commit formatting
- 🌍 **Global Access**: Install once, use anywhere with `git commit-ai`
- 🎨 **Interactive**: Clean terminal interface with smart options
- 🔧 **Flexible**: Both global and local usage modes

## Installation Requirements

- [Ollama](https://ollama.ai) installed and running
- Git repository with staged changes  
- Bash shell (macOS/Linux)
- Admin access for global installation (optional)

## Advanced Usage (Local Script)

The local script offers more advanced features:

```bash
./git-commit-generator.sh [options]

Options:
  --only-message    Output only the commit message (for scripts)
  --verbose         Show detailed analysis and processing steps
  -h, --help        Display help information
  --update          Update the Ollama model before running
```

### Examples

**Global quick usage**:
```bash
git add .
git commit-ai
```

**Local interactive mode**:
```bash
./git-commit-generator.sh
```

**Script/automation mode**:
```bash
commit_msg=$(./git-commit-generator.sh --only-message)
git commit -m "$commit_msg"
```

**Verbose analysis**:
```bash
./git-commit-generator.sh --verbose
```

## How It Works

1. **Analyzes** your staged git changes (`git diff --staged`)
2. **Splits** large diffs into manageable chunks
3. **Generates** micro-messages for each chunk using AI
4. **Combines** them into a cohesive final commit message
5. **Presents** options to commit, edit, regenerate, or discard

## Model Details

- **Base Model**: Gemma3 4B (latest model, excellent for code understanding)
- **Specialized**: Custom training for git commit messages
- **Format**: Conventional commits (type(scope): description)
- **Speed**: Optimized parameters for quick responses
- **Quality**: Superior reasoning and code comprehension

## Commit Message Format

The generator follows [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): description

Types:
- feat: new feature
- fix: bug fix
- docs: documentation changes
- style: formatting, missing semicolons, etc.
- refactor: code refactoring
- test: adding missing tests
- chore: maintain, dependencies, etc.
```

## Examples of Generated Messages

```
feat: add user authentication system
fix: resolve memory leak in cache manager
docs: update API documentation for v2
refactor: simplify error handling logic
test: add unit tests for validation utils
chore: update dependencies to latest versions
```

## Troubleshooting

**Model not found**:
```bash
./setup.sh  # Rebuild the model
```

**Ollama not running**:
```bash
ollama serve  # Start Ollama service
```

**No staged changes**:
```bash
git add .  # Stage your changes first
```

## Contributing

Feel free to submit issues and enhancement requests!

## License

MIT License - feel free to use and modify as needed.
