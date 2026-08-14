.PHONY: test test-lua test-ts typecheck lint

test: test-lua test-ts

test-lua:
	XDG_STATE_HOME=/tmp/agent-follow-state nvim --headless -u tests/minimal_init.lua -l tests/run.lua

test-ts:
	bun test

typecheck:
	bun run typecheck

lint:
	stylua --check lua tests
