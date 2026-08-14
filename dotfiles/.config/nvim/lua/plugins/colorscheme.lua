return {
  -- Ayu: matches Zed/Ghostty/herdr theme stack
  {
    "Shatur/neovim-ayu",
    priority = 1000,
    opts = {
      mirage = true, -- use mirage variant
      overrides = {
        Normal = { bg = "#252834" },
        NormalFloat = { bg = "#363943" },
        SignColumn = { bg = "#252834" },
        LineNr = { bg = "#252834" },
        -- brighter syntax
        String = { fg = "#d5ff80" },      -- bright green
        Keyword = { fg = "#ffae57" },     -- bright orange
        Function = { fg = "#73d0ff" },    -- bright blue
        Type = { fg = "#73d0ff" },        -- bright blue
        Constant = { fg = "#dfbfff" },    -- bright purple
        Number = { fg = "#dfbfff" },      -- bright purple
        Comment = { fg = "#6c7086" },     -- slightly brighter gray
        Identifier = { fg = "#cccac2" }, -- brighter text
        Special = { fg = "#95e6cb" },    -- bright cyan
        Statement = { fg = "#ffa759" },  -- bright orange
      },
    },
    config = function(_, opts)
      require("ayu").setup(opts)
    end,
  },
  -- override LazyVim default colorscheme
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "ayu-mirage",
    },
  },
}
