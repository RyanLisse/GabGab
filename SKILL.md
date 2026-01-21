---
name: gabgab
description: Local-first voice processing (TTS/STT) for macOS using Apple MLX. Capable of generating high-quality speech from text and transcribing audio files locally without cloud dependencies.
version: 1.0.0
license: MIT
homepage: https://github.com/RyanLisse/GabGab
user-invocable: true
metadata:
  author: Ryan Lisse
  type: tool
---

# GabGab Voice Skill

This skill integrates GabGab's local voice capabilities into your agent workflow. It allows you to speak responses and transcribe audio input using optimized on-device models.

## Capabilities

### Text-to-Speech (TTS)

Generate speech from text using the `voice/generate_speech` tool.

- **Models**: Kokoro-82M (fast), LFM-2.5-Audio-1.5B (high quality).
- **Usage**: Use this when you need to "speak", "say", or generate audio output for the user.

### Speech-to-Text (STT)

Transcribe audio files using the `voice/transcribe_audio` tool.

- **Models**: Parakeet-0.6B (fast), Whisper Large v3 Turbo (high accuracy).
- **Usage**: Use this when the user provides an audio file or requests a transcription.

## Tools

- `voice/generate_speech`: Synthesize speech.
  - `text`: The text to speak.
  - `voice`: (Optional) Voice ID to use.
  - `output_path`: (Optional) Path to save output.

- `voice/transcribe_audio`: Transcribe audio.
  - `audio_path`: Path to the audio file.

- `voice/check_health`: Check if the voice server is running.

- `voice/list_voices`: Get a list of available voice profiles.

## Instructions

1. **Check Health**: Before heavy processing, you may check `voice/check_health` to ensure the local server is active.
2. **Generate Speech**:
    - When asked to "say" something, use `voice/generate_speech`.
    - Example: `voice/generate_speech(text="Hello world!", voice="af_heart")`
3. **Transcribe**:
    - When given an audio path, use `voice/transcribe_audio`.

## Troubleshooting

If the MCP tools are not available, ensure the `mlx-voice-mcp-server` is running on the host machine.
You can try to start it via the CLI if you have shell access: `mlx-voice-mcp-server`.
