Start the agent team for this project.

tmux mode: Launch Claude Code with `claude --teammate-mode tmux`, then run
/orchestrate inside that session. If you skip the flag, teammates run in in-process
mode instead (use Shift+Up/Down to navigate). Verify tmux is installed first.
`teammateMode` in settings.json is not currently a recognized field — the CLI flag
is the only confirmed way to set this.

1. Verify td is available: run `command -v td`
   If not found, print: "td is not installed. Install it and ensure it's in your PATH." and stop.

2. Verify `.claude/agents.env` exists in the current project directory.
   If not found, print the following and stop:

   ```
   Missing .claude/agents.env in this project. Create one with:

   PROJECT_NAME="YourProject"
   TECH_STACK="Python, FastAPI, etc."
   TEST_COMMAND="pytest"
   BASE_BRANCH="main"
   ```

3. Read `.claude/agents.env` and parse each KEY="VALUE" line.

4. Create `td-completed-log.md` in the project root if it doesn't exist.

5. Read your system prompt from `~/.claude/prompts/orchestrator.md`.
   Substitute all {PLACEHOLDERS} with the values from step 3.

6. Begin the orchestration loop as defined in the prompt.
