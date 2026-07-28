FROM vankichi/go:latest AS go

FROM vankichi/rust:latest AS rust

FROM vankichi/docker:latest AS docker

FROM vankichi/dart:latest AS dart

FROM vankichi/kube:latest AS kube

FROM vankichi/env:latest AS env

FROM env

LABEL maintainer="vankichi <kyukawa315@gmail.com>"

ARG USER_ID=1000
ARG GROUP_ID=1000
ARG WHOAMI=vankichi

ENV GROUP sudo,root,users,docker,wheel
ENV TZ Asia/Tokyo
ENV HOME /home/${WHOAMI}
ENV GOPATH $HOME/go
ENV DART_PATH /usr/local/flutter
ENV GOROOT /usr/local/go
ENV CARGO_PATH $HOME/.cargo
ENV NVIM_HOME $HOME/.config/nvim
ENV VIM_PLUG_HOME $NVIM_HOME/plugged/vim-plug
ENV LIBRARY_PATH /usr/local/lib:$LIBRARY_PATH
ENV PATH $GOPATH/bin:/usr/local/go/bin:$CARGO_PATH/bin:$DART_PATH/bin:$GCLOUD_PATH/bin:$PATH

COPY --from=docker /usr/lib/docker/cli-plugins/docker-buildx /usr/lib/docker/cli-plugins/docker-buildx
COPY --from=docker /usr/lib/docker/cli-plugins/docker-compose /usr/lib/docker/cli-plugins/docker-compose
COPY --from=docker /usr/docker/bin/ /usr/bin/

COPY --from=dart /usr/local/bin/flutter/ $DART_PATH

COPY --from=kube /usr/k8s/bin/ /usr/bin/

COPY --from=go /opt/go/bin $GOROOT/bin
COPY --from=go /opt/go/src $GOROOT/src
COPY --from=go /opt/go/lib $GOROOT/lib
COPY --from=go /opt/go/pkg $GOROOT/pkg
COPY --from=go /opt/go/misc $GOROOT/misc
COPY --from=go /go/bin $GOPATH/bin

COPY --from=rust /root/.cargo $CARGO_PATH
COPY --from=rust /root/.cargo/bin/rustup $HOME/.rustup

COPY gitattributes $HOME/.gitattributes
COPY gitconfig $HOME/.gitconfig
COPY gitignore $HOME/.gitignore
COPY tmux-kube $HOME/.tmux-kube
COPY tmux.conf $HOME/.config/tmux/tmux.conf
COPY zshrc $HOME/.zshrc

ENV SHELL /usr/bin/zsh

WORKDIR $VIM_PLUG_HOME

USER root
# `rm -f ${HOME}/.tmux.conf` drops the stale tmux config inherited from the parent
# image. $HOME/.config/tmux/tmux.conf is the only source of truth; with both in
# place tmux loads each one (the stale one first) and settings become untraceable.
RUN usermod -aG ${GROUP} ${WHOAMI} \
    && chown -R ${USER_ID}:${GROUP_ID} ${HOME} \
    && chown -R ${USER_ID}:${GROUP_ID} ${HOME}/.* \
    && chmod -R 755 ${HOME} \
    && chmod -R 755 ${HOME}/.* \
    && rm -rf $VIM_PLUG_HOME/autoload \
    && rm -f ${HOME}/.tmux.conf \
    && git clone --depth 1 https://github.com/junegunn/vim-plug.git $VIM_PLUG_HOME/autoload \
    && npm uninstall yarn -g \
    && npm install yarn -g \
    && rm -rf ${HOME}/.cache \
    && rm -rf ${HOME}/.npm/_cacache \
    && rm -rf ${HOME}/.cargo/registry/cache \
    && rm -rf /usr/local/share/.cache \
    && rm -rf /tmp/* \
    && chown -R ${USER_ID}:${GROUP_ID} ${HOME} \
    && chown -R ${USER_ID}:${GROUP_ID} ${HOME}/.* \
    && chown -R ${USER_ID}:${GROUP_ID} /usr/local/lib/node_modules \
    && chown -R ${USER_ID}:${GROUP_ID} /usr/local/bin/npm \
    && chmod -R 755 ${HOME} \
    && chmod -R 755 ${HOME}/.* \
    && chmod -R 755 /usr/local/lib/node_modules \
    && chmod -R 755 /usr/local/bin/npm

# sheldon (zsh plugin manager)
# Bake in the statically linked musl release, verified by checksum.
# devrun used to bind-mount the host's /usr/bin/sheldon instead, but a
# dynamically linked binary from an Arch host cannot resolve libgit2.so.1.9 in an
# Ubuntu container and fails to start (sonames differ across distros). Pin the
# supply path to the image.
# Always bump the version and the checksum together; a desync fails sha256sum -c.
RUN set -eux; \
    SHELDON_VERSION='0.8.5'; \
    case "$(dpkg --print-architecture)" in \
        amd64) sheldon_target='x86_64-unknown-linux-musl'; \
               sheldon_sha256='80aa0be617072c278d67fd6c5fbce4903d3801d78b6abf8f058f0648d2242c78' ;; \
        arm64) sheldon_target='aarch64-unknown-linux-musl'; \
               sheldon_sha256='1f6b792e49e259f7c313e9921c8d4ad638d827abc2c023efe0588a55678f9a3e' ;; \
        *) echo "unsupported architecture for sheldon: $(dpkg --print-architecture)" >&2; exit 1 ;; \
    esac; \
    sheldon_tar="/tmp/sheldon-${SHELDON_VERSION}-${sheldon_target}.tar.gz"; \
    curl -fsSL -o "${sheldon_tar}" \
        "https://github.com/rossmacarthur/sheldon/releases/download/${SHELDON_VERSION}/sheldon-${SHELDON_VERSION}-${sheldon_target}.tar.gz"; \
    echo "${sheldon_sha256}  ${sheldon_tar}" | sha256sum -c -; \
    tar -xzf "${sheldon_tar}" -C /usr/local/bin sheldon; \
    rm -f "${sheldon_tar}"; \
    chmod 755 /usr/local/bin/sheldon; \
    sheldon --version

USER ${USER_ID}
WORKDIR ${HOME}

ENTRYPOINT ["docker-entrypoint"]
CMD ["/usr/bin/zsh"]
