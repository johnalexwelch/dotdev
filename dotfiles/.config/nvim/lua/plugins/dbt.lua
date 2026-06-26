return {
  -- sqls: SQL LSP (in Mason registry, dbt-language-server was archived)
  -- provides completion + basic intelligence for .sql files incl. dbt models
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        sqls = {
          filetypes = { "sql", "mysql" },
          root_dir = require("lspconfig.util").root_pattern(
            "dbt_project.yml",
            ".git"
          ),
          settings = {},
        },
      },
    },
  },

  -- mason: sqls + sqlfluff (sqlfluff already on PATH via pip, Mason finds it)
  {
    "williamboman/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, {
        "sqls",
        "sqlfluff",
      })
    end,
  },

  -- Jinja/dbt template syntax highlighting
  {
    "HiPhish/jinja.vim",
    ft = { "sql", "html", "jinja2", "yaml" },
  },

  -- filetype detection: treat dbt sql files as sql+jinja
  {
    "nvim-treesitter/nvim-treesitter",
    opts = function(_, opts)
      opts.ensure_installed = opts.ensure_installed or {}
      vim.list_extend(opts.ensure_installed, { "sql", "python", "jinja2" })
    end,
  },
}
