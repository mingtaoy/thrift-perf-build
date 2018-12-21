DOCKER ?= docker

all: fbcode-image

fbcode-image:
	$(DOCKER) build -t mingtaoy/fbcode-thrift -f Dockerfile .

.PHONY: all fbcode-image
