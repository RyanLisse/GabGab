#!/usr/bin/env python3
"""
Quick test to verify the LanceDB POC setup is working.
"""

import sys

def test_imports():
    """Test that all required packages are installed."""
    print("Testing imports...")

    try:
        import lancedb
        print("✓ lancedb imported")
    except ImportError as e:
        print(f"✗ lancedb not found: {e}")
        return False

    try:
        import pyarrow
        print("✓ pyarrow imported")
    except ImportError as e:
        print(f"✗ pyarrow not found: {e}")
        return False

    try:
        import numpy
        print("✓ numpy imported")
    except ImportError as e:
        print(f"✗ numpy not found: {e}")
        return False

    try:
        from sentence_transformers import SentenceTransformer
        print("✓ sentence_transformers imported")
    except ImportError as e:
        print(f"✗ sentence_transformers not found: {e}")
        return False

    return True


def test_database():
    """Test basic database operations."""
    print("\nTesting database operations...")

    try:
        import lancedb
        import pyarrow as pa

        # Connect to test database
        db = lancedb.connect("./test_db")

        # Create simple schema
        schema = pa.schema([
            pa.field("id", pa.string()),
            pa.field("text", pa.string())
        ])

        # Create table
        table = db.create_table("test_table", schema=schema, mode="overwrite")
        print("✓ Database and table created")

        # Insert test data
        data = [{"id": "1", "text": "Hello, GabGab!"}]
        table.add(data)
        print("✓ Data inserted")

        # Read back
        result = table.to_pandas()
        if len(result) == 1 and result.iloc[0]["text"] == "Hello, GabGab!":
            print("✓ Data read back correctly")
        else:
            print("✗ Data mismatch")
            return False

        return True

    except Exception as e:
        print(f"✗ Database test failed: {e}")
        return False


def main():
    print("=" * 50)
    print("GabGab LanceDB POC - Setup Test")
    print("=" * 50)
    print()

    success = True

    if not test_imports():
        print("\n❌ Some imports failed. Run: pip install -r requirements.txt")
        success = False

    if not test_database():
        print("\n❌ Database test failed")
        success = False

    print()
    print("=" * 50)

    if success:
        print("✅ All tests passed! Run: python gabgab_lancedb_poc.py")
    else:
        print("❌ Some tests failed. Check error messages above.")
        sys.exit(1)


if __name__ == "__main__":
    main()
