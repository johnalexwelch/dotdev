# 🧪 Testing Guide

This document outlines the testing procedures and tools used to ensure the reliability of these dotfiles.

## 🔍 Test Suite Overview

### 📋 Test Categories

| Category | Purpose | Location |
|----------|---------|----------|
| 🛠️ Installation | Verify setup process | `scripts/test-install.sh` |
| ⚙️ Configuration | Check settings | `scripts/test-config.sh` |
| 🔒 Security | Validate security tools | `scripts/test-security.sh` |
| 🐚 Shell | Test shell functions | `scripts/test-shell.sh` |

## 🚀 Running Tests

### 📝 Basic Test Run

```bash
# Run all tests
./scripts/test.sh

# Run specific test category
./scripts/test-install.sh
./scripts/test-config.sh
./scripts/test-security.sh
./scripts/test-shell.sh
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
        run: ./scripts/test.sh
```

## 📊 Test Coverage

### 🎯 Core Components

| Component | Tests | Coverage |
|-----------|-------|----------|
| 📥 Installation | 15 | 100% |
| ⚙️ Configuration | 25 | 95% |
| 🔒 Security | 10 | 100% |
| 🐚 Shell | 20 | 90% |

### 🔍 Test Types

1. 🛠️ Unit Tests
   - Shell function testing
   - Configuration validation
   - Tool availability checks

2. 🔄 Integration Tests
   - Full installation simulation
   - Cross-tool interactions
   - Security tool integration

3. 🎭 End-to-End Tests
   - Complete setup process
   - User workflow scenarios
   - System integration

## 🐛 Debugging Tests

### 🔍 Debug Mode

```bash
# Enable debug output
export DEBUG=1
./scripts/test.sh

# Run specific test with debugging
DEBUG=1 ./scripts/test-config.sh
```

### 📝 Logging

```bash
# View test logs
cat logs/test.log

# Watch logs in real-time
tail -f logs/test.log
```

## 🔧 Test Maintenance

### 🔄 Regular Updates

```bash
# Update test dependencies
./scripts/update-tests.sh

# Verify test integrity
./scripts/verify-tests.sh
```

### 📝 Adding New Tests

1. Create test file in `tests/` directory
2. Add test to appropriate category
3. Update test documentation
4. Verify coverage

## 🚨 Common Issues

| Issue | Solution | Prevention |
|-------|----------|------------|
| 🐌 Slow tests | Optimize checks | Regular profiling |
| ❌ Failed security | Update baseline | Regular updates |
| 🔧 Config mismatch | Sync settings | Version control |

## 📊 Performance Metrics

### ⏱️ Execution Time

| Test Suite | Average Time | Threshold |
|------------|--------------|-----------|
| 🛠️ Installation | 2 min | 5 min |
| ⚙️ Configuration | 30 sec | 1 min |
| 🔒 Security | 1 min | 2 min |
| 🐚 Shell | 15 sec | 30 sec |

## 📈 Quality Metrics

### 🎯 Test Goals

- 💯 100% installation success rate
- ⚡ < 5 minute total test time
- 🎯 95%+ test coverage
- 0️⃣ security vulnerabilities

## 📚 Resources

- [🧪 Testing Best Practices](../wiki/Testing.md)
- [📊 Coverage Reports](../reports/coverage)
- [📝 Test Documentation](../tests/README.md)
