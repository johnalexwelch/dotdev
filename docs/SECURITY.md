# 🔒 Security Configuration

This guide details the security tools and configurations included in these dotfiles.

## 🛡️ Security Tools

### 🔍 Secret Detection

| Tool | Purpose | Configuration |
|------|---------|--------------|
| 🕵️ Gitleaks | Git secret scanner | `.gitleaks.toml` |
| 🔎 detect-secrets | Secrets baseline | `.secrets.baseline` |
| 🔐 git-secrets | AWS credential scanner | `.git-secrets` |

### 🔒 Git Security

```bash
# Initialize git security tools
./scripts/security-init.sh

# Run manual scan
gitleaks detect --source . --verbose
detect-secrets scan
```

## 🚨 Pre-commit Hooks

### 📝 Configuration

```yaml
# Security hooks in .pre-commit-config.yaml
- repo: https://github.com/zricethezav/gitleaks
  rev: v8.22.0
  hooks:
    - id: gitleaks

- repo: https://github.com/Yelp/detect-secrets
  rev: v1.5.0
  hooks:
    - id: detect-secrets
      args: ["--baseline", ".secrets.baseline"]
```

### 🔄 Regular Updates

```bash
# Update security tools
brew upgrade gitleaks detect-secrets git-secrets

# Update pre-commit hooks
pre-commit autoupdate
```

## 🔐 SSH Configuration

### 🔑 Key Management

```bash
# Generate new SSH key
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add to SSH agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

### 📝 SSH Config

```bash
# SSH configuration
Host *
    UseKeychain yes
    AddKeysToAgent yes
    IdentityFile ~/.ssh/id_ed25519
```

## 🔒 GPG Configuration

### 🔑 Key Setup

```bash
# Generate GPG key
gpg --full-generate-key

# List GPG keys
gpg --list-secret-keys --keyid-format LONG
```

### 🔏 Git Signing

```bash
# Configure Git to use GPG
git config --global commit.gpgsign true
git config --global user.signingkey YOUR_KEY_ID
```

## 🛡️ macOS Security

### 🔒 System Settings

```bash
# Enable FileVault
sudo fdesetup enable

# Enable Firewall
sudo /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on
```

### 🔐 Application Security

```bash
# Gatekeeper settings
sudo spctl --master-enable
sudo spctl --enable
```

## 🔍 Security Auditing

### 📊 Regular Checks

| Check | Command | Frequency |
|-------|---------|-----------|
| 🔎 Secret scan | `./scripts/scan-secrets.sh` | Pre-commit |
| 🔒 Security audit | `./scripts/security-audit.sh` | Weekly |
| 🔐 Key rotation | `./scripts/rotate-keys.sh` | Quarterly |

### 📝 Logging

```bash
# Enable security logging
sudo log config --mode "private" --subsystem "com.apple.security" --level "debug"
```

## ⚠️ Incident Response

### 🚨 If Secrets Are Exposed

1. 🔒 Revoke compromised credentials
2. 🔄 Rotate affected keys
3. 📝 Update security baseline
4. 🔍 Audit access logs

## 📚 Resources

- [🔒 Security Best Practices](https://docs.github.com/en/code-security)
- [🔑 SSH Key Guide](https://docs.github.com/authentication/connecting-to-github-with-ssh)
- [🔐 GPG Signing Guide](https://docs.github.com/authentication/managing-commit-signature-verification)
