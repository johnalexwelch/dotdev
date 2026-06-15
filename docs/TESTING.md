# 🧪 Testing Guide

This document outlines the testing procedures and tools used to ensure the reliability of these dotfiles.

## 🔍 Test Suite Overview

### 📋 Test Categories

| Category | Purpose | Location |
|----------|---------|----------|
| 🧾 Commit hooks | Commit message normalization | `test/test-commit-normalize.sh` |
| 🧱 tmux workflow | Terminal workspace behavior | `test/test-tmux-dev.sh` |

## 🚀 Running Tests

### 📝 Basic Test Run

```bash
# Run all tests
./test/run-tests.sh

# Run specific test category
./test/test-commit-normalize.sh
./test/test-tmux-dev.sh
```

### 🔄 Continuous Integration

```yaml
# GitHub Actions workflow
name: 🧪 Test Dotfiles
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v4
      - name: 🧪 Run tests
        run: ./test/run-tests.sh
```

## 🐛 Debugging Tests

### 🔍 Debug Mode

```bash
# Enable debug output
export DEBUG=1
./test/run-tests.sh

# Run a specific check
DEBUG=1 ./test/test-tmux-dev.sh
```

### 📝 Adding New Tests

1. Create `test/test-*.sh`
2. Add test to appropriate category
3. Update test documentation
4. Run `pre-commit run --all-files`

## 🚨 Common Issues

| Issue | Solution | Prevention |
|-------|----------|------------|
| 🐌 Slow tests | Optimize checks | Regular profiling |
| ❌ Failed security | Update baseline | Regular updates |
| 🔧 Config mismatch | Sync settings | Version control |
