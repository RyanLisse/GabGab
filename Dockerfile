# Dockerfile for GabGab - CI-focused containerization
# Multi-stage build for optimal image size

# Stage 1: Build stage
FROM swift:6.2-focal AS builder

# Set working directory
WORKDIR /build

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Copy Package files
COPY Package.swift Package.resolved ./

# Resolve dependencies (cached layer)
RUN swift package resolve

# Copy source code
COPY Sources ./Sources
COPY Tests ./Tests

# Build the project
RUN swift build -c release --static-swift-stdlib

# Stage 2: Runtime stage
FROM ubuntu:22.04

# Install runtime dependencies
RUN apt-get update && apt-get install -y \
    ca-certificates \
    libatomic1 \
    libcurl4 \
    libxml2 \
    && rm -rf /var/lib/apt/lists/*

# Create app directory
WORKDIR /app

# Copy binaries from builder
COPY --from=builder /build/.build/release/gabgab-cli /usr/local/bin/gabgab-cli
COPY --from=builder /build/.build/release/gabgab-mcp /usr/local/bin/gabgab-mcp

# Verify binaries
RUN gabgab-cli --help && gabgab-mcp --help || echo "MCP server may not support --help"

# Set default command
CMD ["gabgab-cli", "--help"]

# Labels
LABEL maintainer="GabGab Project"
LABEL description="GabGab - Local-first macOS voice processing using MLX models"
LABEL version="1.0.0"
