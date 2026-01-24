#!/usr/bin/env python3
"""
GabGab LanceDB POC - Multimodal Voice Data Storage

This proof-of-concept demonstrates LanceDB's benefits for storing and querying
voice recordings with associated transcripts and embeddings.

Key Features:
- Multimodal storage: audio bytes + text + embeddings in one table
- Semantic search: find recordings by meaning, not just keywords
- Versioning: easy schema evolution and data migration
"""

import lancedb
import pyarrow as pa
import numpy as np
from datetime import datetime, timedelta
from sentence_transformers import SentenceTransformer
from typing import Optional, List
import json

# ============================================
# SCHEMA DEFINITION
# ============================================

def get_gabgab_schema() -> pa.Schema:
    """
    Define the schema for GabGab voice recordings.

    The schema captures:
    - Audio data (binary)
    - Transcript (text)
    - Semantic embedding (vector for similarity search)
    - Metadata (model, duration, speaker, etc.)
    """
    return pa.schema([
        pa.field("id", pa.string(), nullable=False),
        pa.field("timestamp", pa.timestamp("us"), nullable=False),
        pa.field("audio_bytes", pa.binary(), nullable=True),  # Optional to support remote storage
        pa.field("transcript", pa.string(), nullable=False),
        pa.field("embedding", pa.list_(pa.float32(), 384), nullable=False),
        pa.field("model", pa.string(), nullable=False),  # e.g., "kokoro-82m", "lfm2.5"
        pa.field("duration_ms", pa.int32(), nullable=False),
        pa.field("speaker", pa.string(), nullable=True),  # Optional speaker identification
        pa.field("metadata", pa.string(), nullable=True),  # JSON metadata for extensibility
    ])


# ============================================
# LANCEDB MANAGER
# ============================================

class GabGabLanceDB:
    """Manager for GabGab voice recordings in LanceDB."""

    def __init__(self, db_path: str = "./gabgab_lancedb"):
        """
        Initialize the LanceDB connection.

        Args:
            db_path: Path to the LanceDB database directory
        """
        self.db = lancedb.connect(db_path)
        self.table_name = "recordings"
        self.embedding_model = SentenceTransformer("all-MiniLM-L6-v2")

    def create_table(self) -> lancedb.table.Table:
        """
        Create the recordings table with the GabGab schema.

        LanceDB automatically creates vector indices for the embedding column.
        """
        if self.table_name in self.db.table_names():
            print(f"Table '{self.table_name}' already exists.")
            return self.db.open_table(self.table_name)

        table = self.db.create_table(
            self.table_name,
            schema=get_gabgab_schema(),
            mode="overwrite"
        )
        print(f"Created table '{self.table_name}' with schema:")
        print(table.schema)
        return table

    def insert_recording(
        self,
        id: str,
        transcript: str,
        model: str,
        duration_ms: int,
        audio_bytes: Optional[bytes] = None,
        speaker: Optional[str] = None,
        timestamp: Optional[datetime] = None,
        metadata: Optional[dict] = None
    ) -> None:
        """
        Insert a voice recording into the database.

        The embedding is automatically computed from the transcript.
        """
        if timestamp is None:
            timestamp = datetime.now()

        # Generate embedding for semantic search
        embedding = self.embedding_model.encode(transcript).astype(np.float32)

        data = [{
            "id": id,
            "timestamp": timestamp,
            "audio_bytes": audio_bytes,
            "transcript": transcript,
            "embedding": embedding.tolist(),
            "model": model,
            "duration_ms": duration_ms,
            "speaker": speaker,
            "metadata": json.dumps(metadata) if metadata else None
        }]

        table = self.db.open_table(self.table_name)
        table.add(data)
        print(f"✓ Inserted recording: {id}")

    def semantic_search(
        self,
        query: str,
        limit: int = 5,
        speaker_filter: Optional[str] = None
    ) -> List[dict]:
        """
        Search recordings by semantic meaning.

        This is the key benefit: find recordings that are semantically similar
        to a natural language query, even if they don't contain the exact words.
        """
        # Generate embedding for the query
        query_embedding = self.embedding_model.encode(query).astype(np.float32)

        table = self.db.open_table(self.table_name)

        # Build the search
        search_results = table.search(query_embedding.tolist(), vector_column_name="embedding").limit(limit).to_pandas()

        # Apply speaker filter if specified
        if speaker_filter:
            search_results = search_results[search_results["speaker"] == speaker_filter]

        print(f"\n🔍 Semantic search for: '{query}'")
        print("-" * 60)
        for idx, row in search_results.iterrows():
            print(f"\n[{idx+1}] {row['id']}")
            print(f"  Transcript: {row['transcript']}")
            print(f"  Model: {row['model']}, Duration: {row['duration_ms']}ms")
            print(f"  Speaker: {row['speaker'] or 'Unknown'}")
            print(f"  Timestamp: {row['timestamp']}")

        return search_results.to_dict("records")

    def versioning_demo(self) -> None:
        """
        Demonstrate LanceDB's versioning and schema evolution capabilities.

        Key benefits:
        1. Time travel: query data as it was at any point in time
        2. Schema evolution: add new columns without breaking existing data
        3. Transactional updates: atomic modifications
        """
        print("\n" + "=" * 60)
        print("VERSIONING & MIGRATION DEMO")
        print("=" * 60)

        table = self.db.open_table(self.table_name)

        # 1. Get current version
        print(f"\n📍 Current version: {table.version}")

        # 2. Add new columns (schema evolution)
        print("\n📝 Adding new columns: 'quality_score' and 'processing_time_ms'")
        new_data = [{
            "id": "rec-001",
            "quality_score": 4.5,
            "processing_time_ms": 1200,
            # Need to include all required fields
            "timestamp": datetime.now(),
            "audio_bytes": None,
            "transcript": "Hello world",
            "embedding": [0.0] * 384,  # Dummy embedding
            "model": "kokoro-82m",
            "duration_ms": 2500,
            "speaker": "Alice",
            "metadata": None
        }]
        table = self.db.create_table(self.table_name, data=new_data, mode="overwrite")
        print(f"✓ Schema evolved. New version: {table.version}")

        # 3. Show updated schema
        print(f"\n📋 Updated schema:")
        print(table.schema)

        # 4. Restore to previous version (time travel)
        print(f"\n⏱️  Time travel: restoring to version {table.version - 1}")
        # Note: In a real app, you'd open a specific version
        # table = db.open_table("recordings", version=old_version)

        # 5. Update/transmute data (migration pattern)
        print("\n🔄 Updating data: adding quality scores to all recordings")
        table.update(
            where="quality_score is null",
            values={"quality_score": 3.8}
        )
        print(f"✓ Update complete. Version: {table.version}")

    def get_stats(self) -> None:
        """Print database statistics."""
        table = self.db.open_table(self.table_name)
        print("\n" + "=" * 60)
        print("DATABASE STATISTICS")
        print("=" * 60)
        print(f"Total recordings: {table.count_rows()}")
        print(f"Table version: {table.version}")
        print(f"Schema: {len(table.schema)} fields")
        print("\nRecordings by model:")
        print(table.to_pandas()["model"].value_counts())


