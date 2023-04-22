FROM vankichi/dev-base:latest AS kube-base

ENV ARCH amd64
ENV OS linux
ENV GITHUB https://github.com
ENV RAWGITHUB https://raw.githubusercontent.com
ENV API_GITHUB https://api.github.com/repos
ENV GOOGLE https://storage.googleapis.com
ENV RELEASE_DL releases/download
ENV ARCHIVE_DL archive/refs/tags
ENV RELEASE_LATEST releases/latest
ENV LOCAL /usr/local
ENV BIN_PATH ${LOCAL}/bin
ENV TELEPRESENCE_VERSION 2.6.8

RUN apt-get update

RUN apt-get update && apt-get install -y --no-install-recommends \
    python3.9 \
    python3-setuptools \
    python3-pip \
    python3-venv \
    && mkdir -p ${BIN_PATH}

FROM kube-base AS kubectl
RUN set -x; cd "$(mktemp -d)" \
    && mkdir -p ${BIN_PATH} \
    && curl -fsSLo ${BIN_PATH}/kubectl "${GOOGLE}/kubernetes-release/release/$(curl -s ${GOOGLE}/kubernetes-release/release/stable.txt)/bin/${OS}/${ARCH}/kubectl" \
    && chmod a+x ${BIN_PATH}/kubectl \
    && ${BIN_PATH}/kubectl version --client

FROM kube-base AS helm
RUN set -x; cd "$(mktemp -d)" \
    && curl "${RAWGITHUB}/helm/helm/master/scripts/get-helm-3" | bash \
    && BIN_NAME="helm" \
    && chmod a+x "${BIN_PATH}/${BIN_NAME}" \
    && upx -9 "${BIN_PATH}/${BIN_NAME}"


FROM kube-base AS helmfile
RUN set -x; cd "$(mktemp -d)" \
    && ORG="roboll" \
    && NAME="helmfile" \
    && REPO="${ORG}/${NAME}" \
    && HELMFILE_VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLo ${BIN_PATH}/helmfile "${GITHUB}/${REPO}/${RELEASE_DL}/v${HELMFILE_VERSION}/helmfile_${OS}_${ARCH}" \
    && chmod a+x ${BIN_PATH}/helmfile

FROM kube-base AS kubectx
RUN set -x; cd "$(mktemp -d)" \
    && git clone "${GITHUB}/ahmetb/kubectx" /opt/kubectx \
    && mv /opt/kubectx/kubectx ${BIN_PATH}/kubectx \
    && mv /opt/kubectx/kubens ${BIN_PATH}/kubens

FROM kube-base AS krew
RUN set -x; cd "$(mktemp -d)" \
    && ORG="kubernetes-sigs" \
    && NAME="krew" \
    && REPO="${ORG}/${NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLO "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${NAME}-${OS}_${ARCH}.tar.gz" \
    && curl -fsSLO "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/krew.yaml" \
    && tar zxvf krew-${OS}_${ARCH}.tar.gz \
    && ./krew-"${OS}_${ARCH}" install --manifest=krew.yaml --archive=krew-${OS}_${ARCH}.tar.gz

FROM kube-base AS kubebox
RUN set -x; cd "$(mktemp -d)" \
    && ORG="astefanutti" \
    && NAME="kubebox" \
    && REPO="${ORG}/${NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLo ${BIN_PATH}/${NAME} "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${NAME}-${OS}" \
    && chmod a+x ${BIN_PATH}/${NAME}

FROM kube-base AS stern
RUN set -x; cd "$(mktemp -d)" \
    && ORG="stern" \
    && NAME="stern" \
    && REPO="${ORG}/${NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLO "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${NAME}_${VERSION}_${OS}_${ARCH}.tar.gz" \
    && tar zvxf ${NAME}_${VERSION}_${OS}_${ARCH}.tar.gz \
    && mv ${NAME} ${BIN_PATH}/${NAME} \
    && chmod a+x ${BIN_PATH}/${NAME}

FROM kube-base AS kubebuilder
RUN set -x; cd "$(mktemp -d)" \
    && ORG="kubernetes-sigs" \
    && BIN_NAME="kubebuilder" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && FILE_NAME="${BIN_NAME}_${OS}_${ARCH}" \
    && curl -fsSLO "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${FILE_NAME}" \
    && mv "${FILE_NAME}" "${BIN_PATH}/${BIN_NAME}" \
    && chmod a+x "${BIN_PATH}/${BIN_NAME}" \
    && upx -9 "${BIN_PATH}/${BIN_NAME}"

