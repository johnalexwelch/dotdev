# Zed Workspace Sync

HerdR plugin `artisann.zed-herdr` keeps the active HerdR workspace available in Zed without taking ownership of either application.

Supports macOS and Linux, HerdR **0.7.3+** using protocol **16**, Bun, Git, and Zed with its `zed` CLI available.

## Build and install

```bash
cd herdr-plugins/zed-herdr
bun install --frozen-lockfile
bun run build
herdr plugin link artisann.zed-herdr
herdr plugin enable artisann.zed-herdr
```

## Usage

The plugin activates on `workspace.created` and `workspace.focused` events. It opens/focuses Zed with the Git root of the current HerdR workspace.

### Commands

- `bun run dev` — development mode with watch
- `bun run start` — run daemon directly
- `bun dist/index.js health` — check daemon health
- `bun dist/index.js toggle` — toggle sync on/off

### Keybinding

Add to `~/.config/herdr/config.toml`:

```toml
[[keys.command]]
key = "prefix+shift+z"
type = "plugin_action"
command = "artisann.zed-herdr.toggle"
description = "Toggle Zed workspace sync"
```

Then: `herdr server reload-config`

## Configuration

- `ZED_BIN` — path to Zed CLI (defaults to `zed` on PATH, falls back to `/Applications/Zed.app/Contents/MacOS/cli` on macOS)
