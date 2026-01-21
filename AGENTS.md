# PROJECT KNOWLEDGE BASE

**Generated:** 2026-01-21 22:32:00 UTC  
**Commit:** 3e0fff5 (Rename project to GabGab and clean up repo)  
**Branch:** main

## OVERVIEW

Local-first macOS voice processing (TTS/STT) using MLX models. Three targets: `GabGab` library, `gabgab-cli` (ArgumentParser), `gabgab-mcp` (MCP server).

## STRUCTURE

```
./                      # Root
├── Sources/
│   ├── GabGab/         # Core library (MLXVoiceClient)
│   ├── GabGabCLI/      # CLI entry point
│   └── GabGabMCP/      # MCP server entry point
├── Tests/GabGabTests/  # Swift Testing suite
├── assets/             # Logo (not in SPM)
└── Package.swift       # SPM config (6.2, macOS 14+)
```

## WHERE TO LOOK

| Task | Location | Notes |
|------|----------|-------|
| Core logic | `Sources/GabGab/MLXVoiceClient.swift` | `GabGabSessionManager` actor |
| CLI commands | `Sources/GabGabCLI/main.swift` | `AsyncParsableCommand` |
| MCP server | `Sources/GabGabMCP/main.swift` | stdio transport |
| Tests | `Tests/GabGabTests/MLXVoiceTests.swift` | Swift Testing (`@Test`, `#expect`) |

## CONVENTIONS

- **Swift 6.2** (`// swift-tools-version: 6.2`)
- **4-space indentation** (no formatter config)
- Doc comments (`///`) for public APIs
- **Actors** for stateful concurrency (`GabGabSessionManager`)
- **async/await** with `URLSession.shared.data(for:)`
- **Swift Testing**: `@Test` macro, `#expect()` assertions

## ANTI-PATTERNS (THIS PROJECT)

- **No CI/CD**: Missing `.github/workflows/` for automated builds
- **No linter**: No `.swiftformat`/`.swiftlint.yml` to enforce style
- **Manual install**: Docs show `cp` to `/usr/local/bin/` (could use Makefile)
- **Assets outside SPM**: `assets/logo.png` not declared in `Package.swift`

## UNIQUE STYLES

- **Serena meta-files**: `.serena/` memories, `SKILL.md` for agent integration
- **Mixed naming**: PascalCase targets (`GabGabCLI`) → kebab-case binaries (`gabgab-cli`)
- **Python fallback**: `voice_router.py` for TTS/STT when MLX server unavailable

## COMMANDS

```bash
swift build              # Debug
swift build -c release   # Release
swift test              # Swift Testing
swift run gabgab-cli tts "hello" --output hello.wav
swift run gabgab-mcp
```

## NOTES

- Project recently moved from `GabGab/` subdirectory to root (git state transitional)
- Single large file: `MLXVoiceClient.swift` (199 lines) - candidate for refactoring
- MCP server uses stdio transport for AI agent integration
