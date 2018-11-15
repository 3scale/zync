.PHONY: all secrets imagestream buildconfig deploy service route hpa help
.DEFAULT_GOAL := help

MKFILE_PATH := $(abspath $(lastword $(MAKEFILE_LIST)))
THISDIR_PATH := $(patsubst %/,%,$(abspath $(dir $(MKFILE_PATH))))

all: secrets imagestream buildconfig deploy service route hpa

secrets: ## Create the secrets. Parameters: BUGSNAG_API_KEY, DB_URL, DB_NAME, DB_USER, DB_PASSWORD, DB_PORT, SECRET_KEY_BASE, SKYLIGHT_AUTHENTICATION, ZYNC_AUTHENTICATION_TOKEN.
	oc new-app -f $(THISDIR_PATH)/00-secrets-template.yml \
		-p BUGSNAG_API_KEY=${BUGSNAG_API_KEY} \
		-p DB_URL=${DB_URL} \
		-p DB_NAME=${DB_NAME} \
		-p DB_USER=${DB_USER} \
		-p DB_PASSWORD=${DB_PASSWORD} \
		-p DB_PORT=${DB_PORT} \
		-p SECRET_KEY_BASE=${SECRET_KEY_BASE} \
		-p SKYLIGHT_AUTHENTICATION=${SKYLIGHT_AUTHENTICATION} \
		-p ZYNC_AUTHENTICATION_TOKEN=${ZYNC_AUTHENTICATION_TOKEN}

imagestream: ## Create the Imagestreams.
	oc create -f $(THISDIR_PATH)/01-zync-imagestream.yml
	oc create -f $(THISDIR_PATH)/02-ruby-24-centos7-imagestream.yml

buildconfig: ## Create the BuildConfigs.
	oc new-app -f $(THISDIR_PATH)/03-buildconfig-template.yml

deploy: ## Create the DeploymentConfig.
	oc new-app -f $(THISDIR_PATH)/04-deploymentconfig-template.yml

service: ## Create the Services. Parameters: ZYNC_EXTERNAL_DB_HOST.
	oc new-app -f $(THISDIR_PATH)/05-services-template.yml \
		-p ZYNC_EXTERNAL_DB_HOST=${ZYNC_EXTERNAL_DB_HOST}

route: ## Create the Routes.Parameters: HOST.
	oc new-app -f $(THISDIR_PATH)/06-route-template.yml \
		-p HOST=${HOST}
hpa: ## Create the HPA.
	oc create -f $(THISDIR_PATH)/07-zync-hpa.yml

help: ## Print this help
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)
