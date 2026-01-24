# GabGab LanceDB POC

A proof-of-concept demonstrating LanceDB for multimodal voice data storage in GabGab.

## Quick Start

```bash
# Install dependencies
pip install -r requirements.txt

# Run the demo
python gabgab_lancedb_poc.py
```

## What This Demonstrates

1. **Multimodal Storage**: Audio, transcripts, and embeddings in one table
2. **Semantic Search**: Find recordings by meaning, not keywords
3. **Versioning**: Schema evolution and time travel capabilities
4. **Local-First**: Zero cloud dependencies, privacy-preserving

## Files

- `gabgab_lancedb_poc.py` - Main demonstration script
- `requirements.txt` - Python dependencies
- `GABGAB_LANCEDB_POC.md` - Full documentation
- `README.md` - This file

## Example Output

```
🔍 Semantic search for: 'reminders and appointments'
------------------------------------------------------------

[1] gabgab-002
  Transcript: Remind me about the dentist appointment at 3 PM
  Model: kokoro-82m, Duration: 2800ms
  Speaker: user
  Timestamp: 2025-01-23 12:34:56.789
```

## Documentation

See [GABGAB_LANCEDB_POC.md](./GABGAB_LANCEDB_POC.md) for detailed documentation.
