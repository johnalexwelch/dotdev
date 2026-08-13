--- Decides what the editor should do about a follow event.
---
--- Pure: takes the event and a snapshot of editor state, returns an action.
--- All the "should we move the cursor right now" judgement lives here so it can
--- be tested without touching a real buffer.

local M = {}

---@class AgentFollowEvent
---@field path string Absolute path the agent changed.
---@field line integer 1-indexed line to land on.

---@class AgentFollowEditorState
---@field mode string Result of `vim.fn.mode()`.
---@field modified boolean Whether the current buffer has unsaved changes.
---@field current_path string Absolute path of the current buffer.

---@class AgentFollowAction
---@field action "jump"|"move_cursor"|"skip"
---@field path string|nil
---@field line integer|nil
---@field reason string|nil

---@param event AgentFollowEvent
---@param state AgentFollowEditorState
---@return AgentFollowAction
function M.decide(event, state)
  if state.mode ~= "n" then
    return { action = "skip", reason = "insert_mode" }
  end
  if state.modified then
    return { action = "skip", reason = "buffer_modified" }
  end
  if state.current_path == event.path then
    return { action = "move_cursor", line = event.line }
  end
  return { action = "jump", path = event.path, line = event.line }
end

return M
