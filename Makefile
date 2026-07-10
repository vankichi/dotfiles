.PHONY: all new_link new_clean zsh bash build prod_build profile run push pull update/go update/ngt

include Makefile.d/version.mk

USER = $(eval USER := $(shell whoami))$(USER)
USER_ID = $(eval USER_ID := $(shell id -u $(USER)))$(USER_ID)
GROUP_ID = $(eval GROUP_ID := $(shell id -g $(USER)))$(GROUP_ID)
GROUP_IDS = $(eval GROUP_IDS := $(shell id -G $(USER)))$(GROUP_IDS)
ROOTDIR = $(eval ROOTDIR := $(or $(shell git rev-parse --show-toplevel), $(PWD)))$(ROOTDIR)
# $(ROOTDIR)/
all: prod_build login push profile git_push

run:
	source ./alias && devrun

unlink:
	unlink $(HOME)/.config/nvim

new_link:
	mkdir -p $(HOME)/.config
	mkdir -p $(HOME)/.config/tmux
	mkdir -p $(HOME)/.config/sheldon
	ln -sfv $(shell pwd)/gitconfig $(HOME)/.gitconfig
	ln -sfv $(shell pwd)/zshrc $(HOME)/.zshrc
	[ -f $(shell pwd)/zshrc.local ] && ln -sfv $(shell pwd)/zshrc.local $(HOME)/.zshrc.local || true
	ln -sfv $(shell pwd)/tmux.conf $(HOME)/.config/tmux/tmux.conf
	ln -sfnv $(shell pwd)/config/nvim $(HOME)/.config/nvim
	ln -sfv $(shell pwd)/starship.toml $(HOME)/.config/starship.toml
	ln -sfv $(shell pwd)/config/sheldon/plugins.toml $(HOME)/.config/sheldon/plugins.toml
	ln -sfv $(shell pwd)/editorconfig $(HOME)/.editorconfig
	ln -sfv $(shell pwd)/alias $(HOME)/.aliases
	ln -sfv $(shell pwd)/gitattributes $(HOME)/.gitattributes
	ln -sfv $(shell pwd)/gitignore $(HOME)/.gitignore
	ln -sfv $(shell pwd)/tmux-kube $(HOME)/.tmux-kube
	# Claude Code config (runtime state stays local under ~/.claude)
	mkdir -p $(HOME)/.claude
	ln -sfv $(shell pwd)/claude/CLAUDE.md $(HOME)/.claude/CLAUDE.md
	ln -sfv $(shell pwd)/claude/settings.json $(HOME)/.claude/settings.json
	ln -sfv $(shell pwd)/claude/statusline-command.sh $(HOME)/.claude/statusline-command.sh
	ln -sfnv $(shell pwd)/claude/agents $(HOME)/.claude/agents
	ln -sfnv $(shell pwd)/claude/skills $(HOME)/.claude/skills
	ln -sfnv $(shell pwd)/claude/hooks $(HOME)/.claude/hooks
	ln -sfnv $(shell pwd)/claude/rules $(HOME)/.claude/rules

new_clean:
	-unlink $(HOME)/.gitconfig
	-unlink $(HOME)/.zshrc
	-unlink $(HOME)/.zshrc.local
	-unlink $(HOME)/.editorconfig
	-unlink $(HOME)/.aliases
	-unlink $(HOME)/.gitattributes
	-unlink $(HOME)/.gitignore
	-unlink $(HOME)/.tmux-kube
	-unlink $(HOME)/.config/tmux/tmux.conf
	-unlink $(HOME)/.config/nvim
	-unlink $(HOME)/.config/starship.toml
	-unlink $(HOME)/.config/sheldon/plugins.toml
	-unlink $(HOME)/.claude/CLAUDE.md
	-unlink $(HOME)/.claude/settings.json
	-unlink $(HOME)/.claude/statusline-command.sh
	-unlink $(HOME)/.claude/agents
	-unlink $(HOME)/.claude/skills
	-unlink $(HOME)/.claude/hooks
	-unlink $(HOME)/.claude/rules

zsh: new_link
	@if [ -f "$(HOME)/.zshrc" ] && ! grep -qF '[ -f $HOME/.aliases ] && source $HOME/.aliases' "$(HOME)/.zshrc"; then \
		echo '[ -f $$HOME/.aliases ] && source $$HOME/.aliases' >> "$(HOME)/.zshrc"; \
	fi

bash: new_link
	@if [ -f "$(HOME)/.bashrc" ] && ! grep -qF '[ -f $HOME/.aliases ] && source $HOME/.aliases' "$(HOME)/.bashrc"; then \
		echo '[ -f $$HOME/.aliases ] && source $$HOME/.aliases' >> "$(HOME)/.bashrc"; \
	fi

build:
	docker build -t vankichi/dev:latest .

docker_build:
	# docker build ${ARGS} --squash -t ${IMAGE_NAME}:latest -f ${DOCKERFILE} .
	docker buildx build --platform $(DOCKER_BUILDER_PLATFORM) ${ARGS} --squash -t ${IMAGE_NAME}:latest -f ${DOCKERFILE} . --push
	# docker buildx build --squash -t ${IMAGE_NAME}:latest -f ${DOCKERFILE} .

