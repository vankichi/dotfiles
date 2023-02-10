FROM vankichi/dev-base:latest AS dart-base

ENV FLUTTER_VERSION 3.7.3
ENV LOCAL /usr/local
ENV BIN_PATH ${LOCAL}/bin

FROM dart-base AS flutter
RUN set -x; cd "$(mktemp -d)" \
    && curl -fsSLO "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    && tar xf flutter_linux_${FLUTTER_VERSION}-stable.tar.xz \
    && mv flutter ${BIN_PATH}/flutter

FROM scratch AS dart

ENV BIN_PATH /usr/local/bin

COPY --from=flutter ${BIN_PATH}/flutter ${BIN_PATH}/flutter