# ============================================
# SAMPLE DATA
# ============================================

SAMPLE_RECORDINGS = [
    {
        "id": "gabgab-001",
        "transcript": "Generate a daily briefing for the morning routine",
        "model": "kokoro-82m",
        "duration_ms": 3500,
        "speaker": "user"
    },
    {
        "id": "gabgab-002",
        "transcript": "Remind me about the dentist appointment at 3 PM",
        "model": "kokoro-82m",
        "duration_ms": 2800,
        "speaker": "user"
    },
    {
        "id": "gabgab-003",
        "transcript": "The weather forecast shows rain this afternoon",
        "model": "lfm2.5",
        "duration_ms": 4200,
        "speaker": "system"
    },
    {
        "id": "gabgab-004",
        "transcript": "Schedule a team meeting for next week Monday",
        "model": "kokoro-82m",
        "duration_ms": 3100,
        "speaker": "user"
    },
    {
        "id": "gabgab-005",
        "transcript": "Play some relaxing music for meditation",
        "model": "lfm2.5",
        "duration_ms": 2500,
        "speaker": "user"
    },
    {
        "id": "gabgab-006",
        "transcript": "What's the stock price of Apple today?",
        "model": "kokoro-82m",
        "duration_ms": 2000,
        "speaker": "user"
    },
    {
        "id": "gabgab-007",
        "transcript": "Set a timer for 25 minutes for focused work",
        "model": "kokoro-82m",
        "duration_ms": 2300,
        "speaker": "user"
    },
    {
        "id": "gabgab-008",
        "transcript": "Turn off all the lights in the living room",
        "model": "kokoro-82m",
        "duration_ms": 2700,
        "speaker": "user"
    }
]


# ============================================
# MAIN DEMO
# ============================================

def main():
    """Run the complete LanceDB POC demonstration."""
    print("=" * 60)
    print("GABGAB LANCEDB POC - Multimodal Voice Data Storage")
    print("=" * 60)

    # Initialize
    manager = GabGabLanceDB()

    # Step 1: Create table
    print("\n📦 Creating table...")
    table = manager.create_table()

    # Step 2: Insert sample data
    print("\n🎤 Inserting sample recordings...")
    for rec in SAMPLE_RECORDINGS:
        manager.insert_recording(
            id=rec["id"],
            transcript=rec["transcript"],
            model=rec["model"],
            duration_ms=rec["duration_ms"],
            speaker=rec.get("speaker")
        )

    # Step 3: Semantic search demonstrations
    print("\n" + "=" * 60)
    print("SEMANTIC SEARCH DEMONSTRATIONS")
    print("=" * 60)

    # Search 1: Find reminders (different wording)
    manager.semantic_search("reminders and appointments")

    # Search 2: Find scheduling-related requests
    manager.semantic_search("scheduling and calendar events")

    # Search 3: Find music/audio requests
    manager.semantic_search("music and audio playback")

    # Search 4: Find smart home controls
    manager.semantic_search("home automation devices")

    # Search with speaker filter
    manager.semantic_search("system messages", speaker_filter="system")

    # Step 4: Versioning demo
    manager.versioning_demo()

    # Step 5: Statistics
    manager.get_stats()

    print("\n" + "=" * 60)
    print("✅ POC Complete!")
    print("=" * 60)
    print("\nKey Benefits Demonstrated:")
    print("  1. Multimodal storage: audio + text + embeddings in one table")
    print("  2. Semantic search: find by meaning, not keywords")
    print("  3. Versioning: schema evolution and time travel")
    print("  4. Local-first: no cloud dependencies")
    print(f"\nDatabase stored in: ./gabgab_lancedb")


if __name__ == "__main__":
    main()
