return {
  -- dadbod: database UI + completion (LazyVim sql extra brings core, we extend here)
  {
    "kristijanhusak/vim-dadbod-ui",
    keys = {
      { "<leader>D", "<cmd>DBUIToggle<cr>", desc = "Database UI" },
    },
    init = function()
      vim.g.db_ui_save_location = vim.fn.stdpath("data") .. "/dadbod"
      vim.g.db_ui_use_nerd_fonts = 1
      vim.g.db_ui_show_database_icon = 1
      vim.g.db_ui_winwidth = 35
    end,
  },

  -- completion source for SQL buffers
  {
    "hrsh7th/nvim-cmp",
    opts = function(_, opts)
      opts.sources = opts.sources or {}
      table.insert(opts.sources, { name = "vim-dadbod-completion" })
    end,
  },

  -- sqlfluff as null-ls/conform formatter
  {
    "stevearc/conform.nvim",
    opts = function(_, opts)
      opts.formatters_by_ft = opts.formatters_by_ft or {}
      opts.formatters_by_ft.sql = { "sqlfluff" }
      opts.formatters = opts.formatters or {}
      -- dbt-aware: override dialect per project if needed
      opts.formatters.sqlfluff = {
        args = { "format", "--dialect", "redshift", "-" },
      }
    end,
  },
}
