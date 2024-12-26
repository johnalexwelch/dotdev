# 🍎 macOS Configuration

## ⚙️ System Preferences

### 🎯 Dock

- Position: Bottom
- Size: 36 pixels
- Magnification: Enabled (128 pixels)
- Minimize effect: Scale
- Auto-hide: Enabled
- Show indicators for open apps: Yes
- Show recent applications: No

### 🔍 Finder

- Default view: List
- Show all filename extensions
- Show hidden files
- Keep folders on top
- Search current folder by default
- Show path bar and status bar
- New window opens: Home directory

### 🔒 Security

- FileVault: Enabled
- Firewall: Enabled with stealth mode
- Automatic updates: Security only
- Gatekeeper: App Store and identified developers
- Privacy permissions: Managed per application

### ⌨️ Input

- Key repeat rate: Fast (level 2)
- Delay until repeat: Short (level 15)
- Tap to click: Enabled
- Three finger drag: Enabled
- Natural scrolling: Enabled
- Smart quotes: Disabled
- Auto-correct: Disabled

## 🔍 Spotlight

### 🎯 Search Configuration

- Excluded locations:
  - `/node_modules`
  - `/.git`
  - `/Library`
  - `/System`
- Priority folders:
  - Documents
  - Applications
  - Developer
- Search categories:
  - Applications
  - Documents
  - Folders
  - Developer
  - System Settings

## 📸 Screenshots

### 📝 Settings

- Save location: `~/Pictures/Screenshots`
- File format: PNG
- Include date in filename
- Disable shadow effect
- Show thumbnail: Yes
- Default name format: `Screenshot {date} at {time}`

### ⌨️ Shortcuts

- Full screen: `Shift + Cmd + 3`
- Selected portion: `Shift + Cmd + 4`
- Window capture: `Shift + Cmd + 4 + Space`
- Copy to clipboard: Add `Control` to any above

## 🖥️ Terminal

### 🔧 Integration

- Default shell: zsh
- SSH key management: 1Password
- Git credentials: Git Credential Manager
- Environment setup: `.zshrc` and `.zshenv`

### 🎨 Theme

- Font: JetBrains Mono
- Theme: Dracula
- Opacity: 95%
- Blur: Enabled
