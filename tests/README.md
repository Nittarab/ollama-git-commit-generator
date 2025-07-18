# Unit Tests for Ollama Git Commit Generator

This directory contains comprehensive unit tests for the ollama-git-commit-generator tool. The tests focus on individual components and functions in isolation by directly testing the main `git-commit-generator.sh` script.

## Test Philosophy

- **Real Dependencies**: Tests use real `git` and `jq` commands for authentic testing
- **Mock Only Ollama**: Only the Ollama AI service is mocked to enable offline testing
- **Direct Script Testing**: Tests source the actual `git-commit-generator.sh` file, not a separate functions file
- **Single File Focus**: Maintains the goal of having one installable script file

## Test Coverage

### Core Functionality Tests (`test_core_functions.bats`) - ✅ 15/15 PASSING
- ✅ JSON extraction from markdown code fences
- ✅ JSON extraction from plain text
- ✅ Malformed JSON handling
- ✅ Complex nested JSON parsing
- ✅ Dependency checking (with real git/jq)
- ✅ File change analysis with ollama mocking
- ✅ Prompt generation
- ✅ Utility functions

### Git Diff Parsing Tests (`test_git_diff_parsing.bats`) - ⚠️ 3/9 PASSING
- ✅ Empty diff handling
- ✅ File status extraction
- ✅ Script file exclusion
- ❌ Integration tests requiring specific ollama responses (6 tests)

### Prompt Formatting Tests (`test_prompt_formatting.bats`) - ✅ 11/11 PASSING
- ✅ File summaries inclusion in prompts
- ✅ User hint integration
- ✅ Required JSON format templating
- ✅ Analysis instruction formatting
- ✅ Multiline summary handling
- ✅ Special character handling
- ✅ Empty summary handling
- ✅ Large summary handling
- ✅ Consistent formatting structure

### Input Validation Tests (`test_input_validation.bats`) - ✅ 10/11 PASSING
- ✅ Git repository validation
- ✅ Malicious file path handling
- ✅ User input sanitization
- ✅ JSON response validation
- ✅ Empty/missing file handling
- ✅ File status parameter validation
- ✅ Large file content handling
- ✅ Commit plan structure validation
- ✅ Special characters in filenames
- ⚠️ Command dependency mocking (1 test skipped - better tested manually)

### Output Formatting Tests (`test_output_formatting.bats`) - ✅ 8/10 PASSING
- ✅ Conventional commit format validation
- ✅ Commit message structure validation
- ✅ Multiple commit handling
- ✅ Status message formatting
- ✅ JSON parsing error handling
- ✅ Commit plan JSON structure validation
- ✅ File path formatting
- ❌ Integration tests requiring actual git operations (2 tests)

### Output Formatting Tests (`test_output_formatting.bats`)
- ✅ Conventional commit format validation
- ✅ Commit message structure validation
- ✅ Commit plan parsing
- ✅ File staging handling
- ✅ Multiple commit execution
- ✅ Error message formatting
- ✅ Status message clarity
- ✅ JSON parsing error handling
- ✅ File path consistency

## Testing Framework

The tests use [Bats (Bash Automated Testing System)](https://github.com/bats-core/bats-core), a TAP-compliant testing framework for Bash.

### Prerequisites

- `bash` (4.0+)
- `git`
- `jq`
- `bats` (automatically installed via setup)

### Running Tests

#### Quick Start
```bash
# Run all tests
make test

# Or use the test runner directly
./tests/run_tests.sh
```

#### Individual Test Suites
```bash
# Core functionality tests
make test-core

# Git diff parsing tests
make test-diff

# Prompt formatting tests
make test-prompt

# Input validation tests
make test-validation

# Output formatting tests
make test-output
```

#### Manual Test Execution
```bash
# Set up bats if needed
make test-setup

# Run specific test file
bats tests/test_core_functions.bats

# Run with verbose output
bats -t tests/test_core_functions.bats
```

### Test Structure

Each test file follows this structure:

```bash
#!/usr/bin/env bats

load '../test_helper'

setup() {
    # Test-specific setup
    source "${BATS_TEST_DIRNAME}/../git-commit-generator.sh"
    export TEST_TEMP_DIR=$(mktemp -d)
}

teardown() {
    # Cleanup
    rm -rf "$TEST_TEMP_DIR"
}

@test "descriptive test name" {
    # Test implementation
    run command_to_test
    [ "$status" -eq 0 ]
    [[ "$output" == *"expected"* ]]
}
```

### Test Helpers

The `test_helper.bash` file provides utility functions for:

- Setting up mock Git repositories
- Mocking external dependencies (git, jq, ollama)
- Creating test files and data
- Assertion helpers
- Test data generators

### Mocking Strategy

Tests use function mocking to isolate components:

```bash
# Mock ollama responses
function ollama() {
    echo '{"summary": "test response"}'
}
export -f ollama

# Mock git commands
function git() {
    case "$1" in
        "diff") echo "test diff content" ;;
        "add") return 0 ;;
        *) return 0 ;;
    esac
}
export -f git
```

### Test Data

Tests use realistic data patterns:

- Valid and invalid JSON responses
- Various git diff formats
- Different file types and statuses
- Edge cases and error conditions
- Security-related test cases

## Continuous Integration

The testing framework is designed to work in CI environments:

```bash
# CI-friendly test execution
make check-deps test

# Generate test coverage reports
make test-coverage
```

## Adding New Tests

1. Create test file in `tests/` directory with `.bats` extension
2. Follow naming convention: `test_[component].bats`
3. Use test helpers for common setup/teardown
4. Mock external dependencies appropriately
5. Include edge cases and error conditions
6. Update this README with new test coverage

### Test Guidelines

- **Isolation**: Each test should be independent
- **Speed**: Tests should run quickly (< 1 second each)
- **Clarity**: Test names should be descriptive
- **Coverage**: Test both success and failure paths
- **Mocking**: Mock external dependencies to avoid side effects
- **Assertions**: Use clear, specific assertions

## Troubleshooting

### Common Issues

1. **Bats not found**: Run `make test-setup` to install bats locally
2. **Permission denied**: Ensure test scripts are executable (`chmod +x`)
3. **Git errors**: Tests create temporary git repos, ensure git is configured
4. **JQ errors**: Ensure jq is installed and available in PATH

### Debug Mode

Run tests with debug output:

```bash
# Verbose output
bats -t tests/test_core_functions.bats

# With test names
bats --verbose-run tests/test_core_functions.bats
```

### Test-Specific Debugging

Add debug output to specific tests:

```bash
@test "debug test" {
    echo "Debug: $variable" >&3  # Visible with -t flag
    run command_to_test
    echo "Output: $output" >&3
    [ "$status" -eq 0 ]
}
```

## Performance

Current test performance:
- **Total tests**: ~60+ tests
- **Execution time**: < 30 seconds
- **Memory usage**: Minimal (temporary files only)
- **Dependencies**: Lightweight (bash, git, jq, bats)

## Contributing

When adding functionality to the main script:

1. Write tests first (TDD approach)
2. Ensure existing tests continue to pass
3. Add tests for new functionality
4. Update test coverage documentation
5. Follow existing test patterns and conventions