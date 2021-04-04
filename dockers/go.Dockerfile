FROM vankichi/dev-base:latest AS go-base


ENV GO_VERSION 1.16
ENV GO111MODULE on
ENV DEBIAN_FRONTEND noninteractive
ENV INITRD No
ENV LANG en_US.UTF-8
ENV GOROOT /opt/go
ENV GOPATH /go
ENV GOFLAGS "-ldflags=-w -ldflags=-s"

WORKDIR /opt
RUN curl -sSL -O "https://dl.google.com/go/go${GO_VERSION}.linux-amd64.tar.gz" \
    && tar zxf "go${GO_VERSION}.linux-amd64.tar.gz" \
    && rm "go${GO_VERSION}.linux-amd64.tar.gz" \
    && ln -s /opt/go/bin/go /usr/bin/ \
    && mkdir -p ${GOPATH}/bin

FROM go-base AS gotests
RUN GO111MODULE=on go get -u  \
    --ldflags "-s -w" --trimpath \
    github.com/cweill/gotests/gotests \
    && upx -9 ${GOPATH}/bin/gotests

FROM go-base AS ghq
RUN GO111MODULE=on go get -u  \
    --ldflags "-s -w" --trimpath \
    github.com/x-motemen/ghq \
    && upx -9 ${GOPATH}/bin/ghq

FROM go-base AS efm
RUN GO111MODULE=on go get -u  \
    --ldflags "-s -w" --trimpath \
    github.com/mattn/efm-langserver \
    && upx -9 ${GOPATH}/bin/efm-langserver

FROM go-base AS golint
RUN GO111MODULE=on go get -u  \
    --ldflags "-s -w" --trimpath \
    golang.org/x/lint/golint@latest \
    && upx -9 ${GOPATH}/bin/golint

FROM golangci/golangci-lint:latest AS golangci-lint-base
FROM go-base AS golangci-lint
COPY --from=golangci-lint-base /usr/bin/golangci-lint $GOPATH/bin/golangci-lint
RUN upx -9 ${GOPATH}/bin/golangci-lint

FROM go-base AS gofumpt
RUN GO111MODULE=on go get -u  \
    --ldflags "-s -w" --trimpath \
    mvdan.cc/gofumpt \
    && upx -9 ${GOPATH}/bin/gofumpt

FROM go-base AS gofumports
RUN GO111MODULE=on go get -u  \
    --ldflags "-s -w" --trimpath \
    mvdan.cc/gofumpt/gofumports \
    && upx -9 ${GOPATH}/bin/gofumports

FROM go-base AS goimports
RUN GO111MODULE=on go get -u  \
    --ldflags "-s -w" --trimpath \
    golang.org/x/tools/cmd/goimports \
    && upx -9 ${GOPATH}/bin/goimports

FROM go-base AS goimports-update-ignore
RUN GO111MODULE=on go get -u  \
    --ldflags "-s -w" --trimpath \
    github.com/pwaller/goimports-update-ignore \
    && upx -9 ${GOPATH}/bin/goimports-update-ignore

FROM go-base AS gopls
RUN GO111MODULE=on go get \
    --ldflags "-s -w" --trimpath \
    golang.org/x/tools/gopls@latest \
    golang.org/x/tools@master \
    && upx -9 ${GOPATH}/bin/gopls

FROM go-base AS hugo
RUN git clone https://github.com/gohugoio/hugo --depth 1 \
    && cd hugo \
    && go install \
    --ldflags "-s -w" --trimpath \
    && upx -9 ${GOPATH}/bin/hugo

FROM go-base AS prototool
RUN GO111MODULE=on go get -u \
    --ldflags "-s -w" --trimpath \
    github.com/uber/prototool/cmd/prototool@dev \
    && upx -9 ${GOPATH}/bin/prototool


FROM go-base AS go
RUN upx -9 ${GOROOT}/bin/*

FROM go-base AS go-bins
COPY --from=efm $GOPATH/bin/efm-langserver $GOPATH/bin/efm-langserver
COPY --from=ghq $GOPATH/bin/ghq $GOPATH/bin/ghq
COPY --from=gofumports $GOPATH/bin/gofumports $GOPATH/bin/gofumports
COPY --from=gofumpt $GOPATH/bin/gofumpt $GOPATH/bin/gofumpt
COPY --from=goimports $GOPATH/bin/goimports $GOPATH/bin/goimports
COPY --from=goimports-update-ignore $GOPATH/bin/goimports-update-ignore $GOPATH/bin/goimports-update-ignore
COPY --from=golangci-lint $GOPATH/bin/golangci-lint $GOPATH/bin/golangci-lint
COPY --from=golint $GOPATH/bin/golint $GOPATH/bin/golint
COPY --from=gopls $GOPATH/bin/gopls $GOPATH/bin/gopls
COPY --from=gotests $GOPATH/bin/gotests $GOPATH/bin/gotests
COPY --from=hugo $GOPATH/bin/hugo $GOPATH/bin/hugo
COPY --from=prototool $GOPATH/bin/prototool $GOPATH/bin/prototool

FROM scratch
ENV GOROOT /opt/go
ENV GOPATH /go
COPY --from=go $GOROOT/bin $GOROOT/bin
COPY --from=go $GOROOT/src $GOROOT/src
COPY --from=go $GOROOT/lib $GOROOT/lib
COPY --from=go $GOROOT/pkg $GOROOT/pkg
COPY --from=go $GOROOT/misc $GOROOT/misc
COPY --from=go-bins $GOPATH/bin $GOPATH/bin
