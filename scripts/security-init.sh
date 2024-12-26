#!/bin/bash

echo "🔒 Initializing security tools..."

# Initialize detect-secrets
echo "📝 Generating secrets baseline..."
detect-secrets scan >.secrets.baseline

# Initialize git-secrets for AWS credentials
echo "🔑 Setting up git-secrets..."
git secrets --install
git secrets --register-aws

# Initialize gitleaks
echo "🔍 Setting up gitleaks..."
gitleaks protect --staged

echo "✅ Security tools initialized!"
echo "🔍 Review .secrets.baseline for accuracy"
