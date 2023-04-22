FROM vankichi/dev-base:latest AS env

ENV LD_LIBRARY_PATH $LD_LIBRARY_PATH:/usr/lib:/usr/local/lib:/lib:/lib64:/var/lib:/google-cloud-sdk/lib:/usr/local/go/lib:/usr/lib/dart/lib:/usr/lib/node_modules/lib

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG DOCKER_GROUP_ID=961
ARG GROUP_IDS=${GROUP_ID}
ARG WHOAMI=vankichi

ENV BASE_DIR /home
ENV USER ${WHOAMI}
ENV HOME ${BASE_DIR}/${USER}
ENV SHELL /usr/bin/zsh
ENV GROUP sudo,root,users,docker,wheel
ENV UID ${USER_ID}
ENV GITHUB https://github.com
ENV API_GITHUB https://api.github.com/repos

RUN groupadd --non-unique --gid ${DOCKER_GROUP_ID} docker \
    && groupadd --non-unique --gid ${GROUP_ID} wheel \
    && groupmod --non-unique --gid ${GROUP_ID} users \
    && useradd --uid ${USER_ID} \
        --gid ${GROUP_ID} \
        --non-unique --create-home \
        --shell ${SHELL} \
        --base-dir ${BASE_DIR} \
        --home ${HOME} \
        --groups ${GROUP} ${USER} \
    && echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers \
    && echo "${USER} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers \
    && sed -i -e 's/# %users\tALL=(ALL)\tNOPASSWD: ALL/%users\tALL=(ALL)\tNOPASSWD: ALL/' /etc/sudoers \
    && sed -i -e 's/%users\tALL=(ALL)\tALL/# %users\tALL=(ALL)\tALL/' /etc/sudoers \
    && chown -R 0:0 /etc/sudoers.d \
    && chown -R 0:0 /etc/sudoers \
    && chmod -R 0440 /etc/sudoers.d \
    && chmod -R 0440 /etc/sudoers \
    && visudo -c

WORKDIR /tmp
RUN echo $'/lib\n\
/lib64\n\
/var/lib\n\
/usr/lib\n\
/usr/local/lib\n\
/usr/local/go/lib\n\
/usr/local/clang/lib\n\
/usr/lib/node_modules/lib' > /etc/ld.so.conf.d/usr-local-lib.conf \
    && echo $(ldconfig)

RUN apt-get update -y \
    && apt-get upgrade -y \
    && apt-get install -y --no-install-recommends --fix-missing \
    libgtk-3-dev \
    liblzma-dev \
    libhdf5-serial-dev \
    libomp-dev \
    libopenblas-dev \
    nodejs \
    npm \
    vim \
    ninja-build \
    pkg-config \
    python3-dev \
    python3-pip \
    python3-setuptools \
    python3-venv \
    && apt-get clean \
    && curl -LO "https://github.com/neovim/neovim/releases/download/stable/nvim-linux64.tar.gz" \
    && tar -zxvf nvim-linux64.tar.gz \
    && mv ./nvim-linux64/bin/nvim /usr/bin/nvim \
    && chmod 755 -R /usr/bin/nvim \
    && mv ./nvim-linux64/share/nvim /usr/share/nvim \
    && mv ./nvim-linux64/lib/nvim /usr/lib/nvim \
    && rm -rf /var/lib/apt/lists/* \
    && rm -rf /var/lib/apt/lists/* \
    && pip3 install --upgrade pip ranger-fm thefuck httpie python-language-server vim-vint grpcio-tools \
    && apt -y autoremove \
    && chown -R ${USER}:users ${HOME} \
    && chown -R ${USER}:users ${HOME}/.* \
    && chmod -R 755 ${HOME} \
    && chmod -R 755 ${HOME}/.* \
    && nvim -v \
    && npm install -g n

RUN n lts \
    && hash -r \
    && bash -c "chown -R ${USER} $(npm config get prefix)/{lib/node_modules,bin,share}" \
    && bash -c "chmod -R 755 $(npm config get prefix)/{lib/node_modules,bin,share}" \
    && npm install -g \
        diagnostic-languageserver \
        dockerfile-language-server-nodejs \
        bash-language-server \
        markdownlint-cli \
        npm \
        prettier \
        resume-cli \
        terminalizer \
        typescript \
        typescript-language-server \
        yarn \
    && bash -c "chown -R ${USER} $(npm config get prefix)/{lib/node_modules,bin,share}" \
    && bash -c "chmod -R 755 $(npm config get prefix)/{lib/node_modules,bin,share}" \
    && apt purge -y nodejs npm \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/* \
    && apt -y autoremove

RUN cmake --version

WORKDIR /tmp
RUN set -x; cd "$(mktemp -d)" \
    && OS="linux" \
    && ARCH="x86_64" \
    && REPO_NAME="protobuf" \
    && BIN_NAME="protoc" \
    && RELEASE_LATEST="releases/latest" \
    && REPO="protocolbuffers/${REPO_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && ZIP_NAME="${BIN_NAME}-${VERSION}-${OS}-${ARCH}" \
    && curl -fsSL "${GITHUB}/${REPO}/releases/download/v${VERSION}/${ZIP_NAME}.zip" -o "/tmp/${BIN_NAME}.zip" \
    && unzip -o "/tmp/${BIN_NAME}.zip" -d /usr/local "bin/${BIN_NAME}" \
    && unzip -o "/tmp/${BIN_NAME}.zip" -d /usr/local 'include/*' \
    && rm -f /tmp/protoc.zip \
    && rm -rf /tmp/*

WORKDIR /tmp
ENV NGT_VERSION 2.0.9
ENV CFLAGS "-mno-avx512f -mno-avx512dq -mno-avx512cd -mno-avx512bw -mno-avx512vl"
ENV CXXFLAGS ${CFLAGS}
RUN curl -LO "https://github.com/yahoojapan/NGT/archive/v${NGT_VERSION}.tar.gz" \
    && tar zxf "v${NGT_VERSION}.tar.gz" -C /tmp \
    && cd "/tmp/NGT-${NGT_VERSION}" \
    && cmake -DNGT_LARGE_DATASET=ON . \
    && make -j -C "/tmp/NGT-${NGT_VERSION}" \
    && make install -C "/tmp/NGT-${NGT_VERSION}" \
    && cd /tmp \
    && rm -rf /tmp/*

WORKDIR /tmp
ENV TENSORFLOW_C_VERSION 2.10.0
RUN curl -LO https://storage.googleapis.com/tensorflow/libtensorflow/libtensorflow-cpu-linux-x86_64-${TENSORFLOW_C_VERSION}.tar.gz \
    && tar -C /usr/local -xzf libtensorflow-cpu-linux-x86_64-${TENSORFLOW_C_VERSION}.tar.gz \
    && rm -f libtensorflow-cpu-linux-x86_64-${TENSORFLOW_C_VERSION}.tar.gz \
    && ldconfig \
    && rm -rf /tmp/* /var/cache
