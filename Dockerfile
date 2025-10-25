# Build stage
FROM golang:1.24-alpine AS builder

# Install dependencies
RUN apk add --no-cache git make gcc musl-dev linux-headers

# Set working directory
WORKDIR /app

# Copy go mod files
COPY go.mod go.sum ./

# Download dependencies
RUN go mod download

# Copy source code
COPY . .

# Build the binary
RUN make install

# Runtime stage
FROM alpine:latest

# Install runtime dependencies
RUN apk add --no-cache ca-certificates bash curl jq

# Create app user
RUN addgroup -g 1000 pokerchain && \
    adduser -D -u 1000 -G pokerchain pokerchain

# Copy binary from builder
COPY --from=builder /go/bin/pokerchaind /usr/local/bin/pokerchaind

# Create data directory
RUN mkdir -p /home/pokerchain/.pokerchain && \
    chown -R pokerchain:pokerchain /home/pokerchain

# Switch to app user
USER pokerchain
WORKDIR /home/pokerchain

# Expose ports
# 26656: P2P
# 26657: RPC
# 1317: REST API
# 9090: gRPC
EXPOSE 26656 26657 1317 9090

# Set entrypoint
ENTRYPOINT ["pokerchaind"]
CMD ["start"]
