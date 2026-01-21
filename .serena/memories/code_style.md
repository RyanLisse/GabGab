# Code Style & Conventions

- Swift 6.2 package (`// swift-tools-version: 6.2`).
- 4-space indentation, Swift standard formatting (no explicit SwiftFormat/SwiftLint config found).
- Doc comments (`///`) used for public methods.
- Actor-based concurrency (e.g., `public actor GabGabSessionManager`).
- Prefer `async/await` with `URLSession.shared.data(for:)`.
- CLI uses ArgumentParser with `AsyncParsableCommand` and nested subcommands.
