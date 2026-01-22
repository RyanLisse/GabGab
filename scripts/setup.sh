#!/bin/bash

# setup.sh - Install dependencies for GabGab local MLX execution

set -e

echo "📦 Installing GabGab dependencies..."

# Check for python3
if ! command -v python3 &> /dev/null; then
    echo "❌ Python 3 could not be found. Please install Python 3."
    exit 1
fi

# Create virtual environment if it doesn't exist
# Check if python3.12 is available, otherwise fall back to python3
PYTHON_CMD="python3"
if command -v python3.12 &> /dev/null; then
    PYTHON_CMD="python3.12"
    echo "ℹ️  Using Python 3.12 for better compatibility."
fi

if [ ! -d ".venv" ]; then
    echo "🐍 Creating virtual environment with $PYTHON_CMD..."
    "$PYTHON_CMD" -m venv .venv
fi

# Activate virtual environment
source .venv/bin/activate

echo "🐍 Installing Python packages in virtual environment..."
# Install protobuf < 5 first to avoid ABI conflicts
pip3 install "protobuf<5"
# Install other dependencies, forcing source build for sentencepiece and spacy to link against local protobuf
pip3 install --no-binary=sentencepiece,spacy mlx mlx-lm mlx-audio mlx-whisper huggingface_hub soundfile numpy scipy sounddevice loguru misaki num2words spacy pocket-tts
python3 -m spacy download en_core_web_sm

echo "✅ Dependencies installed successfully!"
echo "ℹ️  Virtual environment created at .venv"
