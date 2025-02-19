.PHONY: all link clean zsh bash build prod_build profile run push pull update/go update/ngt

include Makefile.d/version.mk

USER = $(eval USER := $(shell whoami))$(USER)
USER_ID = $(eval USER_ID := $(shell id -u $(USER)))$(USER_ID)
GROUP_ID = $(eval GROUP_ID := $(shell id -g $(USER)))$(GROUP_ID)
GROUP_IDS = $(eval GROUP_IDS := $(shell id -G $(USER)))$(GROUP_IDS)
ROOTDIR = $(eval ROOTDIR := $(or $(shell git rev-parse --show-toplevel), $(PWD)))$(ROOTDIR)

all: prod_build login push profile git_push

run:
	source ./alias && devrun

unlink:
	unlink $(HOME)/.config/nvim

new_link:
	ln -sfv $(shell pwd)/gitconfig $(HOME)/.gitconfig
	ln -sfv $(shell pwd)/zshrc $(HOME)/.zshrc
	ln -sfv $(shell pwd)/tmux.conf $(HOME)/.config/tmux/.tmux.conf
	# ln -sfv $(shell pwd)/config/nvim $(HOME)/.config
	# ln -sfv $(shell pwd)/config/sheldon $(HOME)/.config
	ln -sfv $(shell pwd)editorconfig $(HOME)/.editorconfig

new_clean:
	unlink $(HOME)/.config/tmux/.tmux.conf

link:
	mkdir -p ${HOME}/.config/nvim/colors
	mkdir -p ${HOME}/.config/nvim/syntax
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))init.vim $(HOME)/.config/nvim/init.vim
	# ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))starship.toml $(HOME)/.config/starship.toml
	# ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))efm-lsp-conf.yaml $(HOME)/.config/nvim/efm-lsp-conf.yaml
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))coc-settings.json $(HOME)/.config/nvim/coc-settings.json
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))monokai.vim $(HOME)/.config/nvim/colors/monokai.vim
	# ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))go.vim $(HOME)/.config/nvim/syntax/go.vim
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))zshrc $(HOME)/.zshrc
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))editorconfig $(HOME)/.editorconfig
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))alias $(HOME)/.aliases
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))gitconfig $(HOME)/.gitconfig
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))gitattributes $(HOME)/.gitattributes
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))gitignore $(HOME)/.gitignore
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))tmux.conf $(HOME)/.tmux.conf
	ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))tmux-kube $(HOME)/.tmux-kube
	# ln -sfv $(dir $(abspath $(lastword $(MAKEFILE_LIST))))tmux.new-session $(HOME)/.tmux.new-session

clean:
	# sed -e "/\[\ \-f\ \$HOME\/\.aliases\ \]\ \&\&\ source\ \$HOME\/\.aliases/d" ~/.zshrc
	unlink $(HOME)/.config/nvim/init.vim
	# unlink $(HOME)/.config/starship.toml
	# unlink $(HOME)/.config/nvim/efm-lsp-conf.yaml
	unlink $(HOME)/.config/nvim/coc-settings.json
	unlink $(HOME)/.config/nvim/colors/monokai.vim
	# unlink $(HOME)/.config/nvim/syntax/go.vim
	unlink $(HOME)/.zshrc
	unlink $(HOME)/.editorconfig
	unlink $(HOME)/.aliases
	unlink $(HOME)/.gitconfig
	unlink $(HOME)/.gitattributes
	unlink $(HOME)/.gitignore
	unlink $(HOME)/.tmux.conf
	unlink $(HOME)/.tmux-kube
	# unlink $(HOME)/.tmux.new-session

zsh: link
	[ -f $(HOME)/.zshrc ] && echo "[ -f $$HOME/.aliases ] && source $$HOME/.aliases" >> $(HOME)/.zshrc

bash: link
	[ -f $(HOME)/.bashrc ] && echo "[ -f $$HOME/.aliases ] && source $$HOME/.aliases" >> $(HOME)/.bashrc

build:
	docker build -t vankichi/dev:latest .

docker_build:
	docker build ${ARGS} --squash -t ${IMAGE_NAME}:latest -f ${DOCKERFILE} .
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
DOCKER_BUILDER_PLATFORM = "linux/amd64,linux/arm64/v8"

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
