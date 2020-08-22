PROJECT_NAME=usersrv
BUILD_VERSION=$(shell cat VERSION)
DOCKER_IMAGE=$(PROJECT_NAME):$(BUILD_VERSION)
GO_BUILD_ENV=CGO_ENABLED=0 GOOS=linux GOARCH=amd64 GO111MODULE=on
GO_FILES=$(shell go list ./... | grep -v /vendor/)

# API settings
PROTO_ROOT_DIR = api/
DOC_DIR = github.com/pthethanh/usersrv/doc
PROTOC_VERSION = 3.10.1
GRPC_GATEWAY_VERSION = v1.14.6
PROTOBUF_VERSION= v1.4.2

PROTODIR := .
PROTOC := protoc
GOPATH ?= $(HOME)/go
PROTO_OUT = $(GOPATH)/src
DOC_OUT ?= $(PROTO_OUT)/$(DOC_DIR)
MOD=$(GOPATH)/pkg/mod
GRPC_GATEWAY_INCLUDES := $(MOD)/github.com/grpc-ecosystem/grpc-gateway@$(GRPC_GATEWAY_VERSION)/third_party/googleapis
PROTOC_INCLUDES := /usr/local/include
PROTOC_GEN_GO = $(GOPATH)/bin/protoc-gen-go
PROTOC_GEN_GRPC_GATEWAY = $(GOPATH)/bin/protoc-gen-grpc-gateway
PROTOC_GEN_SWAGGER = $(GOPATH)/bin/protoc-gen-swagger

.SILENT:

all: api mod_tidy fmt vet build test

build_test: mod_tidy fmt vet build test

vet:
	$(GO_BUILD_ENV) go vet $(GO_FILES)

fmt:
	$(GO_BUILD_ENV) go fmt $(GO_FILES)

test:
	$(GO_BUILD_ENV) go test $(GO_FILES) -cover -v

mod_tidy:
	$(GO_BUILD_ENV) go mod tidy

build:
	$(GO_BUILD_ENV) go build -v -o $(PROJECT_NAME)-$(BUILD_VERSION).bin .

install_protobuf:
	wget https://github.com/google/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-linux-x86_64.zip
	unzip protoc-$(PROTOC_VERSION)-linux-x86_64.zip -d protoc
	sudo cp protoc/bin/protoc /usr/local/bin
	sudo mkdir -p /usr/local/include
	sudo cp -R protoc/include/* /usr/local/include/
	rm -rf protoc
	rm -rf protoc-$(PROTOC_VERSION)-linux-x86_64.zip
	sudo chmod -R 755 /usr/local/include/
	sudo chmod +x /usr/local/bin/protoc

api: proto_go proto_gateway proto_swagger

proto: proto_go proto_gateway

$(PROTOC_GEN_GO):
	cd $(MOD)/github.com/golang/protobuf@${PROTOBUF_VERSION}/protoc-gen-go && go install

$(PROTOC_GEN_GRPC_GATEWAY):
	cd $(MOD)/github.com/grpc-ecosystem/grpc-gateway@$(GRPC_GATEWAY_VERSION)/protoc-gen-grpc-gateway && go install

$(PROTOC_GEN_SWAGGER):
	cd $(MOD)/github.com/grpc-ecosystem/grpc-gateway@$(GRPC_GATEWAY_VERSION)/protoc-gen-swagger && go install

proto_go: $(PROTOC_GEN_GO)
	@ if ! which $(PROTOC) > /dev/null; then \
		echo "error: protoc not installed" >&2; \
		exit 1; \
	fi
	for dir in $$(find . -name '*.proto' -exec dirname '{}' ';' |  grep $(PROTO_ROOT_DIR) | sort -u); do \
		$(PROTOC) -I $(PROTOC_INCLUDES) -I $(GRPC_GATEWAY_INCLUDES) -I $(PROTODIR) --plugin=protoc-gen-go=$(PROTOC_GEN_GO) --go_out=plugins=grpc:$(PROTO_OUT) $$dir/*.proto || exit 1; \
	done

proto_gateway: $(PROTOC_GEN_GRPC_GATEWAY)
	@ if ! which $(PROTOC) > /dev/null; then \
		echo "error: protoc not installed" >&2; \
		exit 1; \
	fi
	for dir in $$(find . -name '*.proto' -exec dirname '{}' ';' | grep $(PROTO_ROOT_DIR) | sort -u); do \
		$(PROTOC) -I $(PROTOC_INCLUDES) -I $(GRPC_GATEWAY_INCLUDES) -I $(PROTODIR) --plugin=protoc-gen-grpc-gateway=$(PROTOC_GEN_GRPC_GATEWAY) --grpc-gateway_out=logtostderr=true:$(PROTO_OUT) $$dir/*.proto || exit 1; \
	done

proto_swagger: $(PROTOC_GEN_SWAGGER)
	@ if ! which $(PROTOC) > /dev/null; then \
		echo "error: protoc not installed" >&2; \
		exit 1; \
	fi
	for dir in $$(find . -name '*.proto' -exec dirname '{}' ';' | grep $(PROTO_ROOT_DIR) | sort -u); do \
		$(PROTOC) -I $(PROTOC_INCLUDES) -I $(GRPC_GATEWAY_INCLUDES) -I $(PROTODIR) --plugin=protoc-gen-swagger=$(PROTOC_GEN_SWAGGER) --swagger_out=logtostderr=true:$(DOC_OUT) $$dir/*.proto || exit 1; \
	done

_docker_prebuild: vet test build
	mkdir -p deployment/docker/web
	mv $(PROJECT_NAME)-$(BUILD_VERSION).bin deployment/docker/$(PROJECT_NAME).bin; \
	cp -R web deployment/docker/web/;

_docker_build:
	cd deployment/docker; \
	docker build -t $(DOCKER_IMAGE) .

_docker_postbuild:
	cd deployment/docker; \
	rm -rf $(PROJECT_NAME).bin 2> /dev/null;\
	rm -rf web 2> /dev/null;

docker_build: _docker_prebuild _docker_build _docker_postbuild

docker:
	docker run -p 8000:8000 $(DOCKER_IMAGE)

compose: docker
	cd deployment/docker && docker-compose up

_heroku_predeploy:
	cd deployment/docker; \
	heroku container:login; \
	heroku container:push web --app usersrv; \
	heroku container:release web --app usersrv; \
	heroku open --app usersrv

heroku: _docker_prebuild _heroku_predeploy _docker_postbuild

