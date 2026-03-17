# Multi-Repo Devcontainer Template

This repository is a **template** for creating devcontainer instances. It is never opened as a devcontainer directly.

## How It Works

1. This template repo contains the `.devcontainer/` config, `repo-catalog.json` (all available repos), and `setup-instructions.md` (the creation procedure).
2. To create a new workspace instance, follow `setup-instructions.md`. Each instance is a standalone directory (`hub_1/`, `hub_2/`, ...) with its own repos, config, and Docker volumes.
3. Instances are NOT git repos — only the individual code repos inside them have `.git/`.

## Key Files

| File | Purpose |
|------|---------|
| `repo-catalog.json` | Machine-readable registry of all available repos (URLs, Python versions, descriptions) |
| `setup-instructions.md` | Step-by-step procedure for creating a new instance |
| `.devcontainer/` | Dockerfile, devcontainer.json, initialize.cmd, post-create.sh — copied to each instance |
| `docs/cross-repo-service-dependencies.md` | How repos integrate via HTTP APIs at runtime |

## Creating a New Instance

Read `setup-instructions.md` for the full procedure. Summary:

1. Determine next instance number by scanning `d:/containers/hub_*/`
2. Create directory, copy `.devcontainer/` and catalog from this template
3. Select repos, clone them, generate manifest/workspace/CLAUDE.md
4. Open in VS Code and "Reopen in Container"

## Dev Container

Before creating or modifying any devcontainer file, read `~/.claude/devcontainer-guide.md` first.
