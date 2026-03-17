# Multi-Repo Dev Container

A template for creating devcontainer instances that host multiple related repositories in one VS Code window, with shared system dependencies (CUDA 12.8, CMake, FFmpeg) and per-repo Python isolation.

## Available Repositories

| Repo | Language | Python | CUDA | Purpose |
|------|----------|--------|------|---------|
| [video_agent](https://github.com/hyang0129/video_agent) | Python | 3.10 | No | Multi-agent video content pipeline (LangChain + FFmpeg) |
| [live2d](https://github.com/hyang0129/live2d) | C++/Python | 3.11 | No (OpenGL/EGL) | Live2D avatar renderer with FastAPI server |
| [chatterbox](https://github.com/hyang0129/chatterbox) | Python | 3.11 | Yes (cu128) | Chatterbox Turbo TTS server (350M-param model) |
| [HalluLens](https://github.com/hyang0129/HalluLens) | Python | 3.12 | Yes (cu124) | LLM hallucination detection via activation analysis |

## Architecture

```
d:/containers/
  multi-repo-devcontainer/          <-- This template repo (on GitHub)
    .devcontainer/
    repo-catalog.json
    setup-instructions.md

  hub_1/                            <-- Instance 1 (generated from template)
    .devcontainer/                  <-- Copied from template, patched per-instance
    manifest.json                   <-- Which repos are active
    workspace.code-workspace        <-- Generated multi-root workspace
    CLAUDE.md                       <-- Generated context segregation rules
    video_agent/                    <-- Cloned repo (direct child, no repos/ subdir)
    live2d/
    chatterbox/
      │
      │  Docker Desktop (--gpus all, --shm-size 8g)
      ▼
  Linux Container (nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04)
    /workspaces/hub_1/              <-- workspaceFolder (bind mount)
      video_agent/
      live2d/
      chatterbox/
    /workspaces/.venvs/             <-- Named Docker volume
      video_agent/    (Python 3.10)
      live2d/         (Python 3.11)
      chatterbox/     (Python 3.11)
    /home/vscode/.cache/huggingface/  <-- Named Docker volume (model weights)

  hub_2/                            <-- Instance 2 (different repo selection)
    .devcontainer/
    manifest.json
    HalluLens/
    video_agent/
```

### Key Design Decisions

- **Template + Instance model**: This repo is the template; instances are stamped out from it. Instances are NOT git repos — only the code repos inside them have `.git/`.
- **Repos as direct children**: No `repos/` subdirectory. Shorter paths, cleaner layout.
- **Auto-scoped volumes**: Volume names use `${localWorkspaceFolderBasename}` (e.g., `hub_1-venvs`, `hub_2-venvs`). No collisions between instances.
- **Bind mount for source code**: Windows can access test artifacts (video, audio, images) via Explorer. Heavy I/O (venvs, builds, model cache) uses named volumes.

## Setup

### Prerequisites

- Windows 10/11 with Docker Desktop (WSL 2 backend)
- NVIDIA GPU + drivers installed
- Git, VS Code with Dev Containers extension

### Creating an Instance

The recommended workflow is to ask Claude Code to create an instance — it reads `setup-instructions.md` and `repo-catalog.json` to automate the process.

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

# 5. Create manifest.json (see setup-instructions.md for format)
# 6. Patch devcontainer.json workspaceFolder to /workspaces/hub_1
# 7. Generate workspace.code-workspace and CLAUDE.md
# 8. Open in VS Code → "Dev Containers: Reopen in Container"
```

The `post-create.sh` script automatically:
- Propagates your git identity from the Windows host
- Reads `manifest.json` + `repo-catalog.json` to determine which repos need venvs
- Creates a Python venv for each repo (with the correct Python version)
- Installs each repo's `requirements.txt` into its venv
- Marks all repos as `git safe.directory`

## Design Pillars

### 1. Single-Window Workflow

A VS Code **multi-root workspace** file (`workspace.code-workspace`) lists all repos as separate root folders. One Explorer sidebar, one integrated terminal per repo, one set of extensions.

### 2. Context Segregation (Claude Code)

A **two-tier CLAUDE.md** strategy prevents unintended cross-repo edits:

| Layer | File | Purpose |
|-------|------|---------|
| Hub | `CLAUDE.md` (per-instance) | Enforces "ask which repo" for ambiguous prompts. Repo inventory. |
| Per-repo | `<repo>/CLAUDE.md` | Repo-specific build commands, architecture, conventions. |

### 3. Shared Dependencies, Isolated Environments

| Scope | What | Where |
|-------|------|-------|
| Shared | CUDA 12.8 + cuDNN, Python 3.10/3.11/3.12, CMake 3.28, FFmpeg | Docker image |
| Per-repo | Python packages | `/workspaces/.venvs/<repo>/` (named volume) |
| Cached | HuggingFace model weights | `/home/vscode/.cache/huggingface/` (named volume) |

### 4. Manifest-Driven Configuration

- `repo-catalog.json` — the full registry of available repos (URLs, Python versions, service dependencies)
- `manifest.json` — per-instance file declaring which repos are active
- `post-create.sh` reads both via `jq` — no hardcoded repo lists

## Named Docker Volumes

Volume names are derived from the host folder name (`${localWorkspaceFolderBasename}`),
so each instance gets its own isolated volumes automatically.

| Volume pattern | Mount | Purpose |
|----------------|-------|---------|
| `<folder>-venvs` | `/workspaces/.venvs` | Per-repo Python venvs |
| `<folder>-hf-cache` | `/home/vscode/.cache/huggingface` | HuggingFace model weights |

These survive container rebuilds. To reset, delete via `docker volume rm <name>`.

## Daily Usage

### Activate a repo's venv

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
3. Rebuild the container — `gh` will automatically detect the token

## How-To

### Adding a Repo to the Catalog

1. Add the repo entry to `repo-catalog.json` in the template
2. If it has service dependencies, add those to the `service_dependencies` section
3. Commit and push the template repo

### Adding a Repo to an Existing Instance

1. Clone it: `git clone <url> <repo_name>` (inside the instance directory)
2. Update `manifest.json` to include the repo name
3. Add a `folders` entry in `workspace.code-workspace`
4. Add a row to the Repo Inventory in `CLAUDE.md`
5. Rebuild the container — venv is auto-created from catalog + manifest

### Fast Setup — Clone Docker Volumes

If you already have a working `hub_1` with all venvs and model weights installed,
you can copy those volumes instead of rebuilding from scratch:

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
- etc.

## Pitfalls (Windows + Docker Desktop)

These are already addressed in the config files, but worth knowing:

- **`cmd.exe` runs `initializeCommand`** — must be a `.cmd` file, not `.sh`.
- **Docker Desktop WSL root is only 135 MB** — `initialize.cmd` cleans stale VS Code Server installs.
- **Git checks out `.sh` with CRLF on Windows** — `.gitattributes` enforces LF to prevent `bash\r` errors.
- **Bind-mount performance** — venvs and build artifacts use named Docker volumes instead.
- **`--shm-size 8g`** — required by PyTorch for shared-memory data loading (chatterbox, HalluLens).
