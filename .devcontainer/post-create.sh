#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
HUB_DIR="$(dirname "$SCRIPT_DIR")"
VENV_BASE="/workspaces/.venvs"

# ── Git identity (captured by initialize.cmd) ──────────────────
GITUSER_TMP="$SCRIPT_DIR/.gituser.tmp"
if [ -f "$GITUSER_TMP" ]; then
  GIT_NAME=$(sed -n '1p' "$GITUSER_TMP")
  GIT_EMAIL=$(sed -n '2p' "$GITUSER_TMP")
  [ -n "$GIT_NAME" ]  && git config --global user.name  "$GIT_NAME"
  [ -n "$GIT_EMAIL" ] && git config --global user.email "$GIT_EMAIL"
  rm -f "$GITUSER_TMP"
fi

# ── Mark all repos as git safe directories ──────────────────────
for repo_dir in "$HUB_DIR"/repos/*/; do
  [ -d "$repo_dir/.git" ] && git config --global --add safe.directory "$repo_dir"
done

# ── Per-repo venvs ──────────────────────────────────────────────
# Map each repo to the Python version it needs
declare -A REPO_PYTHON=(
  [video_agent]="python3.10"
  [live2d]="python3.11"
  [chatterbox]="python3.11"
  [HalluLens]="python3.12"
)

for repo_name in "${!REPO_PYTHON[@]}"; do
  repo_dir="$HUB_DIR/repos/$repo_name"
  venv_path="$VENV_BASE/$repo_name"
  py="${REPO_PYTHON[$repo_name]}"

  [ ! -d "$repo_dir" ] && continue

  if [ -d "$venv_path" ]; then
    echo "Venv for $repo_name already exists — skipping install."
    continue
  fi

  echo "Creating venv for $repo_name with $py ..."
  "$py" -m venv "$venv_path"

  # Install requirements if present
  if [ -f "$repo_dir/requirements.txt" ]; then
    echo "Installing requirements for $repo_name ..."
    "$venv_path/bin/pip" install --upgrade pip
    "$venv_path/bin/pip" install -r "$repo_dir/requirements.txt"
  fi
done

echo "post-create.sh complete."
