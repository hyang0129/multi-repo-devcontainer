# Assistant Profiles

This template supports three assistant profiles for generated hubs.

## Profiles

### `dual`

Use when both Claude and Codex should be available in the same hub.

Generated hub assets:

- `CLAUDE.md`
- `AGENTS.md`

Bootstrap expectations:

- mount `~/.claude`
- mount `~/.codex`
- optionally mount a shared `dot-claude` repo when used by your Claude setup
- install both the Claude and ChatGPT/Codex-related VS Code extensions

### `claude`

Use when the hub should be Claude-focused but still keep the same repo and venv layout.

Generated hub assets:

- `CLAUDE.md`

Bootstrap expectations:

- mount `~/.claude`
- optionally mount `dot-claude`
- install the Claude extension
- omit Codex-specific mounts and docs unless you intentionally want them available

### `codex`

Use when the hub should be Codex-focused but still keep the same repo and venv layout.

Generated hub assets:

- `AGENTS.md`

Bootstrap expectations:

- mount `~/.codex`
- install the ChatGPT/Codex-related VS Code extension
- omit Claude-specific mounts and docs unless you intentionally want them available

## Shared Invariants

These stay the same for all assistant profiles:

- repos are direct children of the hub directory
- `manifest.json` declares active repos and `assistant_profile`
- per-repo venvs live under `/workspaces/.venvs/<repo>`
- service dependencies come from `repo-catalog.json`
- generated workspace files stay multi-root and repo-oriented

## Current Template Default

The checked-in `.devcontainer/devcontainer.json` is the default `dual` bootstrap.
If you stamp a `claude` or `codex` hub, keep the same base template and remove only the assistant-specific mounts, docs, and extensions that do not apply.
