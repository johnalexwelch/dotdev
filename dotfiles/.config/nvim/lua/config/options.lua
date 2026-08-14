-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- Scope nvim to the directory it was launched in (for herdr pane cwd respect)
vim.opt.autochdir = false -- don't auto-change; rely on LazyVim root detection
vim.g.root_spec = { "cwd" } -- use cwd as root, not .git detection
