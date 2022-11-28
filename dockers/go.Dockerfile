FROM vankichi/dev-base:latest AS go-base

ENV GO_VERSION 1.19
ENV GO111MODULE on
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV LANG en_US.UTF-8
ENV GOROOT /opt/go
ENV GOPATH /go
ENV GOBIN ${GOPATH}/bin
ENV GOFLAGS "-ldflags=-w -ldflags=-s"

WORKDIR /opt
RUN curl -sSL -O "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz" \
    && tar zxf "go${GO_VERSION}.linux-amd64.tar.gz" \
    && rm "go${GO_VERSION}.linux-amd64.tar.gz" \
    && ln -s /opt/go/bin/go /usr/bin/ \
    && mkdir -p ${GOBIN}

FROM go-base AS gotests
RUN GO111MODULE=on go install \
    --ldflags "-s -w" --trimpath \
    github.com/cweill/gotests/gotests@latest \
    && chmod a+x ${GOBIN}/gotests \
    && upx -9 ${GOBIN}/gotests

FROM go-base AS ghq
RUN GO111MODULE=on go install \
    --ldflags "-s -w" --trimpath \
    github.com/x-motemen/ghq@latest \
    && chmod a+x ${GOBIN}/ghq \
    && upx -9 ${GOBIN}/ghq

FROM go-base AS efm
RUN GO111MODULE=on go install  \
    --ldflags "-s -w" --trimpath \
    github.com/mattn/efm-langserver@latest \
    && chmod a+x ${GOBIN}/efm-langserver \
    && upx -9 ${GOBIN}/efm-langserver

FROM go-base AS golint
RUN GO111MODULE=on go install  \
    --ldflags "-s -w" --trimpath \
    golang.org/x/lint/golint@latest \
    && chmod a+x ${GOBIN}/golint \
    && upx -9 ${GOBIN}/golint

FROM golangci/golangci-lint:latest AS golangci-lint-base
FROM go-base AS golangci-lint
COPY --from=golangci-lint-base /usr/bin/golangci-lint $GOBIN/golangci-lint
RUN chmod a+x ${GOBIN}/golangci-lint
RUN upx -9 ${GOBIN}/golangci-lint

FROM go-base AS gofumpt
RUN GO111MODULE=on go install  \
    --ldflags "-s -w" --trimpath \
    mvdan.cc/gofumpt@latest \
    && chmod a+x ${GOBIN}/gofumpt \
    && upx -9 ${GOBIN}/gofumpt

FROM go-base AS goimports
RUN GO111MODULE=on go install  \
    --ldflags "-s -w" --trimpath \
    golang.org/x/tools/cmd/goimports@latest \
    && chmod a+x ${GOBIN}/goimports \
    && upx -9 ${GOBIN}/goimports

FROM go-base AS goimports-update-ignore
RUN GO111MODULE=on go install  \
    --ldflags "-s -w" --trimpath \
    github.com/pwaller/goimports-update-ignore@latest \
    && chmod a+x ${GOBIN}/goimports-update-ignore \
    && upx -9 ${GOBIN}/goimports-update-ignore

FROM go-base AS gopls
RUN GO111MODULE=on go install \
    --ldflags "-s -w" --trimpath \
    golang.org/x/tools/gopls@latest \
    && chmod a+x ${GOBIN}/gopls \
    && upx -9 ${GOBIN}/gopls

FROM go-base AS hugo
RUN git clone https://github.com/gohugoio/hugo --depth 1 \
    && cd hugo \
    && go install \
    --ldflags "-s -w" --trimpath \
    && chmod a+x ${GOBIN}/hugo \
    && upx -9 ${GOBIN}/hugo

FROM go-base AS prototool
RUN GO111MODULE=on go install \
    --ldflags "-s -w" --trimpath \
    github.com/uber/prototool/cmd/prototool@dev \
    && chmod a+x ${GOBIN}/prototool \
    && upx -9 ${GOBIN}/prototool


FROM go-base AS go
RUN upx -9 ${GOROOT}/bin/*

FROM go-base AS go-bins
COPY --from=efm $GOBIN/efm-langserver $GOBIN/efm-langserver
COPY --from=ghq $GOBIN/ghq $GOBIN/ghq
COPY --from=gofumpt $GOBIN/gofumpt $GOBIN/gofumpt
COPY --from=goimports $GOBIN/goimports $GOBIN/goimports
COPY --from=goimports-update-ignore $GOBIN/goimports-update-ignore $GOBIN/goimports-update-ignore
COPY --from=golangci-lint $GOBIN/golangci-lint $GOBIN/golangci-lint
COPY --from=golint $GOBIN/golint $GOBIN/golint
COPY --from=gopls $GOBIN/gopls $GOBIN/gopls
COPY --from=gotests $GOBIN/gotests $GOBIN/gotests
COPY --from=hugo $GOBIN/hugo $GOBIN/hugo
COPY --from=prototool $GOBIN/prototool $GOBIN/prototool

FROM scratch
ENV GOROOT /opt/go
ENV GOPATH /go
COPY --from=go $GOROOT/bin $GOROOT/bin
COPY --from=go $GOROOT/src $GOROOT/src
COPY --from=go $GOROOT/lib $GOROOT/lib
COPY --from=go $GOROOT/pkg $GOROOT/pkg
COPY --from=go $GOROOT/misc $GOROOT/misc
COPY --from=go-bins $GOBIN $GOBIN
