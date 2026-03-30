# Multi-Repo Devcontainer Template

This repository is a template for creating multi-repo devcontainer hubs.
It is not itself a generated hub instance.

## Scope

Only modify template files in this repository:

- `.devcontainer/`
- `repo-catalog.json`
- `setup-instructions.md`
- `README.md`
- `docs/`
- assistant-facing template docs such as `CLAUDE.md` and `AGENTS.md`

Do not treat `hub_N` directories outside this repo as part of this repository.

## Assistant Profiles

The template supports three hub profiles:

- `dual`: default profile, with both Claude-facing and Codex-facing bootstrap
- `claude`: Claude-focused bootstrap while keeping the same repo layout
- `codex`: Codex-focused bootstrap while keeping the same repo layout

Profile differences should stay in:

- assistant-facing hub docs
- editor extensions
- mounted assistant home/config directories
- small post-create bootstrap actions

Profile differences should not change:

- repo topology
- manifest structure
- per-repo venv layout
- shared system dependencies
- service-dependency handling

## Guardrails

When updating the template:

1. Keep the generated hub model consistent across `README.md`, `setup-instructions.md`, and `.devcontainer/`.
2. Prefer a concrete default over aspirational language.
3. Keep `dual` as the default profile unless there is a strong reason not to.
4. Avoid introducing assistant-specific behavior into repo layout or dependency isolation.
