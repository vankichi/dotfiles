FROM ubuntu:latest AS base

ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV LANG en_US.UTF-8
ENV LANGUAGE en_US:en
ENV LC_ALL en_US.UTF-8
ENV TZ Asia/Tokyo
ENV CC clang
ENV CXX clang++
ENV CLANG_PATH /usr/local/clang
ENV PATH ${PATH}:${CLANG_PATH}/bin
ENV LD_LIBRARY_PATH ${LD_LIBRARY_PATH}:${CLANG_PATH}/lib

RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends --fix-missing \
        axel \
        bash \
        build-essential \
        ca-certificates \
        clang \
        cmake \
        curl \
        diffutils \
        gawk \
        git \
        gnupg \
        jq \
        less \
        libtinfo5 \
        locales \
        mtr \
        ncurses-term \
        openssh-client \
        sed \
        sudo \
        tar \
        tig \
        tmux \
        tree \
        tzdata \
        unzip \
        upx \
        wget \
        xclip \
        zsh \
    && update-alternatives --set cc $(which clang) \
    && update-alternatives --set c++ $(which clang++) \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && ln -fs /usr/share/zoneinfo/Asia/Tokyo /etc/localtime \
    && locale-gen ${LANG} \
    && rm /etc/localtime \
    && dpkg-reconfigure -f noninteractive tzdata \
    && apt-get autoremove
