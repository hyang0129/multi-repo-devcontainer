# syntax=docker/dockerfile:1
FROM nvidia/cuda:12.8.1-cudnn-devel-ubuntu22.04

# ── Python versions needed by each repo ─────────────────────────
# video_agent → 3.10 | chatterbox → 3.11 | HalluLens → 3.12
ARG CMAKE_VERSION=3.28.3

ENV DEBIAN_FRONTEND=noninteractive

# ── System packages ─────────────────────────────────────────────
# Covers all four repos:
#   ffmpeg          → video_agent, live2d, chatterbox
#   Mesa/EGL/GLX    → live2d (headless OpenGL rendering)
#   ninja-build     → live2d (CMake generator)
#   libsndfile1     → chatterbox (WAV I/O)
#   liblmdb-dev     → HalluLens (activation logging)
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    apt-get update && apt-get -y install --no-install-recommends \
        software-properties-common \
        curl wget git build-essential pkg-config \
        ca-certificates sudo openssh-client \
        # Video / audio
        ffmpeg libavcodec-dev libavformat-dev libavutil-dev libswscale-dev \
        libsndfile1 libsndfile1-dev \
        # OpenGL / EGL (live2d headless rendering)
        libgl1-mesa-dev libegl1-mesa-dev libgles2-mesa-dev mesa-utils \
        libglew-dev libglfw3-dev \
        libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev \
        # Build tools
        ninja-build \
        # Storage (HalluLens)
        liblmdb-dev \
        # Misc
        libffi-dev libssl-dev unzip jq

# ── Python 3.10, 3.11, 3.12 via deadsnakes ─────────────────────
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt/lists,sharing=locked \
    add-apt-repository ppa:deadsnakes/ppa \
    && apt-get update && apt-get -y install --no-install-recommends \
        python3.10 python3.10-dev python3.10-venv \
        python3.11 python3.11-dev python3.11-venv \
        python3.12 python3.12-dev python3.12-venv

# Default python → 3.12 (highest version; venvs pin their own)
RUN update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.12 3 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.11 2 \
    && update-alternatives --install /usr/bin/python3 python3 /usr/bin/python3.10 1 \
    && update-alternatives --install /usr/bin/python  python  /usr/bin/python3.12 1

# ── CMake (recent version from Kitware) ─────────────────────────
RUN --mount=type=cache,target=/tmp/cmake-dl \
    wget -q -O /tmp/cmake-dl/cmake.sh \
        "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/cmake-${CMAKE_VERSION}-linux-x86_64.sh" \
    && chmod +x /tmp/cmake-dl/cmake.sh \
    && /tmp/cmake-dl/cmake.sh --skip-license --prefix=/usr/local

# ── Non-root user ───────────────────────────────────────────────
RUN groupadd --gid 1000 vscode \
    && useradd --uid 1000 --gid 1000 -m vscode \
    && echo "vscode ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/vscode

# ── Directories for venvs and HuggingFace cache ────────────────
RUN mkdir -p /workspaces/.venvs && chown vscode:vscode /workspaces/.venvs
RUN mkdir -p /home/vscode/.cache/huggingface && chown -R vscode:vscode /home/vscode/.cache

USER vscode
