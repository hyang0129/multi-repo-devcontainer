# Multi-Repo Dev Container

A single dev container hosting four related repositories in one VSCode window, with shared system dependencies (CUDA 12.8, CMake, FFmpeg) and per-repo Python isolation.

## Repositories

| Repo | Language | Python | CUDA | Purpose |
|------|----------|--------|------|---------|
| [video_agent](https://github.com/hyang0129/video_agent) | Python | 3.10 | No | Multi-agent video content pipeline (LangChain + FFmpeg) |
| [live2d](https://github.com/hyang0129/live2d) | C++/Python | 3.11 | No (OpenGL/EGL) | Live2D avatar renderer with FastAPI server |
| [chatterbox](https://github.com/hyang0129/chatterbox) | Python | 3.11 | Yes (cu128) | Chatterbox Turbo TTS server (350M-param model) |
| [HalluLens](https://github.com/hyang0129/HalluLens) | Python | 3.12 | Yes (cu124) | LLM hallucination detection via activation analysis |

## Architecture

```
Windows Host
  devcontainer1\                          ← this repo (opened by VSCode)
    repos/
      video_agent\                        ← cloned repo
      live2d\                             ← cloned repo
      chatterbox\                         ← cloned repo
      HalluLens\                          ← cloned repo
      │
      │  Docker Desktop (--gpus all, --shm-size 8g)
      ▼
Linux Container (nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04)
  /workspaces/hub/                        ← workspaceFolder
    repos/
      video_agent/                        ← visible via workspace mount
      live2d/                             ← visible via workspace mount
      chatterbox/                         ← visible via workspace mount
      HalluLens/                          ← visible via workspace mount
  /workspaces/.venvs/                     ← named Docker volume
    video_agent/    (Python 3.10)
    live2d/         (Python 3.11)
    chatterbox/     (Python 3.11)
    HalluLens/      (Python 3.12)
  /home/vscode/.cache/huggingface/        ← named Docker volume (model weights)
```

## Design Pillars

### 1. Single-Window Workflow

A VSCode **multi-root workspace** file (`workspace.code-workspace`) lists all repos as separate root folders. One Explorer sidebar, one integrated terminal per repo, one set of extensions.

### 2. Context Segregation (Claude Code)

A **two-tier CLAUDE.md** strategy prevents unintended cross-repo edits:

| Layer | File | Purpose |
|-------|------|---------|
| Hub | `CLAUDE.md` | Enforces "ask which repo" for ambiguous prompts. Repo inventory. Prohibits cross-repo edits. |
| Per-repo | `repos/<name>/CLAUDE.md` | Repo-specific build commands, architecture, conventions. |

**Key rule:** If a prompt like "add logging" doesn't specify a repo, Claude must stop and ask.

### 3. Shared Dependencies, Isolated Environments

| Scope | What | Where |
|-------|------|-------|
| Shared | CUDA 12.8 + cuDNN, Python 3.10/3.11/3.12, CMake 3.28, FFmpeg | Docker image |
| Per-repo | Python packages | `/workspaces/.venvs/<repo>/` (named volume) |
| Cached | HuggingFace model weights | `/home/vscode/.cache/huggingface/` (named volume) |

- **System Python is a venv seed only** — never `pip install` into it.
- **Venvs in a named Docker volume** — fast I/O (avoids bind-mount penalty), survives rebuilds.
- **Three Python versions** installed (3.10, 3.11, 3.12). Each venv is created with the version its repo needs.
- **CUDA is shared** — the NVIDIA base image sets `LD_LIBRARY_PATH`. PyTorch cu124 and cu128 wheels both work on the 12.8 runtime.

## Setup

### Prerequisites

- Windows 10/11 with Docker Desktop (WSL 2 backend)
- NVIDIA GPU + drivers installed
- Git

### Steps

```bash
# 1. Clone this hub repo
git clone <this-repo-url> devcontainer1
cd devcontainer1

# 2. Clone the project repos
git clone https://github.com/hyang0129/video_agent.git  repos/video_agent
git clone https://github.com/hyang0129/live2d.git        repos/live2d
git clone https://github.com/hyang0129/chatterbox.git    repos/chatterbox
git clone https://github.com/hyang0129/HalluLens.git     repos/HalluLens

# 3. Open in VSCode and reopen in container
code .
# Then: Ctrl+Shift+P → "Dev Containers: Reopen in Container"

# 4. Once inside the container, open the multi-root workspace
# File → Open Workspace from File → /workspaces/hub/workspace.code-workspace
```

The `post-create.sh` script automatically:
- Propagates your git identity from the Windows host
- Creates a Python venv for each repo (with the correct Python version)
- Installs each repo's `requirements.txt` into its venv
- Marks all repos as `git safe.directory`

## File Reference

```
devcontainer1/
  .devcontainer/
    devcontainer.json       # GPU, shm-size, named volumes, extensions
    Dockerfile              # CUDA 12.8 + Python 3.10/3.11/3.12 + CMake + Mesa/EGL + FFmpeg
    initialize.cmd          # Windows host: WSL cleanup + git identity capture
    post-create.sh          # Linux: git config, per-repo venvs, requirements install
  .gitattributes            # Line ending enforcement (*.sh → LF, *.cmd → CRLF)
  .gitignore                # Exclude .gituser.tmp and repos/
  workspace.code-workspace  # Multi-root workspace (hub + 4 repos)
  CLAUDE.md                 # Context segregation rules + repo inventory
  README.md                 # This file
  repos/                    # Cloned repositories (gitignored)
    video_agent/
    live2d/
    chatterbox/
    HalluLens/
```

## Named Docker Volumes

Volume names are derived from the host folder name (`${localWorkspaceFolderBasename}`),
so each copy of this workspace gets its own isolated volumes automatically.

| Volume pattern | Mount | Purpose |
|----------------|-------|---------|
| `<folder>-venvs` | `/workspaces/.venvs` | Per-repo Python venvs |
| `<folder>-hf-cache` | `/home/vscode/.cache/huggingface` | HuggingFace model weights (chatterbox, HalluLens) |
| `<folder>-build-cache` | `repos/live2d/build` | CMake build artifacts |

These survive container rebuilds. To reset, delete via `docker volume rm <name>`.

## Daily Usage

### Activate a repo's venv

```bash
source /workspaces/.venvs/video_agent/bin/activate    # Python 3.10
source /workspaces/.venvs/live2d/bin/activate          # Python 3.11
source /workspaces/.venvs/chatterbox/bin/activate      # Python 3.11
source /workspaces/.venvs/HalluLens/bin/activate       # Python 3.12
```

### Build live2d (C++)

```bash
cd /workspaces/hub/repos/live2d
cmake --preset linux
cmake --build --preset linux
```

### Run chatterbox TTS server

```bash
source /workspaces/.venvs/chatterbox/bin/activate
cd /workspaces/hub/repos/chatterbox
uvicorn app.main:app --host 0.0.0.0 --port 8000
```

### Run HalluLens experiments

```bash
source /workspaces/.venvs/HalluLens/bin/activate
cd /workspaces/hub/repos/HalluLens
python scripts/run_with_server.py --step all --task precisewikiqa \
  --model meta-llama/Llama-3.1-8B-Instruct --N 100
```

## How-To

### Adding a Repo

1. Clone it into `repos/`: `git clone <url> repos/<name>`
2. Add a `folders` entry in `workspace.code-workspace`
3. Add a row to the Repo Inventory in `CLAUDE.md`
4. Add a `REPO_PYTHON` entry in `post-create.sh` (maps repo name → Python version)
5. Rebuild the container — venv is auto-created

### Removing a Repo

Reverse the above. Optionally clean up: `rm -rf /workspaces/.venvs/<name>`

### Adding a Repo from a Different Host Path

For repos outside `devcontainer1/repos/`, add a bind mount in `devcontainer.json`:

```jsonc
"mounts": [
    // ... existing mounts ...
    "source=C:\\path\\to\\external-repo,target=/workspaces/hub/repos/external-repo,type=bind,consistency=cached"
]
```

Then follow the same steps as above for workspace + CLAUDE.md + post-create.sh.

## Running Multiple Copies (Parallel Claude Sessions)

You can run multiple independent dev containers from this template on the same host.
Each copy gets its own Docker container and volumes — no state is shared.

```bash
# 1. Clone a second copy with a different folder name
git clone <this-repo-url> devcontainer2
cd devcontainer2

# 2. Clone the repos you need (can be different branches)
git clone https://github.com/hyang0129/video_agent.git  repos/video_agent
git clone https://github.com/hyang0129/live2d.git        repos/live2d
git clone https://github.com/hyang0129/chatterbox.git    repos/chatterbox
git clone https://github.com/hyang0129/HalluLens.git     repos/HalluLens

# 3. Open in a new VSCode window and reopen in container
code .
# Ctrl+Shift+P → "Dev Containers: Reopen in Container"
```

**Why this works:**
- Volume names use `${localWorkspaceFolderBasename}` — so `devcontainer2` gets
  `devcontainer2-venvs`, `devcontainer2-hf-cache`, etc. No collisions.
- Each copy runs in its own Docker container with its own bind mount.
- GPU is shared (both containers can use `--gpus all`), but VRAM is first-come-first-served.

**Tips for parallel use:**
- Use different branch checkouts in each copy's `repos/` to work on separate features.
- If both containers forward the same port (e.g. 8000), change `forwardPorts` in one
  copy's `devcontainer.json`, or just use different ports inside the container.
- Each copy has its own Claude Code context — the `CLAUDE.md` in each copy is independent.

## Pitfalls (Windows + Docker Desktop)

These are already addressed in the config files, but worth knowing:

- **`cmd.exe` runs `initializeCommand`** — must be a `.cmd` file, not `.sh`.
- **Docker Desktop WSL root is only 135 MB** — `initialize.cmd` cleans stale VS Code Server installs.
- **Git checks out `.sh` with CRLF on Windows** — `.gitattributes` enforces LF to prevent `bash\r` errors.
- **Bind-mount performance** — venvs and build artifacts use named Docker volumes instead.
- **`--shm-size 8g`** — required by PyTorch for shared-memory data loading (chatterbox, HalluLens).
