# Multi-Repo Dev Container

A template for creating assistant-aware devcontainer hubs that host multiple related repositories in one VS Code window, with shared system dependencies and per-repo Python isolation.

## Available Repositories

| Repo | Language | Python | CUDA | Purpose |
|------|----------|--------|------|---------|
| [video_agent](https://github.com/hyang0129/video_agent) | Python | 3.10 | No | Multi-agent video content pipeline (LangChain + FFmpeg) |
| [live2d](https://github.com/hyang0129/live2d) | C++/Python | 3.11 | No (OpenGL/EGL) | Live2D avatar renderer with FastAPI server |
| [chatterbox](https://github.com/hyang0129/chatterbox) | Python | 3.11 | Yes (cu128) | Chatterbox Turbo TTS server (350M-param model) |
| [HalluLens](https://github.com/hyang0129/HalluLens) | Python | 3.12 | Yes (cu124) | LLM hallucination detection via activation analysis |

## Architecture

```text
d:/containers/
  multi-repo-devcontainer/          <-- This template repo
    .devcontainer/
    repo-catalog.json
    setup-instructions.md

  hub_1/                            <-- Instance 1 (generated from template)
    .devcontainer/                  <-- Copied from template, patched per-instance
    manifest.json                   <-- Active repos + assistant profile
    workspace.code-workspace        <-- Generated multi-root workspace
    CLAUDE.md                       <-- Current Claude-oriented hub guardrails
    <assistant-specific docs>       <-- Future Codex/dual-agent guardrails
    video_agent/                    <-- Cloned repo (direct child, no repos/ subdir)
    live2d/
    chatterbox/
      |
      |  Docker Desktop (--gpus all, --shm-size 8g)
      v
  Linux Container (nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04)
    /workspaces/hub_1/              <-- workspaceFolder (bind mount)
      video_agent/
      live2d/
      chatterbox/
    /workspaces/.venvs/             <-- Named Docker volume
      video_agent/    (Python 3.10)
      live2d/         (Python 3.11)
      chatterbox/     (Python 3.11)
    /home/vscode/.cache/huggingface/  <-- Named Docker volume
```

### Key Design Decisions

- **Template + Instance model**: This repo is the template; instances are stamped out from it. Instances are not git repos; only the code repos inside them have `.git/`.
- **Repos as direct children**: No `repos/` subdirectory. Shorter paths, cleaner layout.
- **Assistant integration is a hub concern**: Repo selection, venvs, ports, and service dependencies are shared across assistants. Assistant-specific mounts, extensions, and guardrail files belong in the per-hub bootstrap layer.
- **Auto-scoped volumes**: Volume names use `${localWorkspaceFolderBasename}` (for example, `hub_1-venvs`, `hub_2-venvs`). No collisions between instances.
- **Bind mount for source code**: Windows can access test artifacts via Explorer. Heavy I/O (venvs, builds, model cache) uses named volumes.

## Setup

### Prerequisites

- Windows 10/11 with Docker Desktop (WSL 2 backend)
- NVIDIA GPU + drivers installed
- Git, VS Code with Dev Containers extension

### Creating an Instance

The recommended workflow is to use an assistant to create an instance. It reads `setup-instructions.md` and `repo-catalog.json` to automate the process.

Each hub should support one of these assistant profiles:
- `dual` as the default for both assistants in the same hub, with shared repo and venv layout
- `claude` for Claude-specific mounts, extension, and hub guardrails
- `codex` for Codex-specific mounts, tooling, and hub guardrails

The intended default is now **dual-assistant hubs**. The current template implementation is still **Claude-first**, so Codex bootstrap work is still needed to fully match this default.

**Manual steps:**

```bash
# 1. Clone this template (if not already present)
git clone https://github.com/hyang0129/multi-repo-devcontainer d:/containers/multi-repo-devcontainer

# 2. Create an instance directory
mkdir d:/containers/hub_1

# 3. Copy devcontainer config
cp -r d:/containers/multi-repo-devcontainer/.devcontainer d:/containers/hub_1/
cp d:/containers/multi-repo-devcontainer/repo-catalog.json d:/containers/hub_1/
cp d:/containers/multi-repo-devcontainer/.gitattributes d:/containers/hub_1/

# 4. Clone repos you need
cd d:/containers/hub_1
git clone https://github.com/hyang0129/video_agent.git video_agent
git clone https://github.com/hyang0129/live2d.git live2d
git clone https://github.com/hyang0129/chatterbox.git chatterbox

# 5. Create manifest.json (including assistant profile)
# 6. Patch devcontainer.json workspaceFolder to /workspaces/hub_1
# 7. Generate workspace.code-workspace and hub guardrail docs
# 8. Open in VS Code -> "Dev Containers: Reopen in Container"
```

The `post-create.sh` script automatically:
- propagates your git identity from the Windows host
- reads `manifest.json` and `repo-catalog.json` to determine which repos need venvs
- creates a Python venv for each repo using the correct Python version
- installs each repo's `requirements.txt` into its venv
- marks all repos as `git safe.directory`

## Design Pillars

### 1. Single-Window Workflow

A VS Code multi-root workspace file (`workspace.code-workspace`) lists all repos as separate root folders. One Explorer sidebar, one integrated terminal per repo, one set of extensions.

### 2. Context Segregation (Assistant Layer)

A hub should carry assistant-facing guardrails that prevent unintended cross-repo edits. The same policy applies regardless of assistant:

| Layer | File | Purpose |
|-------|------|---------|
| Hub | Assistant-specific hub instructions | Enforces "ask which repo" for ambiguous prompts. Repo inventory. |
| Per-repo | Assistant-specific repo instructions | Repo-specific build commands, architecture, conventions. |

Today, the concrete implementation is a two-tier `CLAUDE.md` strategy. Codex support should be added by generating an equivalent Codex-facing instruction layer rather than by changing repo layout or dependency isolation.

### 3. Shared Dependencies, Isolated Environments

| Scope | What | Where |
|-------|------|-------|
| Shared | CUDA 12.8 + cuDNN, Python 3.10/3.11/3.12, CMake 3.28, FFmpeg | Docker image |
| Per-repo | Python packages | `/workspaces/.venvs/<repo>/` |
| Cached | HuggingFace model weights | `/home/vscode/.cache/huggingface/` |

### 4. Manifest-Driven Configuration

- `repo-catalog.json` is the full registry of available repos, including URLs, Python versions, and service dependencies
- `manifest.json` is the per-instance file declaring which repos are active and which assistant profile the hub is configured for
- `post-create.sh` reads both via `jq`; there are no hardcoded repo lists

## Named Docker Volumes

Volume names are derived from the host folder name (`${localWorkspaceFolderBasename}`), so each instance gets its own isolated volumes automatically.

| Volume pattern | Mount | Purpose |
|----------------|-------|---------|
| `<folder>-venvs` | `/workspaces/.venvs` | Per-repo Python venvs |
| `<folder>-hf-cache` | `/home/vscode/.cache/huggingface` | HuggingFace model weights |

These survive container rebuilds. To reset, delete them with `docker volume rm <name>`.

## Daily Usage

### Activate a Repo's Venv

```bash
source /workspaces/.venvs/<repo_name>/bin/activate
```

### Build live2d (C++)

```bash
cd /workspaces/hub_N/live2d
cmake --preset linux
cmake --build --preset linux
```

### Run chatterbox TTS server

```bash
source /workspaces/.venvs/chatterbox/bin/activate
cd /workspaces/hub_N/chatterbox
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

## GitHub CLI Authentication

The container forwards `GITHUB_TOKEN` from the host environment, giving `gh` access for PRs, issues, cloning, and API calls.

**One-time host setup:**

1. On the host, retrieve your token from the existing `gh` session:
   ```bash
   gh auth token
   ```
2. Add it to your host shell profile (`.bashrc`, `.zshrc`, or Windows `$PROFILE`):
   ```bash
   export GITHUB_TOKEN=<token from above>
   ```
3. Rebuild the container; `gh` will automatically detect the token

## How-To

### Adding a Repo to the Catalog

1. Add the repo entry to `repo-catalog.json` in the template.
2. If it has service dependencies, add those to the `service_dependencies` section.
3. Commit and push the template repo.

### Adding a Repo to an Existing Instance

1. Clone it with `git clone <url> <repo_name>` inside the instance directory.
2. Update `manifest.json` to include the repo name.
3. Add a `folders` entry in `workspace.code-workspace`.
4. Update the hub-level assistant guardrail docs with the new repo in the inventory.
5. Rebuild the container; the venv is auto-created from catalog plus manifest.

### Assistant Strategy

The preferred direction is a **single hub architecture** that can be provisioned for Claude, Codex, or both, with `dual` as the default. That keeps repo topology, volumes, manifests, and service dependency handling consistent.

Use separate hubs per assistant when you want stronger operational isolation:
- separate secrets or home-directory mounts
- different editor extensions or bootstrap tooling
- parallel Claude and Codex sessions against the same repo set

Use a dual-assistant hub as the normal case, and fall back to single-assistant hubs only when you want stricter isolation.

### Fast Setup - Clone Docker Volumes

If you already have a working `hub_1` with all venvs and model weights installed, you can copy those volumes instead of rebuilding from scratch:

```bash
for suffix in venvs hf-cache; do
  docker volume create hub_2-$suffix
  docker run --rm \
    -v hub_1-$suffix:/src:ro \
    -v hub_2-$suffix:/dst \
    alpine sh -c "cp -a /src/. /dst/"
done
```

## Port Conflict Strategy

Multiple instances forwarding the same port will conflict. Assign ports based on instance number:
- `hub_1`: 8000
- `hub_2`: 8001
- and so on

## Pitfalls (Windows + Docker Desktop)

These are already addressed in the config files, but are worth knowing:

- `cmd.exe` runs `initializeCommand`, so it must be a `.cmd` file rather than `.sh`
- Docker Desktop WSL root is only 135 MB, so `initialize.cmd` cleans stale VS Code Server installs
- Git checks out `.sh` with CRLF on Windows, so `.gitattributes` enforces LF to prevent `bash\r` errors
- Bind-mount performance is slower, so venvs and build artifacts use named Docker volumes instead
- `--shm-size 8g` is required by PyTorch for shared-memory data loading
- `--cpuset-cpus=0-7` pins each hub container to cores 0-7. If you change it, update `%USERPROFILE%\.wslconfig` to keep one spare core for host overhead.
- `--cpus 8` caps total CPU time to 8 logical CPUs worth
- `--memory 16g` and `--memory-reservation 8g` reduce contention when multiple hubs run simultaneously
