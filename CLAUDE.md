# Multi-Repo Devcontainer Template

This repository is a **template** for creating devcontainer instances. It is never opened as a devcontainer directly.

## How It Works

1. This template repo contains the `.devcontainer/` config, `repo-catalog.json` (all available repos), and `setup-instructions.md` (the creation procedure).
2. To create a new workspace instance, follow `setup-instructions.md`. Each instance is a standalone directory (`hub_1/`, `hub_2/`, and so on) with its own repos, config, and Docker volumes.
3. Instances are not git repos; only the individual code repos inside them have `.git/`.

## Key Files

| File | Purpose |
|------|---------|
| `repo-catalog.json` | Machine-readable registry of all available repos (URLs, Python versions, descriptions) |
| `setup-instructions.md` | Step-by-step procedure for creating a new instance |
| `.devcontainer/` | Dockerfile, `devcontainer.json`, `initialize.cmd`, `post-create.sh` copied to each instance |
| `docs/cross-repo-service-dependencies.md` | How repos integrate via HTTP APIs at runtime |

## Creating a New Instance

Read `setup-instructions.md` for the full procedure. Summary:

1. Determine the next instance number by scanning `d:/containers/hub_*/`.
2. Create the directory and copy `.devcontainer/` and the catalog from this template.
3. Select repos, choose an assistant profile, clone repos, and generate manifest, workspace, and hub guardrails.
4. Open in VS Code and reopen in the container.

## Assistant Model

The multi-repo hub architecture is assistant-agnostic:

- Repo layout stays the same for Claude, Codex, or dual-assistant hubs.
- `dual` is the intended default profile for new hubs.
- `manifest.json` should record the assistant profile for the hub.
- Assistant-specific behavior belongs in generated hub docs, mounts, extensions, and post-create hooks.

At the moment, the concrete implementation is still Claude-first, so generated hub guardrails are `CLAUDE.md`. Codex support should be added as an equivalent bootstrap layer so the documented `dual` default becomes real, not as a separate hub architecture.

## Resource Limits (runArgs)

Each hub container is created with these resource constraints to prevent CPU and RAM contention when multiple hubs run simultaneously:

| Arg | Value | Purpose |
|-----|-------|---------|
| `--cpuset-cpus` | `0-7` | Pin container to cores 0-7; must not exceed WSL `processors` setting |
| `--cpus` | `8` | Cap total CPU time to 8 logical CPUs |
| `--memory` | `16g` | Hard RAM limit per container |
| `--memory-swap` | `16g` | No extra swap beyond the memory limit |
| `--memory-reservation` | `8g` | Soft reservation; Docker reclaims above this under pressure |
| `--cpu-shares` | `64` | Low relative priority so host stays responsive |

`~/.wslconfig` is set to `processors=9`; containers are pinned to cores `0-7`, leaving core `8` free for WSL and Docker host overhead. If you change `--cpuset-cpus`, update `.wslconfig` to `processors=<max_core+2>` and recreate the hub containers before reopening them.

## Dev Container

Before creating or modifying any devcontainer file, read `~/.claude/devcontainer-guide.md` first.
