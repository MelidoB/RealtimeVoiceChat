#!/bin/bash

# Docker Build Analyzer Script
# This script builds your container step by step and shows space usage

set -e

LOG_DIR="docker_debug_logs"
mkdir -p "$LOG_DIR"

echo "🔍 Docker Build Debug Analysis"
echo "==============================================="

# Function to get image size
get_image_size() {
    local image_id="$1"
    docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}" | grep "$image_id" | awk '{print $3}'
}

# Function to show disk usage
show_disk_usage() {
    echo "💾 Current Docker disk usage:"
    docker system df
    echo
}

echo "📊 Initial Docker disk usage:"
show_disk_usage

# Build with detailed logging
echo "🔨 Starting build with detailed logging..."
docker compose build --progress=plain --no-cache 2>&1 | tee "$LOG_DIR/build_full.log"

echo "📊 Final Docker disk usage:"
show_disk_usage

# Analyze the build log
echo "🔍 Analyzing build steps..."
grep -n "DONE" "$LOG_DIR/build_full.log" > "$LOG_DIR/completed_steps.log" || true
grep -n "ERROR" "$LOG_DIR/build_full.log" > "$LOG_DIR/errors.log" || true

# Show largest layers
echo "📏 Analyzing image layers..."
docker images --format "table {{.Repository}}\t{{.Tag}}\t{{.Size}}\t{{.CreatedAt}}" > "$LOG_DIR/image_sizes.log"

# Show what's taking space
echo "🗂️  Top space consumers:"
docker system df -v > "$LOG_DIR/detailed_usage.log"

echo "✅ Analysis complete! Check the '$LOG_DIR' folder for detailed logs."