FROM kube-base AS kind
RUN set -x; cd "$(mktemp -d)" \
    && ORG="kubernetes-sigs" \
    && BIN_NAME="kind" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLo ${BIN_PATH}/${BIN_NAME} "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${BIN_NAME}-${OS}-${ARCH}" \
    && chmod a+x ${BIN_PATH}/kind

FROM kube-base AS kubectl-fzf
RUN set -x; cd "$(mktemp -d)" \
    && ORG="bonnefoa" \
    && BIN_NAME="kubectl-fzf" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLO "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${BIN_NAME}_${OS}_${ARCH}.tar.gz" \
    && tar -zxvf ${BIN_NAME}_${OS}_${ARCH}.tar.gz \
    && mv kubectl-fzf-server ${BIN_PATH}/${BIN_NAME}-server \
    && mv kubectl-fzf-completion ${BIN_PATH}/${BIN_NAME}-completion

FROM kube-base AS k9s
RUN set -x; cd "$(mktemp -d)" \
    && ORG="derailed" \
    && BIN_NAME="k9s" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLO "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${BIN_NAME}_Linux_amd64.tar.gz" \
    && tar -zxvf ${BIN_NAME}_Linux_amd64.tar.gz \
    && mv k9s ${BIN_PATH}/k9s

FROM kube-base AS telepresence
RUN set -x; cd "$(mktemp -d)" \
    && BIN_NAME="telepresence" \
    && curl -fL https://app.getambassador.io/download/tel2/linux/amd64/latest/telepresence -o ${BIN_PATH}/${BIN_NAME} \
    && chmod a+x ${BIN_PATH}/${BIN_NAME}

FROM kube-base AS kube-profefe
RUN set -x; cd "$(mktemp -d)" \
    && ORG="profefe" \
    && BIN_NAME="kube-profefe" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLO "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${BIN_NAME}_v${VERSION}_Linux_x86_64.tar.gz" \
    && tar -zxvf "${BIN_NAME}_v${VERSION}_Linux_x86_64.tar.gz" \
    && mv kprofefe ${BIN_PATH}/kprofefe \
    && mv kubectl-profefe ${BIN_PATH}/kubectl-profefe

