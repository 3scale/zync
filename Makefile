.PHONY: build push help
.DEFAULT_GOAL := help

IMAGE_NAME := quay.io/3scale/zync
TAG := latest
IMAGE_TAG := $(IMAGE_NAME):$(TAG)

build:
	docker build . --tag $(IMAGE_TAG)

push:
	docker push $(IMAGE_TAG)

help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
