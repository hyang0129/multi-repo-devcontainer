# Multi-Repo Workspace Rules

## Context Segregation (MANDATORY)

This workspace contains multiple independent repos under `repos/`.
Each repo is a separate project with its own git history, dependencies, and purpose.

### Rules

1. **NEVER modify files in a repo other than the one the user explicitly names.**
   If the user says "add logging" without specifying which repo, you MUST ask:
   "Which repo should I modify? This workspace contains: video_agent, live2d, chatterbox, HalluLens."

2. **Before editing any file, confirm the repo it belongs to** by checking
   the path (repos/<name>/). State which repo you are modifying.

3. **Each repo has its own CLAUDE.md.** Before working in a repo, read
   `repos/<repo-name>/CLAUDE.md` for repo-specific instructions.
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
| video_agent | repos/video_agent | 3.10 | /workspaces/.venvs/video_agent | Multi-agent video content pipeline (LangChain + FFmpeg) |
| live2d | repos/live2d | 3.11 | /workspaces/.venvs/live2d | C++/Python Live2D avatar renderer (D3D11/OpenGL + FastAPI) |
| chatterbox | repos/chatterbox | 3.11 | /workspaces/.venvs/chatterbox | Chatterbox Turbo TTS server (FastAPI, CUDA required) |
| HalluLens | repos/HalluLens | 3.12 | /workspaces/.venvs/HalluLens | LLM hallucination detection via activation analysis (vLLM, CUDA required) |

## Shared Dependencies

- CUDA 12.8 + cuDNN (system-level, in Docker image)
- Python 3.10, 3.11, 3.12 (all installed; venvs pin per-repo version)
- CMake 3.28, Ninja (for live2d C++ builds)
- FFmpeg (used by video_agent, live2d, chatterbox)

## Activating a Repo's Venv

```bash
source /workspaces/.venvs/<repo-name>/bin/activate
```

## Dev Container

Before creating or modifying any devcontainer file, read `~/.claude/devcontainer-guide.md` first.
