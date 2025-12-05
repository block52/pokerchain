BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT := $(shell git log -1 --format='%H')
APPNAME := pokerchain

# Detect architecture
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Set OS
ifeq ($(UNAME_S),Linux)
	OS := linux
endif
ifeq ($(UNAME_S),Darwin)
	OS := darwin
endif

# Set ARCH
ifeq ($(UNAME_M),x86_64)
	ARCH := amd64
endif
ifeq ($(UNAME_M),aarch64)
	ARCH := arm64
endif
ifeq ($(UNAME_M),arm64)
	ARCH := arm64
endif

# Default to amd64 if not detected
ifeq ($(ARCH),)
	ARCH := amd64
endif

# # do not override user values
# ifeq (,$(VERSION))
#   VERSION := $(shell git describe --exact-match 2>/dev/null)
#   # if VERSION is empty, then populate it with branch name and raw commit hash
#   ifeq (,$(VERSION))
#     VERSION := $(BRANCH)-$(COMMIT)
#   endif
# endif
VERSION := v0.1.23

# Update the ldflags with the app, client & server names
ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=$(APPNAME) \
	-X github.com/cosmos/cosmos-sdk/version.AppName=$(APPNAME)d \
	-X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
	-X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT)

BUILD_FLAGS := -ldflags '$(ldflags)'

# Build output directory
BUILD_DIR := ./build

##############
###  Info  ###
##############

info:
	@echo "Detected System Information:"
	@echo "  OS:           $(OS)"
	@echo "  Architecture: $(ARCH)"
	@echo "  Version:      $(VERSION)"
	@echo "  Branch:       $(BRANCH)"
	@echo "  Commit:       $(COMMIT)"
	@echo ""
	@echo "Build will create: $(APPNAME)d"

.PHONY: info

##############
###  Test  ###
##############

test-unit:
	@echo Running unit tests...
	@go test -mod=readonly -v -timeout 30m ./...

test-race:
	@echo Running unit tests with race condition reporting...
	@go test -mod=readonly -v -race -timeout 30m ./...

test-cover:
	@echo Running unit tests and creating coverage report...
	@go test -mod=readonly -v -timeout 30m -coverprofile=$(COVER_FILE) -covermode=atomic ./...
	@go tool cover -html=$(COVER_FILE) -o $(COVER_HTML_FILE)
	@rm $(COVER_FILE)

bench:
	@echo Running unit tests with benchmarking...
	@go test -mod=readonly -v -timeout 30m -bench=. ./...

test: govet govulncheck test-unit

.PHONY: test test-unit test-race test-cover bench

#################
###  Build    ###
#################

build:
	@echo "--> Building $(APPNAME)d for $(OS)/$(ARCH)"
	@mkdir -p $(BUILD_DIR)
	@GOOS=$(OS) GOARCH=$(ARCH) go build $(BUILD_FLAGS) -mod=readonly -o $(BUILD_DIR)/$(APPNAME)d ./cmd/$(APPNAME)d
	@echo "--> Binary created at $(BUILD_DIR)/$(APPNAME)d"

build-linux-amd64:
	@echo "--> Building $(APPNAME)d for linux/amd64"
	@mkdir -p $(BUILD_DIR)
	@GOOS=linux GOARCH=amd64 go build $(BUILD_FLAGS) -mod=readonly -o $(BUILD_DIR)/$(APPNAME)d-linux-amd64 ./cmd/$(APPNAME)d

build-linux-arm64:
	@echo "--> Building $(APPNAME)d for linux/arm64"
	@mkdir -p $(BUILD_DIR)
	@GOOS=linux GOARCH=arm64 go build $(BUILD_FLAGS) -mod=readonly -o $(BUILD_DIR)/$(APPNAME)d-linux-arm64 ./cmd/$(APPNAME)d

build-darwin-amd64:
	@echo "--> Building $(APPNAME)d for darwin/amd64"
	@mkdir -p $(BUILD_DIR)
	@GOOS=darwin GOARCH=amd64 go build $(BUILD_FLAGS) -mod=readonly -o $(BUILD_DIR)/$(APPNAME)d-darwin-amd64 ./cmd/$(APPNAME)d

build-darwin-arm64:
	@echo "--> Building $(APPNAME)d for darwin/arm64"
	@mkdir -p $(BUILD_DIR)
	@GOOS=darwin GOARCH=arm64 go build $(BUILD_FLAGS) -mod=readonly -o $(BUILD_DIR)/$(APPNAME)d-darwin-arm64 ./cmd/$(APPNAME)d

