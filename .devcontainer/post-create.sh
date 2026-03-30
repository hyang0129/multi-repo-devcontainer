#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"
VENV_BASE="/workspaces/.venvs"
CATALOG="$HUB_DIR/repo-catalog.json"
MANIFEST="$HUB_DIR/manifest.json"
ASSISTANT_PROFILE="dual"

# Git identity captured by initialize.cmd
GITUSER_TMP="$SCRIPT_DIR/.gituser.tmp"
if [ -f "$GITUSER_TMP" ]; then
  GIT_NAME=$(sed -n '1p' "$GITUSER_TMP")
  GIT_EMAIL=$(sed -n '2p' "$GITUSER_TMP")
  [ -n "$GIT_NAME" ] && git config --global user.name "$GIT_NAME"
  [ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"
  rm -f "$GITUSER_TMP"
fi

# Set HUB_DIR for cross-repo integration tests
if ! grep -q 'export HUB_DIR=' ~/.bashrc 2>/dev/null; then
  echo "export HUB_DIR=\"$HUB_DIR\"" >> ~/.bashrc
fi

# Read manifest to get assistant profile and active repos
if [ ! -f "$MANIFEST" ]; then
  echo "WARNING: manifest.json not found at $MANIFEST; skipping repo setup."
  echo "post-create.sh complete (no repos configured)."
  exit 0
fi

if [ ! -f "$CATALOG" ]; then
  echo "WARNING: repo-catalog.json not found at $CATALOG; skipping repo setup."
  echo "post-create.sh complete (no catalog)."
  exit 0
fi

ASSISTANT_PROFILE=$(jq -r '.assistant_profile // "dual"' "$MANIFEST")
REPOS=$(jq -r '.repos[]' "$MANIFEST")

echo "Assistant profile: $ASSISTANT_PROFILE"

# Assistant bootstrap assets
if [ "$ASSISTANT_PROFILE" = "dual" ] || [ "$ASSISTANT_PROFILE" = "claude" ]; then
  DOT_CLAUDE="/home/vscode/.dot-claude"
  if [ -d "$DOT_CLAUDE" ]; then
    for f in CLAUDE.md settings.json; do
      ln -sf "$DOT_CLAUDE/$f" "/home/vscode/.claude/$f"
    done
    for d in commands guides; do
      rm -rf "/home/vscode/.claude/$d"
      ln -sf "$DOT_CLAUDE/$d" "/home/vscode/.claude/$d"
    done
  fi
fi

if [ "$ASSISTANT_PROFILE" = "dual" ] || [ "$ASSISTANT_PROFILE" = "codex" ]; then
  mkdir -p /home/vscode/.codex
fi

# Mark repos as git safe directories
for repo_name in $REPOS; do
  repo_dir="$HUB_DIR/$repo_name"
  if [ -d "$repo_dir/.git" ]; then
    git config --global --add safe.directory "$repo_dir"
  fi
done

# Create per-repo venvs
for repo_name in $REPOS; do
  repo_dir="$HUB_DIR/$repo_name"
  venv_path="$VENV_BASE/$repo_name"

  py=$(jq -r --arg name "$repo_name" '.repos[$name].python // empty' "$CATALOG")
  if [ -z "$py" ]; then
    echo "WARNING: $repo_name not found in repo-catalog.json; skipping."
    continue
  fi
  py="python${py}"

  [ ! -d "$repo_dir" ] && continue

  if [ -d "$venv_path" ]; then
    echo "Venv for $repo_name already exists; skipping install."
    continue
  fi

  echo "Creating venv for $repo_name with $py ..."
  "$py" -m venv "$venv_path"

  if [ -f "$repo_dir/requirements.txt" ]; then
    echo "Installing requirements for $repo_name ..."
    "$venv_path/bin/pip" install --upgrade pip
    "$venv_path/bin/pip" install -r "$repo_dir/requirements.txt"
  fi
done

# Build-cache symlink for live2d
if echo "$REPOS" | grep -q "^live2d$"; then
  BUILD_CACHE="/workspaces/build-cache"
  LIVE2D_BUILD="$HUB_DIR/live2d/build"
  if [ -d "$BUILD_CACHE" ] && [ ! -L "$LIVE2D_BUILD" ]; then
    mkdir -p "$(dirname "$LIVE2D_BUILD")"
    ln -sfn "$BUILD_CACHE" "$LIVE2D_BUILD"
    echo "Symlinked live2d/build -> $BUILD_CACHE"
  fi
fi

echo "post-create.sh complete."
