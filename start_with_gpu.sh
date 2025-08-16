#!/bin/bash

# Set CUDA environment variables for stability
export CUDA_LAUNCH_BLOCKING=1
export TORCH_USE_CUDA_DSA=1

echo "🚦 Set CUDA environment variables:"
echo "   CUDA_LAUNCH_BLOCKING=$CUDA_LAUNCH_BLOCKING"
echo "   TORCH_USE_CUDA_DSA=$TORCH_USE_CUDA_DSA"

# Activate virtual environment if it exists
if [ -d "venv" ]; then
    echo "🚦 Activating virtual environment..."
    source venv/bin/activate
else
    echo "🚦 No virtual environment found, using system Python"
fi

# Change to code directory
cd code

echo "🚦 Starting RealtimeVoiceChat server with GPU support..."
python server.py