FROM kube-base AS kube-tree
RUN set -x; cd "$(mktemp -d)" \
    && ORG="ahmetb" \
    && BIN_NAME="kubectl-tree" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLO ${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${BIN_NAME}_v${VERSION}_${OS}_${ARCH}.tar.gz \
    && tar -zxvf "${BIN_NAME}_v${VERSION}_${OS}_${ARCH}.tar.gz" \
    && mv ${BIN_NAME} ${BIN_PATH}/${BIN_NAME}

FROM kube-base AS linkerd
RUN set -x; cd "$(mktemp -d)" \
    && curl -sL https://run.linkerd.io/install | sh \
    && mv ${HOME}/.linkerd2/bin/linkerd-* ${BIN_PATH}/linkerd

FROM kube-base AS skaffold
RUN set -x; cd "$(mktemp -d)" \
    && ORG="GoogleContainerTools" \
    && BIN_NAME="skaffold" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLo "${BIN_PATH}/${BIN_NAME}" "${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${BIN_NAME}-${OS}-${ARCH}" \
    && chmod a+x "${BIN_PATH}/${BIN_NAME}" \
    && upx -9 "${BIN_PATH}/${BIN_NAME}"

FROM kube-base AS kubeval
RUN set -x; cd "$(mktemp -d)" \
    && ORG="instrumenta" \
    && BIN_NAME="kubeval" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLO ${GITHUB}/${REPO}/${RELEASE_DL}/v${VERSION}/${BIN_NAME}-${OS}-${ARCH}.tar.gz \
    && tar -zxvf ${BIN_NAME}-${OS}-${ARCH}.tar.gz \
    && mv ${BIN_NAME} ${BIN_PATH}/${BIN_NAME}

FROM kube-base AS helm-docs
RUN set -x; cd "$(mktemp -d)" \
    && ORG="norwoodj" \
    && BIN_NAME="helm-docs" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/' | sed 's/v//g')" \
    && curl -fsSLO ${GITHUB}/norwoodj/helm-docs/${RELEASE_DL}/v${VERSION}/${BIN_NAME}_${VERSION}_Linux_x86_64.tar.gz \
    && tar -zxvf ${BIN_NAME}_${VERSION}_Linux_x86_64.tar.gz \
    && mv ${BIN_NAME} ${BIN_PATH}/${BIN_NAME}

FROM kube-base AS istio
RUN set -x; cd "$(mktemp -d)" \
    && BIN_NAME="istioctl" \
    && curl -L https://istio.io/downloadIstio | sh - \
    && mv "$(ls | grep istio)/bin/${BIN_NAME}" ${BIN_PATH}/${BIN_NAME}

FROM kube-base AS kpt
RUN set -x; cd "$(mktemp -d)" \
    && curl -fsSLo ${BIN_PATH}/kpt ${GOOGLE}/kpt-dev/latest/${OS}_${ARCH}/kpt \
    && chmod a+x ${BIN_PATH}/kpt

FROM kube-base AS kustomize
RUN set -x; cd "$(mktemp -d)" \
    && ORG="kubernetes-sigs" \
    && BIN_NAME="kustomize" \
    && REPO="${ORG}/${BIN_NAME}" \
    && VERSION="$(curl --silent "${API_GITHUB}/${REPO}/${RELEASE_LATEST}" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')" \
    && curl -fsSLO ${GITHUB}/${REPO}/${ARCHIVE_DL}/${VERSION}.tar.gz \
    && tar -zxvf "$(echo ${VERSION} | sed -e 's/.*\/v/v/g')".tar.gz \
    && mv ${BIN_NAME}-"$(echo ${VERSION} | sed -e 's/\//-/g')" ${BIN_PATH}/${BIN_NAME}

FROM scratch AS kube

ENV BIN_PATH /usr/local/bin
ENV LIB_PATH /usr/local/libexec
ENV K8S_PATH /usr/k8s/bin
ENV K8S_LIB_PATH /usr/k8s/lib

COPY --from=helm ${BIN_PATH}/helm ${K8S_PATH}/helm
COPY --from=helm-docs ${BIN_PATH}/helm-docs ${K8S_PATH}/helm-docs
COPY --from=helmfile ${BIN_PATH}/helmfile ${K8S_PATH}/helmfile
COPY --from=istio ${BIN_PATH}/istioctl ${K8S_PATH}/istioctl
COPY --from=k9s ${BIN_PATH}/k9s ${K8S_PATH}/k9s
COPY --from=kind ${BIN_PATH}/kind ${K8S_PATH}/kind
COPY --from=kpt ${BIN_PATH}/kpt ${K8S_PATH}/kpt
COPY --from=krew /root/.krew/bin/kubectl-krew ${K8S_PATH}/kubectl-krew
COPY --from=kube-profefe ${BIN_PATH}/kprofefe ${K8S_PATH}/kprofefe
COPY --from=kube-profefe ${BIN_PATH}/kubectl-profefe ${K8S_PATH}/kubectl-profefe
COPY --from=kube-tree ${BIN_PATH}/kubectl-tree ${K8S_PATH}/kubectl-tree
COPY --from=kubebox ${BIN_PATH}/kubebox ${K8S_PATH}/kubebox
COPY --from=kubebuilder ${BIN_PATH}/kubebuilder ${K8S_PATH}/kubebuilder
COPY --from=kubectl ${BIN_PATH}/kubectl ${K8S_PATH}/kubectl
COPY --from=kubectl-fzf ${BIN_PATH}/kubectl-fzf-server ${K8S_PATH}/kubectl-fzf-server
COPY --from=kubectl-fzf ${BIN_PATH}/kubectl-fzf-completion ${K8S_PATH}/kubectl-fzf-completion
COPY --from=kubectx ${BIN_PATH}/kubectx ${K8S_PATH}/kubectx
COPY --from=kubectx ${BIN_PATH}/kubens ${K8S_PATH}/kubens
COPY --from=kubeval ${BIN_PATH}/kubeval ${K8S_PATH}/kubeval
COPY --from=kustomize ${BIN_PATH}/kustomize ${K8S_PATH}/kustomize
COPY --from=linkerd ${BIN_PATH}/linkerd ${K8S_PATH}/linkerd
COPY --from=skaffold ${BIN_PATH}/skaffold ${K8S_PATH}/skaffold
COPY --from=stern ${BIN_PATH}/stern ${K8S_PATH}/stern
COPY --from=telepresence ${BIN_PATH}/telepresence ${K8S_PATH}/telepresence
