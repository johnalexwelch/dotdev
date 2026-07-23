# Python environment configuration
# shellcheck disable=SC2154  # False positive from .gitignore pattern *$py.class

# mise replaces pyenv (single binary -> 1-2 forks vs pyenv's 30+ forks per command).
# Corporate EDR adds ~250ms per fork(2), making pyenv shims unusable (~10s per command).
# See: ~/.config/starship.toml and the migration in this file.
# If a previous session/worktree cwd was deleted, recover before mise init to avoid warnings.
if [ ! -d "$PWD" ]; then
  builtin cd -- "$HOME" 2>/dev/null || builtin cd -- /
fi
if command -v mise 1>/dev/null 2>&1; then
  eval "$(mise activate zsh)"
fi

# Poetry configuration
export POETRY_VIRTUALENVS_IN_PROJECT=true
export POETRY_VIRTUALENVS_CREATE=true


# Python aliases
alias python='python3'
alias py='python'
alias pip='uv pip'
alias venv='python -m venv venv'
alias activate='source venv/bin/activate'

# UV aliases
alias uvp='uv pip'
alias uvi='uv pip install'
alias uvr='uv pip sync'
alias uvd='uv pip uninstall'
alias uvl='uv pip list'
alias uvf='uv pip freeze'


# Python development helpers
# shellcheck disable=SC2120
mkenv() {
    # Create and activate a new Python virtual environment
    # Usage: mkenv [env_name]
    # Arguments:
    #   env_name: Optional name for the virtual environment (default: venv)
    local env_name
    env_name="${1:-venv}"

    python -m venv "$env_name"
    source "$env_name/bin/activate"
}

pyinit() {
    # Initialize a new Python project
    if [ ! -f "pyproject.toml" ]; then
        echo "Creating pyproject.toml..."
        cat > pyproject.toml << EOL
[project]
name = "$(basename "$(pwd)")"
version = "0.1.0"
description = ""
authors = []
dependencies = []
requires-python = ">=3.8"

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
EOL
    fi

    if [ ! -f ".gitignore" ]; then
        echo "Creating .gitignore..."
        cat > .gitignore << EOL
# Python
__pycache__/
*.py[cod]
*$py.class
*.so
.Python
build/
develop-eggs/
dist/
downloads/
eggs/
.eggs/
lib/
lib64/
parts/
sdist/
var/
wheels/
*.egg-info/
.installed.cfg
*.egg
MANIFEST

# Virtual Environment
.env
.venv
env/
venv/
ENV/

# IDE
.idea/
.vscode/
*.swp
*.swo
EOL
    fi

    # Create virtual environment if it doesn't exist
    if [ ! -d "venv" ]; then
        echo "Creating virtual environment..."
        mkenv
    fi
}

# Python cleanup function
pyclean() {
    find . -type f -name "*.py[co]" -delete
    find . -type d -name "__pycache__" -delete
    find . -type d -name "*.egg-info" -exec rm -r {} +
    find . -type d -name "*.egg" -exec rm -r {} +
    find . -type d -name ".pytest_cache" -exec rm -r {} +
}
