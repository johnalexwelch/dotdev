return {
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    opts = {
      flavour = "macchiato",
      integrations = {
        cmp = true,
        gitsigns = true,
        nvimtree = true,
        treesitter = true,
        telescope = { enabled = true },
        which_key = true,
        mini = { enabled = true },
        harpoon = true,
        mason = true,
        noice = true,
        notify = true,
        lsp_trouble = true,
        illuminate = { enabled = true },
      },
    },
  },
  -- override LazyVim default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "catppuccin",
    },
  },
}
