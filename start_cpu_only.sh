#!/bin/bash

# Force CPU mode for all ML libraries
export CUDA_VISIBLE_DEVICES=""
export TORCH_USE_CUDA_DSA=0

echo "🚦 Forcing CPU mode:"
echo "   CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES (disabled)"
echo "   TORCH_USE_CUDA_DSA=$TORCH_USE_CUDA_DSA (disabled)"

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "🚦 Activating virtual environment..."
    source venv/bin/activate
else
    echo "🚦 No virtual environment found, using system Python"
fi

# Change to code directory
cd code

echo "🚦 Starting RealtimeVoiceChat server in CPU-only mode..."
python server.py
