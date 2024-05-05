.PHONY: version/all
version/all: \
	version/go \
	version/ngt \
	version/tensorflow

.PHONY: version/go
## version/go
version/go:
	@curl --silent https://go.dev/VERSION?m=text | head -n 1 | sed -e 's/go//g' > $(ROOTDIR)/versions/GO_VERSION


.PHONY: verison/ngt
## version/ngt
version/ngt:
	@curl --silent https://api.github.com/repos/yahoojapan/NGT/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/v//g' > $(ROOTDIR)/versions/NGT_VERSION

.PHONY: version/tensorflow
## version/tensorflow
version/tensorflow:
	@curl --silent https://api.github.com/repos/tensorflow/tensorflow/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/v//g' > $(ROOTDIR)/versions/TENSORFLOW_C_VERSION

.PHONY: version/flutter
## version/flutter
version/flutter:
	@$(eval HASH := $(shell curl --silent https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json | jq -c '.current_release.stable'))
	@curl --silent https://storage.googleapis.com/flutter_infra_release/releases/releases_linux.json | jq -c -r '.releases[] | select (.channel == "stable") | select (.hash == ${HASH}).version' > $(ROOTDIR)/versions/FLUTTER_VERSION

