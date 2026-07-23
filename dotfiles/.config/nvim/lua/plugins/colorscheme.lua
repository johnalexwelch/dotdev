return {
  -- Kanagawa: warm, muted, low-contrast dark — matches ghostty (Kanagawa Wave),
  -- with yazi/hunk/pi inheriting the terminal for a coherent stack.
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    opts = {
      theme = "wave", -- wave (default dark) | dragon (darker/muted) | lotus (light)
      background = { dark = "wave", light = "lotus" },
      dimInactive = true, -- dim inactive splits — the multi-pane focus win
    },
  },
  -- override LazyVim default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "kanagawa",
    },
  },
}
