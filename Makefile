BRANCH := $(shell git rev-parse --abbrev-ref HEAD)
COMMIT := $(shell git log -1 --format='%H')
APPNAME := pokerchain

# # do not override user values
# ifeq (,$(VERSION))
#   VERSION := $(shell git describe --exact-match 2>/dev/null)
#   # if VERSION is empty, then populate it with branch name and raw commit hash
#   ifeq (,$(VERSION))
#     VERSION := $(BRANCH)-$(COMMIT)
#   endif
# endif
VERSION := v0.1.0

# Update the ldflags with the app, client & server names
ldflags = -X github.com/cosmos/cosmos-sdk/version.Name=$(APPNAME) \
	-X github.com/cosmos/cosmos-sdk/version.AppName=$(APPNAME)d \
	-X github.com/cosmos/cosmos-sdk/version.Version=$(VERSION) \
	-X github.com/cosmos/cosmos-sdk/version.Commit=$(COMMIT)

BUILD_FLAGS := -ldflags '$(ldflags)'

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
###  Install  ###
#################

all: install

install:
		@echo "--> ensure dependencies have not been modified"
		@go mod verify
		@echo "--> installing $(APPNAME)d"
		@go install $(BUILD_FLAGS) -mod=readonly ./cmd/$(APPNAME)d
		@echo "--> pokerchaind installed successfully"

clean:
	@echo "--> cleaning build cache and binaries"
	@go clean -cache
	@go clean -modcache 2>/dev/null || true
	@rm -f $(shell go env GOPATH)/bin/$(APPNAME)d 2>/dev/null || true
	@echo "Build cache and binaries cleaned"

clean-state:
	@echo "--> removing chain data and state files"
	rm -rf $$HOME/.pokerchain/data
	rm -f $$HOME/.pokerchain/config/genesis.json
	@echo "Chain state cleaned"

init-local-validator:
	@echo "--> copying minimal genesis file for local validator"
	mkdir -p $$HOME/.pokerchain/config
	cp ./genesis-minimal-b52Token.json $$HOME/.pokerchain/config/genesis.json
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
	  -v $(PWD)/genesis-minimal-b52Token.json:/home/pokerchain/.pokerchain/config/genesis.json:ro \
	  -v $(PWD)/config.toml:/home/pokerchain/.pokerchain/config/config.toml:ro \
	  -v $(PWD)/app.toml:/home/pokerchain/.pokerchain/config/app.toml:ro \
	  -e POKERCHAIND_MINIMUM_GAS_PRICES=0.01b52Token \
	  --name pokerchain-node pokerchain:latest

docker-compose-up:
	docker compose up --build

docker-compose-down:
	docker compose down

.PHONY: docker-build docker-run docker-compose-up docker-compose-down