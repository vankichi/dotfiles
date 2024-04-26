.PHONY: update/all
update/all: \
	update/go \
	update/ngt

.PHONY: update/go
## update/go
update/go:
	curl --silent https://go.dev/VERSION?m=text | head -n 1 | sed -e 's/go//g' > $(ROOTDIR)/versions/GO_VERSION


.PHONY: update/ngt
## update/ngt
update/ngt:
	curl --silent https://api.github.com/repos/yahoojapan/NGT/releases/latest | grep -Po '"tag_name": "\K.*?(?=")' | sed 's/v//g' > $(ROOTDIR)/versions/NGT_VERSION