docker_push:
	docker push ${IMAGE_NAME}:latest

prod_build:
	@make DOCKERFILE="./Dockerfile" IMAGE_NAME="vankichi/dev" docker_build

build_go:
	@make DOCKERFILE="./dockers/go.Dockerfile" IMAGE_NAME="vankichi/go" ARGS="--build-arg=GO_VERSION=$(shell cat ./versions/GO_VERSION)" docker_build

build_rust:
	@make DOCKERFILE="./dockers/rust.Dockerfile" IMAGE_NAME="vankichi/rust" docker_build

build_nim:
	@make DOCKERFILE="./dockers/nim.Dockerfile" IMAGE_NAME="vankichi/nim" docker_build

build_dart:
	@make DOCKERFILE="./dockers/dart.Dockerfile" IMAGE_NAME="vankichi/dart" ARGS="--build-arg=FLUTTER_VERSION=$(shell cat ./versions/FLUTTER_VERSION)" docker_build

build_docker:
	@make DOCKERFILE="./dockers/docker.Dockerfile" IMAGE_NAME="vankichi/docker" docker_build

build_base:
	@make DOCKERFILE="./dockers/base.Dockerfile" IMAGE_NAME="vankichi/dev-base" docker_build

build_env:
	@make DOCKERFILE="./dockers/env.Dockerfile" IMAGE_NAME="vankichi/env" ARGS="--build-arg=NGT_VERSION=$(shell cat ./versions/NGT_VERSION) --build-arg=TENSORFLOW_C_VERSION=$(shell cat ./versions/TENSORFLOW_C_VERSION)" docker_build

build_gcloud:
	@make DOCKERFILE="./dockers/gcloud.Dockerfile" IMAGE_NAME="vankichi/gcloud" docker_build

build_k8s:
	@make DOCKERFILE="./dockers/k8s.Dockerfile" IMAGE_NAME="vankichi/kube" docker_build

build_glibc:
	@make DOCKERFILE="./dockers/glibc.Dockerfile" IMAGE_NAME="vankichi/glibc" docker_build

prod_push:
	@make IMAGE_NAME="vankichi/dev" docker_push

push_go:
	@make IMAGE_NAME="vankichi/go" docker_push

push_rust:
	@make IMAGE_NAME="vankichi/rust" docker_push

push_nim:
	@make IMAGE_NAME="vankichi/nim" docker_push

push_dart:
	@make IMAGE_NAME="vankichi/dart" docker_push

push_docker:
	@make IMAGE_NAME="vankichi/docker" docker_push

push_base:
	@make IMAGE_NAME="vankichi/dev-base" docker_push

push_env:
	@make IMAGE_NAME="vankichi/env" docker_push

push_gcloud:
	@make IMAGE_NAME="vankichi/gcloud" docker_push

push_k8s:
	@make IMAGE_NAME="vankichi/kube" docker_push

push_glibc:
	@make IMAGE_NAME="vankichi/glibc" docker_push

build_all: \
	build_base \
	build_env \
	build_docker \
	build_go \
	build_k8s \
	build_rust \
	build_dart \
	prod_build
	echo "done"

push_all: \
	push_base \
	push_env \
	push_docker \
	push_go \
	push_k8s \
	push_rust \
	push_dart \
	prod_push
	echo "done"

profile:
	rm -f analyze.txt
	type dlayer >/dev/null 2>&1 && docker save vankichi/dev:latest | dlayer >> analyze.txt

login:
	docker login -u vankichi

push:
	docker push vankichi/dev:latest

pull:
	docker pull vankichi/dev:latest

git_push:
	git add -A
	git commit -m fix
	git push

DOCKER_EXTRA_OPTS = ""
DOCKER_BUILDER_NAME = "vankichi-builder"
DOCKER_BUILDER_DRIVER = "docker-container"
DOCKER_BUILDER_PLATFORM = "linux/amd64"
# DOCKER_BUILDER_PLATFORM = "linux/amd64,linux/arm64"

init_buildx:
	docker run \
	  --network=host \
	  --privileged \
	  --rm tonistiigi/binfmt:master \
	  --install $(DOCKER_BUILDER_PLATFORM)

create_buildx:
	-docker buildx rm --force $(DOCKER_BUILDER_NAME)
	docker buildx create --use \
		--name $(DOCKER_BUILDER_NAME) \
		--driver $(DOCKER_BUILDER_DRIVER) \
		--driver-opt=image=moby/buildkit:master \
		--driver-opt=network=host \
		--buildkitd-flags="--oci-worker-gc=false --oci-worker-snapshotter=stargz" \
		--platform $(DOCKER_BUILDER_PLATFORM) \
		--bootstrap
	# make add_nodes
	docker buildx ls
	docker buildx inspect --bootstrap $(DOCKER_BUILDER_NAME)
	sudo chown -R $(USER):$(GROUP_ID) "$(HOME)/.docker"

remove_buildx:
	docker buildx rm --force --all-inactive
	sudo rm -rf $(HOME)/.docker/buildx
	docker buildx ls
