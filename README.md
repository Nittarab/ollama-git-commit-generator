# Git commit generator

A simple script to use a local ollama server for auto-create commits

This repo contain a scirpt `git-commit-generator` which install in your local computer a command:
 git ai-commit-generator 

 when you run this command the script will take the git status from the repo, analyse all the git diff, it will use a basic chuking tenique to split the files. 

Onnce all the full context have been pass to the AI, it generate a plan to commit the changes.

You can accept the plan, or ask for change, review the plan and procede.

You can also pass a hint to the AI:
like 

```
git ai-commit-generator "add tests"
```

TODOs
- [ ] unify setup.sh and git-commit-generator.sh
- [ ] add a one line scirpt that install the command and the git command (curl the scirpt from github)
- [ ] Create tests:
     - [ ] unite tests for the script (json AI response parse and chunking are criticals)
     - [ ] test scirpt outputs and interaction 
     - [ ] E2E tests with ollama



Note:
this is inspired by https://ollama.com/tavernari/git-commit-message