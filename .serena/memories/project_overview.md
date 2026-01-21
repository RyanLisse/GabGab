# Project Overview

- **Name**: GabGab
- **Purpose**: Local-first macOS voice processing (TTS/STT) using MLX models with CLI + MCP server.
- **Platform**: macOS 14.0+ (Apple Silicon recommended)
- **Language/Tooling**: Swift 6.2, Swift Package Manager
- **Key Executables**: `gabgab-cli`, `gabgab-mcp`
- **Core Library Target**: `GabGab`
- **Dependencies**: `apple/swift-argument-parser` (CLI)
- **Architecture**: Core actor `GabGabSessionManager` handles TTS/STT and fallbacks.
- **Repo Structure**:
  - `GabGab/Sources/GabGab` (core library)
  - `GabGab/Sources/GabGabCLI` (CLI)
  - `GabGab/Sources/GabGabMCP` (MCP server)
  - `GabGab/Tests/GabGabTests`
  - `GabGab/Package.swift`
