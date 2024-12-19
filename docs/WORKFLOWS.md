# Warp Workflows

Custom workflows for the Warp terminal.

## Available Workflows

### Git Operations

#### Git Feature Branch
Creates and sets up a new feature branch:
```bash
warp open git_feature
```
- Creates feature branch
- Sets upstream tracking
- Pulls latest changes

#### Git Cleanup
Maintains a clean git environment:
```bash
warp open git_cleanup
```
- Prunes remote branches
- Removes merged branches
- Shows remaining branches

### SSH Management

#### Generate SSH Key
Creates new SSH keys with proper configuration:
```bash
warp open ssh_key
```
- Service-specific naming
- Automatic agent configuration
- Keychain integration
- Config file management

### Python Development

#### Initialize Project
Sets up new Python projects with best practices:
```bash
warp open python_project
```
- Virtual environment creation
- Pre-commit hooks setup
- Project structure
- Configuration files

#### Run Tests
Executes test suite with coverage:
```bash
warp open python_test
```
- Runs pytest with coverage
- Generates HTML report
- Shows missing coverage

### AWS Tools

#### Session Setup
Configures AWS session:
```bash
warp open aws_session
```
- Profile selection
- Region configuration
- Identity verification

### Docker Development

#### Environment Setup
Creates Docker development environment:
```bash
warp open docker_dev
```
- Network creation
- Container startup
- Volume management

## Creating Custom Workflows

1. Create new YAML file in `app_configs/.warp/workflows/`
2. Follow this structure:
```yaml
name: Workflow Name
description: What the workflow does
command: |
  # Your commands here
arguments:
  - name: arg_name
    description: arg description
```