build-all: build-linux-amd64 build-linux-arm64 build-darwin-amd64 build-darwin-arm64
	@echo "--> All platform binaries built"

.PHONY: build build-linux-amd64 build-linux-arm64 build-darwin-amd64 build-darwin-arm64 build-all

#################
###  Install  ###
#################

all: install

install:
	@echo "--> ensure dependencies have not been modified"
	@go mod verify
	@echo "--> installing $(APPNAME)d for $(OS)/$(ARCH)"
	@GOOS=$(OS) GOARCH=$(ARCH) go install $(BUILD_FLAGS) -mod=readonly ./cmd/$(APPNAME)d
	@echo "--> pokerchaind installed successfully to $(shell go env GOPATH)/bin/$(APPNAME)d"

clean:
	@echo "--> cleaning build cache and binaries"
	@go clean -cache
	@go clean -modcache 2>/dev/null || true
	@rm -rf $(BUILD_DIR)
	@rm -f $(shell go env GOPATH)/bin/$(APPNAME)d 2>/dev/null || true
	@echo "Build cache and binaries cleaned"

clean-state:
	@echo "--> removing chain data and state files"
	rm -rf $$HOME/.pokerchain/data
	rm -f $$HOME/.pokerchain/config/genesis.json
	@echo "Chain state cleaned"

init-local-validator:
	@echo "--> copying genesis file for local validator"
	mkdir -p $$HOME/.pokerchain/config
	cp ./genesis.json $$HOME/.pokerchain/config/genesis.json
	@echo "--> ensuring priv_validator_state.json exists"
	mkdir -p $$HOME/.pokerchain/data
	if [ ! -f $$HOME/.pokerchain/data/priv_validator_state.json ]; then \
		cp ./priv_validator_state_template.json $$HOME/.pokerchain/data/priv_validator_state.json; \
	fi
	@echo "Local validator initialized"

.PHONY: all install clean clean-state init-local-validator

##################
###  Protobuf  ###
##################

# Use this target if you do not want to use Ignite for generating proto files

proto-deps:
	@echo "Installing proto deps"
	@echo "Proto deps present, run 'go tool' to see them"

proto-gen:
	@echo "Generating protobuf files..."
	@ignite generate proto-go --yes

.PHONY: proto-gen

#################
###  Linting  ###
#################

lint:
	@echo "--> Running linter"
	@go tool github.com/golangci-lint-lint/cmd/golangci-lint run ./... --timeout 15m

lint-fix:
	@echo "--> Running linter and fixing issues"
	@go tool github.com/golangci-lint-lint/cmd/golangci-lint run ./... --fix --timeout 15m

.PHONY: lint lint-fix

###################
### Development ###
###################

govet:
	@echo Running go vet...
	@go vet ./...

govulncheck:
	@echo Running govulncheck...
	@go tool golang.org/x/vuln/cmd/govulncheck@latest
	@govulncheck ./...

.PHONY: govet govulncheck

# Docker targets

docker-build:
	docker build -t pokerchain:latest .

docker-run:
	docker run --rm -it \
	  -p 26656:26656 -p 26657:26657 -p 1317:1317 -p 9090:9090 \
	  -v pokerchain-data:/home/pokerchain/.pokerchain \
	  -v $(PWD)/genesis.json:/home/pokerchain/.pokerchain/config/genesis.json:ro \
	  -v $(PWD)/config.toml:/home/pokerchain/.pokerchain/config/config.toml:ro \
	  -v $(PWD)/app.toml:/home/pokerchain/.pokerchain/config/app.toml:ro \
	  -e POKERCHAIND_MINIMUM_GAS_PRICES=0.01b52Token \
	  --name pokerchain-node pokerchain:latest

docker-compose-up:
	docker compose up --build

docker-compose-down:
	docker compose down

.PHONY: docker-build docker-run docker-compose-up docker-compose-down

###################
### Testnet     ###
###################

testnet-setup:
	@echo "--> Setting up testnet (this will build the binary first)"
	@./scripts/setup-testnet.sh 4 pokerchaind pokerchain-testnet-1

testnet-start:
	@echo "--> Starting testnet"
	@./scripts/manage-testnet.sh start

testnet-stop:
	@echo "--> Stopping testnet"
	@./scripts/manage-testnet.sh stop

testnet-status:
	@echo "--> Testnet status"
	@./scripts/manage-testnet.sh status

testnet-clean:
	@echo "--> Cleaning testnet data"
	@rm -rf ./testnet
	@echo "Testnet data removed"

.PHONY: testnet-setup testnet-start testnet-stop testnet-status testnet-clean