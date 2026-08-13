--- Neovim side of agent-follow.
---
--- Registers this instance's RPC address so emitters can find it, then applies
--- the actions `agent-follow.policy` decides on.

local policy = require("agent-follow.policy")

local M = {}

local function registry_path()
  local workspace = vim.env.HERDR_WORKSPACE_ID
  if not workspace or workspace == "" then
    return nil
  end
  return vim.fs.joinpath(vim.fn.expand("~"), ".herdr", "nvim-servers", workspace)
end

--- Advertises this instance's server address for the current herdr workspace.
function M.register()
  local path = registry_path()
  if not path or vim.v.servername == "" then
    return
  end
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.v.servername }, path)
  vim.api.nvim_create_autocmd("VimLeavePre", {
    once = true,
    callback = function()
      pcall(vim.fn.delete, path)
    end,
  })
end

--- Snapshot of the editor state `policy.decide` needs.
local function editor_state()
  return {
    mode = vim.fn.mode(),
    modified = vim.bo.modified,
    current_path = vim.api.nvim_buf_get_name(0),
  }
end

local function apply(action)
  if action.action == "jump" then
    vim.cmd.edit(vim.fn.fnameescape(action.path))
    pcall(vim.api.nvim_win_set_cursor, 0, { action.line, 0 })
    vim.cmd("normal! zz")
  elseif action.action == "move_cursor" then
    pcall(vim.api.nvim_win_set_cursor, 0, { action.line, 0 })
  end
end

--- Entry point for emitters. Takes one JSON string so there is a single level
--- of quoting between the agent process and here.
---@param json string
function M.follow_json(json)
  local ok, event = pcall(vim.json.decode, json)
  if not ok or type(event) ~= "table" then
    return 0
  end
  vim.schedule(function()
    apply(policy.decide(event, editor_state()))
  end)
  return 1
end

function M.setup()
  M.register()
end

return M
