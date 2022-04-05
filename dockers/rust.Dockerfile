FROM vankichi/dev-base:latest AS rust-base

ARG TOOLCHAIN=nightly

ENV HOME /root
ENV RUSTUP ${HOME}/.rustup
ENV CARGO ${HOME}/.cargo
ENV BIN_PATH ${CARGO}/bin
ENV PATH /root/.cargo/bin:$PATH

RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

RUN rustup install stable \
    && rustup install beta \
    && rustup install nightly \
    && rustup toolchain install nightly \
    && rustup default nightly \
    && rustup update \
    && rustup component add \
       rustfmt \
       rust-analysis \
       rust-src \
       clippy \
       --toolchain nightly

RUN cargo install --force --no-default-features \
    --git https://github.com/mozilla/sccache sccache

FROM rust-base AS cargo-bloat
RUN  cargo install --force --no-default-features \
    --git https://github.com/RazrFalcon/cargo-bloat

FROM rust-base AS fd
RUN cargo install --force --no-default-features \
    --git https://github.com/sharkdp/fd

FROM rust-base AS exa
RUN rustup update stable \
    && rustup default stable \
    && cargo install --force --no-default-features \
    exa

FROM rust-base AS rg
RUN cargo +nightly install --force --no-default-features \
    ripgrep

FROM rust-base AS procs
RUN cargo install --force --no-default-features \
    --git https://github.com/dalance/procs

FROM rust-base AS bat
RUN cargo install --force --locked \
    --git https://github.com/sharkdp/bat

FROM rust-base AS dutree
RUN cargo +nightly install --force --no-default-features \
    dutree

FROM rust-base AS sd
RUN cargo +nightly install --force --no-default-features \
    sd

# FROM rust-base AS gping
# RUN cargo +nightly install --force --no-default-features \
#     gping

FROM rust-base AS delta
RUN cargo +nightly install --force --no-default-features \
    git-delta

FROM rust-base AS bottom
RUN rustup update stable \
    && rustup default stable \
    && cargo install --force --no-default-features \
    --git https://github.com/ClementTsang/bottom

FROM scratch AS rust

ENV HOME /root
ENV RUSTUP ${HOME}/.rustup
ENV CARGO ${HOME}/.cargo
ENV BIN_PATH ${CARGO}/bin

COPY --from=rust-base /root/.cargo /root/.cargo
COPY --from=bat /root/.cargo/bin/bat /root/.cargo/bin/bat
COPY --from=bottom /root/.cargo/bin/btm /root/.cargo/bin/btm
COPY --from=delta /root/.cargo/bin/delta /root/.cargo/bin/delta
COPY --from=exa /root/.cargo/bin/exa /root/.cargo/bin/exa
COPY --from=fd /root/.cargo/bin/fd /root/.cargo/bin/fd
# COPY --from=gping /root/.cargo/bin/gping /root/.cargo/bin/gping
COPY --from=procs /root/.cargo/bin/procs /root/.cargo/bin/procs
COPY --from=rg /root/.cargo/bin/rg /root/.cargo/bin/rg
COPY --from=sd /root/.cargo/bin/sd /root/.cargo/bin/sd
COPY --from=rust-base ${BIN_PATH}/rustup ${BIN_PATH}/rustup
COPY --from=rust-base ${CARGO} ${CARGO}
COPY --from=rust-base ${RUSTUP}/settings.toml ${RUSTUP}/settings.toml
