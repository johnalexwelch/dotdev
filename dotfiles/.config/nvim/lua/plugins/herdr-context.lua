-- Neovim side of the herdr-context.nvim plugin (herdr side installed via herdr-setup.sh).
-- Select code in nvim -> stage it into a live herdr agent's prompt. Only loads inside herdr.
return {
  "makyinmars/herdr-context.nvim",
  cond = vim.env.HERDR_ENV == "1",
  lazy = false, -- keeps :checkhealth herdr-context discoverable before first mapping
  opts = {},
  keys = {
    { "<leader>ac", function() require("herdr-context").compose() end, mode = { "n", "v" }, desc = "Herdr: compose context" },
    { "<leader>ay", function() require("herdr-context").reference() end, mode = { "n", "v" }, desc = "Herdr: send reference" },
    { "<leader>aY", function() require("herdr-context").send() end, mode = { "n", "v" }, desc = "Herdr: send context" },
    { "<leader>ad", function() require("herdr-context").diagnostics() end, mode = { "n", "v" }, desc = "Herdr: send diagnostics" },
    { "<leader>at", function() require("herdr-context").select_target() end, desc = "Herdr: select agent" },
    { "<leader>aa", function() require("herdr-context").agents() end, desc = "Herdr: toggle agents" },
  },
}
