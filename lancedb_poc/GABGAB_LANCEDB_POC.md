# GabGab LanceDB POC - Multimodal Voice Data Storage

## Overview

This proof-of-concept demonstrates how **LanceDB** can enhance GabGab's voice processing capabilities by providing efficient multimodal storage, semantic search, and versioning for voice recordings.

## Why LanceDB for GabGab?

### 1. Multimodal Storage in One Table

Store everything in a single table:
- **Audio bytes**: The actual voice recording
- **Transcript**: The text transcription (STT output)
- **Embedding**: Vector representation for semantic search
- **Metadata**: Model used, duration, speaker, etc.

**Benefit**: No need for separate databases or file systems. Everything is queryable together.

### 2. Semantic Search by Meaning

Find recordings by what they *mean*, not just exact keyword matches:

```python
# Query: "reminders"
# Finds: "Remind me about the dentist appointment at 3 PM"
#        "Generate a daily briefing for the morning routine"

# Query: "scheduling"
# Finds: "Schedule a team meeting for next week Monday"
#        "Set a timer for 25 minutes for focused work"
```

**Benefit**: Natural language queries work even if words don't match exactly.

### 3. Schema Evolution & Versioning

- Add new columns without breaking existing data
- Time travel: query data as it was at any point
- Transactional updates: atomic modifications

**Benefit**: Safe, incremental upgrades as GabGab evolves.

### 4. Local-First & Privacy Preserving

- Zero cloud dependencies
- Full control over data
- Works offline

**Benefit**: Aligns with GabGab's privacy-first philosophy.

## Installation

```bash
# Navigate to the POC directory
cd /Volumes/Main\ SSD/Developer/GabGab/lancedb_poc

# Create a virtual environment (recommended)
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# Install dependencies
pip install -r requirements.txt
```

## Running the POC

```bash
# Run the full demonstration
python gabgab_lancedb_poc.py
```

This will:
1. Create a LanceDB database in `./gabgab_lancedb/`
2. Create a `recordings` table with the GabGab schema
3. Insert sample voice recordings
4. Demonstrate semantic search queries
5. Show versioning and schema evolution capabilities

## Schema Design

```python
Schema([
    id: string                    # Unique recording identifier
    timestamp: timestamp[us]      # When the recording was created
    audio_bytes: binary           # The audio data (optional, can be path)
    transcript: string            # STT transcription
    embedding: list[float32]      # Vector for semantic search (384 dims)
    model: string                 # Model used (kokoro-82m, lfm2.5, etc.)
    duration_ms: int32            # Duration in milliseconds
    speaker: string               # Optional speaker identification
    metadata: string              # JSON for extensibility
])
```

## Key Features Demonstrated

### 1. Semantic Search

```python
manager = GabGabLanceDB()

# Find recordings about reminders
results = manager.semantic_search("reminders and appointments")

# Filter by speaker
results = manager.semantic_search("system messages", speaker_filter="system")
```

**How it works**: The transcript is converted to an embedding vector using a sentence transformer. Queries are also converted to vectors, and similarity is computed using cosine similarity.

### 2. Versioning

```python
# Get current version
version = table.version

# Add new columns (schema evolution)
table.add(new_data_with_new_columns)

# Restore to previous version
old_table = db.open_table("recordings", version=old_version)

# Update existing data
table.update(where="quality_score is null", values={"quality_score": 3.8})
```

**Benefit**: Safe experimentation and rollback capabilities.

### 3. Multimodal Queries

```python
# Query by transcript content
df = table.to_pandas()
meetings = df[df["transcript"].str.contains("meeting", case=False)]

# Query by model type
kokoro_recordings = df[df["model"] == "kokoro-82m"]

# Query by duration range
long_recordings = df[df["duration_ms"] > 3000]
```

## Integration with GabGab

### Current GabGab Workflow

```
Voice Input → STT (Parakeet) → Transcript → Processing
Text Input → TTS (Kokoro/LFM) → Audio Output
```

### With LanceDB

```
Voice Input → STT (Parakeet) → Transcript → Store in LanceDB
                                        → Generate embedding
Text Input → Search LanceDB → Find similar recordings
                        → TTS (Kokoro/LFM) → Audio Output
```

### Example Use Cases

1. **Voice Journal**: Search past conversations by meaning
2. **Smart History**: Find previously generated speech to reuse
3. **Analytics**: Understand usage patterns by model, speaker, duration
4. **Personalization**: Learn user preferences from past interactions

## Performance Considerations

| Operation | Complexity | Notes |
|-----------|------------|-------|
| Insert | O(1) | Fast, with automatic indexing |
| Semantic Search | O(log n) | Uses IVF or HNSW indexes |
| Metadata Filter | O(n) | Can be optimized with materialized views |
| Full Scan | O(n) | Suitable for analytics |

**Indexing**: LanceDB automatically creates vector indices on the `embedding` column. For large datasets (>100K records), consider tuning index parameters.

## Future Enhancements

1. **Hybrid Search**: Combine semantic search with keyword filters
2. **Speaker Diarization**: Store multiple speakers per recording
3. **Audio Features**: Extract MFCCs, prosody features alongside embeddings
4. **Clustering**: Group similar recordings automatically
5. **Deduplication**: Detect and merge duplicate recordings

## Files

- `gabgab_lancedb_poc.py`: Main POC script
- `requirements.txt`: Python dependencies
- `GABGAB_LANCEDB_POC.md`: This documentation
- `./gabgab_lancedb/`: Database directory (created on first run)

## Dependencies

- **lancedb**: Core database functionality
- **pyarrow**: Columnar storage and Arrow IPC
- **sentence-transformers**: Embedding generation for semantic search
- **torch**: Backend for sentence transformers
- **numpy**: Array operations

## Troubleshooting

### Import Errors

```bash
# If you get "Module not found" errors
pip install --upgrade pip
pip install -r requirements.txt
```

### Vector Index Issues

LanceDB will automatically create indexes. For manual control:

```python
table.create_index(
    metric="cosine",
    num_partitions=256,
    num_sub_vectors=96
)
```

### Memory Issues

For large audio files, consider storing paths instead of bytes:

```python
# Instead of audio_bytes
audio_path: string  # Path to file on disk
```

## Next Steps

1. **Benchmark**: Test with real GabGab voice data
2. **Integrate**: Add to Swift code via Python interop or HTTP API
3. **Scale**: Test performance with 10K+ recordings
4. **Productionize**: Add backup/restore, monitoring, alerts

## Resources

- [LanceDB Documentation](https://lancedb.github.io/lancedb/)
- [Sentence Transformers](https://www.sbert.net/)
- [GabGab Project](../README.md)

---

**Created**: 2025-01-23
**Status**: Proof of Concept
**License**: Same as GabGab (MIT)
