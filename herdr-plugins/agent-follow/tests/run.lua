local failures = {}
local total = 0

local function eq(expected, actual, message)
  if not vim.deep_equal(expected, actual) then
    error(
      (message and (message .. ": ") or "")
        .. "expected "
        .. vim.inspect(expected)
        .. ", got "
        .. vim.inspect(actual),
      2
    )
  end
end

local function test(name, callback)
  total = total + 1
  local ok, err = xpcall(callback, debug.traceback)
  if ok then
    print("ok " .. total .. " - " .. name)
  else
    failures[#failures + 1] = { name = name, err = err }
    print("not ok " .. total .. " - " .. name)
  end
end

local policy = require("agent-follow.policy")

local function event(overrides)
  return vim.tbl_extend("force", { path = "/w/src/a.ts", line = 12 }, overrides or {})
end

local function editor(overrides)
  return vim.tbl_extend(
    "force",
    { mode = "n", modified = false, current_path = "/w/src/other.ts" },
    overrides or {}
  )
end

test("follows into a file when the editor is idle", function()
  eq({ action = "jump", path = "/w/src/a.ts", line = 12 }, policy.decide(event(), editor()))
end)

test("does not steal the cursor while you are typing", function()
  eq(
    { action = "skip", reason = "insert_mode" },
    policy.decide(event(), editor({ mode = "i" }))
  )
end)

test("does not abandon a buffer with unsaved changes", function()
  eq(
    { action = "skip", reason = "buffer_modified" },
    policy.decide(event(), editor({ modified = true }))
  )
end)

test("moves the cursor without reopening the file you are already in", function()
  eq(
    { action = "move_cursor", line = 12 },
    policy.decide(event(), editor({ current_path = "/w/src/a.ts" }))
  )
end)

print(("1..%d"):format(total))
if #failures > 0 then
  print("\nFailures:")
  for _, failure in ipairs(failures) do
    print(("\n%s\n%s"):format(failure.name, failure.err))
  end
  vim.cmd("cquit 1")
else
  vim.cmd("qa!")
end
