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
# From any git repository - no need to pre-stage!
git commit-ai
```

**Local installation**:
```bash
# From the script directory - no need to pre-stage!
./git-commit-generator.sh
```

### Add a Shortcut (Optional)

Add this to your `~/.zshrc` or `~/.bashrc`:
```bash
alias gcai="git commit-ai"
```

Then reload and use:
```bash
gcai  # No staging required!
```

## 👤 Human-in-the-Loop Design

This tool is designed with **multiple human decision points** to ensure you maintain full control:

### 1. **Smart File Staging**
When unstaged changes are detected:
- **(a)** Add all changes and continue
- **(s)** Select files interactively
- **(m)** 🤖 Let AI suggest optimal commit splitting  
- **(q)** Quit

### 2. **AI Multi-Commit Oversight**
When AI suggests multiple commits:
- **(i)** 👤 **Interactive mode** - Review each commit individually
- **(c)** Auto-create all suggested commits
- **(e)** Edit AI suggestions before proceeding
- **(s)** Switch to manual staging mode

### 3. **Individual Commit Control** (Interactive Mode)
For each suggested commit:
- **(y)** Accept and create this commit
- **(m)** Modify files or message  
- **(s)** Skip this commit
- **(q)** Quit multi-commit mode

### 4. **Final Commit Review**
Before each commit is created:
- **(c)** Commit with generated message
- **(e)** Edit the message
- **(s)** Skip/discard this commit

**You're always in control!** 🎯

## Features

- 🤖 **AI-powered**: Uses Gemma3 4B for superior code understanding
- ⚡ **Lightning Fast**: Optimized for quick responses and smooth workflow
- 📝 **Conventional Commits**: Automatic conventional commit formatting
- 🌍 **Global Access**: Install once, use anywhere with `git commit-ai`
- 🎨 **Interactive**: Clean terminal interface with smart options
- 🔧 **Flexible**: Both global and local usage modes
- 🧠 **Smart Staging**: Automatically detects and offers to stage files
- 🔀 **Multi-Commit AI**: Let AI analyze and suggest optimal commit splitting
- 📊 **Intelligent Analysis**: Groups related changes for atomic commits

## Installation Requirements

- [Ollama](https://ollama.ai) installed and running
- Git repository (no pre-staging required!)  
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

1. **Smart Detection**: Automatically detects staged/unstaged changes
2. **Interactive Staging**: Offers to stage files with multiple options:
   - Add all changes
   - Select files interactively  
   - Let AI suggest optimal commit splitting
3. **AI Analysis**: For large changes, AI analyzes and suggests how to split into logical commits
4. **Chunk Processing**: Splits large diffs into manageable chunks for analysis
5. **Message Generation**: Creates conventional commit messages
6. **Review Options**: Commit, edit, regenerate, or discard

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
