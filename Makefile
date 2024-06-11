SERVICE = go-svc-template
ARCH = $(shell uname -m)
VERSION ?= $(shell git rev-parse --short=8 HEAD)

GO = CGO_ENABLED=$(CGO_ENABLED) GOFLAGS=-mod=vendor go
CGO_ENABLED ?= 0
GO_BUILD_FLAGS = -ldflags "-X main.version=${VERSION}"

# Pattern #1 example: "example : description = Description for example target"
# Pattern #2 example: "### Example separator text
help: HELP_SCRIPT = \
	if (/^([a-zA-Z0-9-\.\/]+).*?: description\s*=\s*(.+)/) { \
		printf "\033[34m%-40s\033[0m %s\n", $$1, $$2 \
	} elsif(/^\#\#\#\s*(.+)/) { \
		printf "\033[33m>> %s\033[0m\n", $$1 \
	}

.PHONY: help
help:
	@perl -ne '$(HELP_SCRIPT)' $(MAKEFILE_LIST)

### Dev

.PHONY: setup/linux
setup/linux: description = Install dev tools for linux
setup/linux:
	GO111MODULE=off go get github.com/maxbrunsfeld/counterfeiter

.PHONY: setup/darwin
setup/darwin: description = Install dev tools for darwin
setup/darwin:
	GO111MODULE=off go get github.com/maxbrunsfeld/counterfeiter
	brew install doctl

.PHONY: run
run: description = Run $(SERVICE)
run:
	$(GO) run `ls -1 *.go | grep -v _test.go`

.PHONY: start/deps
start/deps: description = Start dependenciesgit
start/deps:
	docker-compose up -d rabbitmq

### Build

.PHONY: build/linux-amd64
build/linux-amd64: description = Build service for linux-amd64
build/linux-amd64: clean
	GOOS=linux GOARCH=amd64 $(GO) build $(GO_BUILD_FLAGS) -o ./build/$(SERVICE)-linux-amd64

.PHONY: build/linux-x86_64
build/linux-x86_64: description = Build service for linux-x86_64
build/linux-x86_64: clean
	GOOS=linux GOARCH=amd64 $(GO) build $(GO_BUILD_FLAGS) -o ./build/$(SERVICE)-linux-amd64

.PHONY: build/linux-arm64
build/linux-arm64: description = Build service for linux-arm64
build/linux-arm64: clean
	GOOS=linux GOARCH=arm64 $(GO) build $(GO_BUILD_FLAGS) -o ./build/$(SERVICE)-linux-arm64

.PHONY: build/darwin-amd64
build/darwin-amd64: description = Build service for darwin-amd64
build/darwin-amd64: clean
	GOOS=darwin GOARCH=amd64 $(GO) build $(GO_BUILD_FLAGS) -o ./build/$(SERVICE)-darwin-amd64

.PHONY: build/darwin-arm64
build/darwin-arm64: description = Build service for darwin-arm64
build/darwin-arm64: clean
	GOOS=darwin GOARCH=arm64 $(GO) build $(GO_BUILD_FLAGS) -o ./build/$(SERVICE)-darwin-arm64

.PHONY: clean
clean: description = Remove existing build artifacts
clean:
	$(RM) ./build/$(SERVICE)-*

### Test

.PHONY: test
test: description = Run Go unit tests
test: GOFLAGS=
test:
	$(GO) test ./...

.PHONY: testv
testv: description = Run Go unit tests (verbose)
testv: GOFLAGS=
testv:
	$(GO) test ./... -v

.PHONY: test/coverage
test/coverage: description = Run Go unit tests
test/coverage: GOFLAGS=
test/coverage:
	$(GO) test ./... -coverprofile c.out

### Docker

.PHONY: docker/build
docker/build: description = Build docker image (you must be authenticated to DO registry)
docker/build:
	docker buildx build --push --platform=linux/amd64 --build-arg VERSION=$(VERSION) \
	-t registry.digitalocean.com/your_org/$(SERVICE):$(VERSION) \
	-t registry.digitalocean.com/your_org/$(SERVICE):latest \
	-f ./Dockerfile .

.PHONY: docker/run
docker/run: description = Build and run container + deps via docker-compose
docker/run:
	docker-compose up -d

### Kubernetes

.PHONY: k8s/deploy/stage
k8s/deploy/stage: description = Deploy to staging
k8s/deploy/stage:
	cat deploy.stage.yml | \
	sed "s/{{VERSION}}/$(VERSION)/g" | \
	sed "s/{{SERVICE}}/$(SERVICE)/g" | \
	kubectl apply -f -

.PHONY: k8s/deploy/prod
k8s/deploy/prod: description = Deploy to production
k8s/deploy/prod:
	cat deploy.prod.yml | \
	sed "s/{{VERSION}}/$(VERSION)/g" | \
	sed "s/{{SERVICE}}/$(SERVICE)/g" | \
	kubectl apply -f -
