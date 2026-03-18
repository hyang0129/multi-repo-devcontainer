# Instance Setup Instructions

Step-by-step procedure for creating a new devcontainer instance from this template.

## Prerequisites

- This template repo is cloned at `d:/containers/multi-repo-devcontainer/`
- Docker Desktop is running with WSL 2 backend
- VS Code with the Dev Containers extension is installed

## Step 1: Determine Instance Number

Scan for existing hub directories:

```bash
ls -d d:/containers/hub_*/ 2>/dev/null
```

Pick the next available number (e.g., if `hub_1` and `hub_2` exist, use `hub_3`).

## Step 2: Create Instance Directory

```bash
mkdir d:/containers/hub_N
```

## Step 3: Copy Template Files

Copy the devcontainer config and catalog from the template:

```bash
cp -r d:/containers/multi-repo-devcontainer/.devcontainer d:/containers/hub_N/
cp d:/containers/multi-repo-devcontainer/repo-catalog.json d:/containers/hub_N/
cp d:/containers/multi-repo-devcontainer/.gitattributes d:/containers/hub_N/
```

## Step 4: Select Repos

Present the user with the available repos from `repo-catalog.json`:

| Repo | Python | Description |
|------|--------|-------------|
| video_agent | 3.10 | Multi-agent video content pipeline (LangChain + FFmpeg) |
| video_agent_long | 3.11 | End-to-end multi-agent pipeline for long-form YouTube videos (5–20 min, 16:9 MP4) |
| live2d | 3.11 | C++/Python Live2D avatar renderer (D3D11/OpenGL + FastAPI) |
| tts_server | 3.11 | FastAPI TTS server with unified API over multiple backends (Chatterbox Turbo, Higgs Audio v2) |
| chatterbox | 3.11 | Chatterbox Turbo TTS server (FastAPI, CUDA required) |
| HalluLens | 3.12 | LLM hallucination detection via activation analysis (vLLM, CUDA required) |

Auto-include service dependencies from `repo-catalog.json`:
- If `video_agent` is selected, also include `chatterbox` (TTS provider).
- If `video_agent_long` is selected, also include `tts_server` (TTS provider).

## Step 5: Clone Selected Repos

Clone each selected repo directly into the instance directory (no `repos/` subdirectory):

```bash
git clone <url> d:/containers/hub_N/<repo_name>
```

## Step 6: Write manifest.json

Create `d:/containers/hub_N/manifest.json`:

```json
{
  "instance_name": "hub_N",
  "repos": ["<selected_repo_1>", "<selected_repo_2>"],
  "created": "YYYY-MM-DD"
}
```

## Step 7: Patch devcontainer.json

Edit `d:/containers/hub_N/.devcontainer/devcontainer.json`:

1. Set `"workspaceFolder"` to `"/workspaces/hub_N"`
2. Set `"workspaceMount"` target to `/workspaces/hub_N`:
   ```
   "source=${localWorkspaceFolder},target=/workspaces/hub_N,type=bind,consistency=cached"
   ```
3. Set `"forwardPorts"` based on instance number: `[8000 + N - 1]`
   - hub_1: `[8000]`, hub_2: `[8001]`, hub_3: `[8002]`, etc.
4. If live2d is included, update the build-cache mount target:
   ```
   "source=${localWorkspaceFolderBasename}-build-cache,target=/workspaces/hub_N/live2d/build,type=volume"
   ```
   If live2d is NOT included, remove the build-cache mount entirely.

## Step 8: Generate workspace.code-workspace

Create `d:/containers/hub_N/workspace.code-workspace`:

```json
{
  "folders": [
    { "name": "hub", "path": "." },
    { "name": "<repo_1>", "path": "<repo_1>" },
    { "name": "<repo_2>", "path": "<repo_2>" }
  ],
  "settings": {
    "python.defaultInterpreterPath": "/workspaces/.venvs/${workspaceFolderBasename}/bin/python",
    "terminal.integrated.cwd": "${workspaceFolder}",
    "git.scanRepositories": [
      "<repo_1>",
      "<repo_2>"
    ]
  }
}
```

Add one folder entry and one `git.scanRepositories` entry per selected repo.

## Step 9: Generate CLAUDE.md

Create `d:/containers/hub_N/CLAUDE.md` using this template:

```markdown
# Multi-Repo Workspace: hub_N

## Context Segregation (MANDATORY)

This workspace contains multiple independent repos as direct subdirectories.
Each repo is a separate project with its own git history, dependencies, and purpose.

### Rules

1. **NEVER modify files in a repo other than the one the user explicitly names.**
   If the user says "add logging" without specifying which repo, you MUST ask:
   "Which repo should I modify? This workspace contains: <comma-separated repo list>."

2. **Before editing any file, confirm the repo it belongs to** by checking
   the path (<repo_name>/). State which repo you are modifying.

3. **Each repo has its own CLAUDE.md.** Before working in a repo, read
   `<repo_name>/CLAUDE.md` for repo-specific instructions.
   Those instructions take precedence for that repo's files.

4. **Do not cross-pollinate dependencies.** Each repo has its own venv at
   `/workspaces/.venvs/<repo-name>/`. Never pip-install into the system
   Python or another repo's venv.

5. **Git operations are per-repo.** Always cd into the repo directory
   before running git commands. Never run git from the hub root expecting
   it to affect a repo.

## Repo Inventory

| Repo | Path | Python | Venv | Purpose |
|------|------|--------|------|---------|
(one row per selected repo, with data from repo-catalog.json)

## Shared Dependencies

- CUDA 12.8 + cuDNN (system-level, in Docker image)
- Python 3.10, 3.11, 3.12 (all installed; venvs pin per-repo version)
- CMake 3.28, Ninja (for live2d C++ builds)
- FFmpeg (used by video_agent, live2d, chatterbox)

## Activating a Repo's Venv

source /workspaces/.venvs/<repo-name>/bin/activate

## Dev Container

Before creating or modifying any devcontainer file, read ~/.claude/devcontainer-guide.md first.
```

## Step 10: Instruct User

Tell the user:
1. Open `d:/containers/hub_N/` in VS Code
2. Use the command palette: "Dev Containers: Reopen in Container"
3. Open the workspace file when prompted: `workspace.code-workspace`

## Notes

- **Instances are NOT git repos.** Only the individual code repos have `.git/` directories. This eliminates git confusion between the hub and nested repos.
- **The template repo on GitHub is the source of truth.** To update devcontainer config, update the template and re-copy `.devcontainer/` to instances.
- **Volume names are auto-scoped** via `${localWorkspaceFolderBasename}` in mount definitions (e.g., `hub_1-venvs`, `hub_2-venvs`), so instances never collide.
