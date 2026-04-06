# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

Personal dotfiles and Docker-based development environment for vankichi. The repo serves two purposes:
1. Dotfiles (zsh, tmux, git, neovim, starship) symlinked to `$HOME`
2. Multi-stage Docker images that assemble a full dev container (Go, Rust, Dart, K8s tools, etc.)

## Key Commands

```bash
# Symlink dotfiles to $HOME (legacy layout)
make link

# Symlink dotfiles (newer layout using ~/.config paths)
make new_link

# Remove symlinks
make clean        # legacy
make new_clean    # newer

# Build the main dev container image
make build                # simple docker build
make prod_build           # multiplatform buildx (linux/amd64,linux/arm64)

# Build individual layer images
make build_go             # reads versions/GO_VERSION
make build_rust
make build_env            # reads versions/NGT_VERSION, TENSORFLOW_C_VERSION
make build_k8s
make build_base
make build_all            # builds all layers then prod

# Update version files from upstream releases
make version/go
make version/ngt
make version/tensorflow
make version/flutter

# Run / manage the dev container (defined in alias file)
source ./alias && devrun  # or just: make run
devin                     # exec into running container
devkill                   # stop and remove container
devres                    # kill + rerun

# Multiplatform buildx setup
make init_buildx          # register qemu binfmt
make create_buildx        # create buildx builder "vankichi-builder"
```

## Architecture

- **Dockerfile** — Final dev image. Multi-stage: pulls from `vankichi/{go,rust,docker,dart,kube,env}` images, copies binaries, then installs dotfiles.
- **dockers/** — Individual Dockerfiles for each layer image (base, env, go, rust, k8s, docker, dart, gcloud, glibc, nim).
- **versions/** — Plain text files (e.g., `GO_VERSION`) consumed as `--build-arg` during Docker builds. Updated via `make version/*` targets.
- **Makefile.d/version.mk** — Version-fetching targets, included by the main Makefile.
- **alias** — Shell functions (`devrun`, `devin`, `devkill`) for container lifecycle. `devrun` mounts dotfiles, Go src, Docker socket, SSH keys, etc. into the container; platform-aware (macOS vs Linux).
- **config/nvim/** — Lua-based Neovim config (lazy.nvim plugin manager).
- **nvim/plugins.lua** — Older Neovim plugin config (separate from config/nvim/).
- **config/sheldon/plugins.toml** — Sheldon zsh plugin manager config.

## Docker Image Hierarchy

```
base.Dockerfile → env.Dockerfile → Dockerfile (final)
                                  ↑ copies from: go, rust, docker, dart, kube
```

All images are pushed to Docker Hub under the `vankichi/` namespace. Builds use `docker buildx` for multiplatform support (`linux/amd64,linux/arm64`).
