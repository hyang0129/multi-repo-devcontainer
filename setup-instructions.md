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

Pick the next available number. For example, if `hub_1` and `hub_2` exist, use `hub_3`.

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
| video_agent_long | 3.11 | End-to-end multi-agent pipeline for long-form YouTube videos (5-20 min, 16:9 MP4) |
| live2d | 3.11 | C++/Python Live2D avatar renderer (D3D11/OpenGL + FastAPI) |
| tts_server | 3.11 | FastAPI TTS server with unified API over multiple backends (Chatterbox Turbo, Higgs Audio v2) |
| chatterbox | 3.11 | Chatterbox Turbo TTS server (FastAPI, CUDA required) |
| HalluLens | 3.12 | LLM hallucination detection via activation analysis (vLLM, CUDA required) |

Auto-include service dependencies from `repo-catalog.json`:
- If `video_agent` is selected, also include `chatterbox`.
- If `video_agent_long` is selected, also include `tts_server`.

## Step 5: Clone Selected Repos

Clone each selected repo directly into the instance directory. Do not create a `repos/` subdirectory.

```bash
git clone <url> d:/containers/hub_N/<repo_name>
```

## Step 6: Write manifest.json

Create `d:/containers/hub_N/manifest.json`:

```json
{
  "instance_name": "hub_N",
  "assistant_profile": "dual",
  "repos": ["<selected_repo_1>", "<selected_repo_2>"],
  "created": "YYYY-MM-DD"
}
```

Assistant profile guidance:
- `dual` is the default and represents the intended shared hub with both assistants available
- `claude` is a single-assistant option when you want Claude-specific isolation
- `codex` is a single-assistant option when you want Codex-specific isolation

The multi-repo layout does not change by assistant. Only the assistant-facing bootstrap layer should vary.

## Step 7: Patch devcontainer.json

Edit `d:/containers/hub_N/.devcontainer/devcontainer.json`:

1. Set `"workspaceFolder"` to `"/workspaces/hub_N"`.
2. Set `"workspaceMount"` target to `/workspaces/hub_N`:
   ```
   "source=${localWorkspaceFolder},target=/workspaces/hub_N,type=bind,consistency=cached"
   ```
3. Set `"forwardPorts"` based on instance number: `[8000 + N - 1]`.
   - hub_1: `[8000]`
   - hub_2: `[8001]`
   - hub_3: `[8002]`
4. If `live2d` is included, update the build-cache mount target:
   ```
   "source=${localWorkspaceFolderBasename}-build-cache,target=/workspaces/hub_N/live2d/build,type=volume"
   ```
   If `live2d` is not included, remove the build-cache mount entirely.
5. Keep assistant-specific mounts and extensions in the bootstrap layer. Do not change repo layout or venv layout per assistant.

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

## Step 9: Generate Hub Guardrail Docs

Generate assistant-facing hub instructions for the selected profile.

The generation model is:
- `dual` hubs generate both Claude-facing and Codex-facing hub instructions
- `claude` hubs generate `CLAUDE.md`
- `codex` hubs generate Codex-facing hub instructions with the same cross-repo safety rules

For `dual` and `claude`, create `d:/containers/hub_N/CLAUDE.md` using this template:

```markdown
# Multi-Repo Workspace: hub_N

## Context Segregation (MANDATORY)

This workspace contains multiple independent repos as direct subdirectories.
Each repo is a separate project with its own git history, dependencies, and purpose.

### Rules

1. **Never modify files in a repo other than the one the user explicitly names.**
   If the user says "add logging" without specifying which repo, ask:
   "Which repo should I modify? This workspace contains: <comma-separated repo list>."

2. **Before editing any file, confirm the repo it belongs to** by checking
   the path (`<repo_name>/`). State which repo you are modifying.

3. **Each repo has its own assistant-facing repo instructions.**
   For the current template, read `<repo_name>/CLAUDE.md` before working in a repo.
   Those instructions take precedence for that repo's files.

4. **Do not cross-pollinate dependencies.** Each repo has its own venv at
   `/workspaces/.venvs/<repo-name>/`. Never install into the system Python
   or another repo's venv.

5. **Git operations are per-repo.** Always `cd` into the repo directory
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

For `dual` and `codex`, create `d:/containers/hub_N/AGENTS.md` with the same cross-repo safety rules, adapted for Codex-facing instructions:

```markdown
# Multi-Repo Workspace: hub_N

## Context Segregation (MANDATORY)

This workspace contains multiple independent repos as direct subdirectories.
Each repo is a separate project with its own git history, dependencies, and purpose.

### Rules

1. Never modify files in a repo other than the one the user explicitly names.
   If the user gives an ambiguous request, ask which repo should be modified.

2. Before editing any file, confirm the repo it belongs to by checking the
   path (`<repo_name>/`). State which repo you are modifying.

3. Each repo has its own repo-level instructions.
   Read `<repo_name>/AGENTS.md` when present, and otherwise check the repo's
   assistant-facing instructions before changing files there.

4. Do not cross-pollinate dependencies. Each repo has its own venv at
   `/workspaces/.venvs/<repo-name>/`. Never install into the system Python
   or another repo's venv.

5. Git operations are per-repo. Always run git commands from the intended repo,
   not from the hub root.

## Repo Inventory

| Repo | Path | Python | Venv | Purpose |
|------|------|--------|------|---------|
(one row per selected repo, with data from repo-catalog.json)

## Shared Dependencies

- CUDA 12.8 + cuDNN (system-level, in Docker image)
- Python 3.10, 3.11, 3.12 (all installed; venvs pin per-repo version)
- CMake 3.28, Ninja (for live2d C++ builds)
- FFmpeg

## Activating a Repo's Venv

source /workspaces/.venvs/<repo-name>/bin/activate
```

## Step 10: Instruct User

Tell the user:
1. Open `d:/containers/hub_N/` in VS Code.
2. Use the command palette: `Dev Containers: Reopen in Container`.
3. Open the workspace file when prompted: `workspace.code-workspace`.

## Notes

- **Instances are not git repos.** Only the individual code repos have `.git/` directories.
- **The template repo on GitHub is the source of truth.** To update devcontainer config, update the template and re-copy `.devcontainer/` to instances.
- **Volume names are auto-scoped** via `${localWorkspaceFolderBasename}`, so instances never collide.
- **Assistant support should stay pluggable.** `dual` should be the default hub profile. Only use separate Claude-versus-Codex layouts when you specifically want runtime isolation between assistants.
- **The checked-in devcontainer is the `dual` bootstrap.** For `claude` or `codex` hubs, remove only the assistant-specific mounts, extensions, and generated guardrail docs that do not apply.
