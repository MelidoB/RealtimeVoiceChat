#!/bin/bash

for container in realtime-voice-chat-app realtime-voice-chat-ollama; do
    echo "Stopping $container..."
    docker stop "$container" >/dev/null
    
    merged_dir=$(docker inspect -f '{{ .GraphDriver.Data.MergedDir }}' "$container" 2>/dev/null)
    
    if [ -n "$merged_dir" ] && [ -d "$merged_dir/home/appuser/.cache/torch_extensions" ]; then
        echo "Clearing torch_extensions for $container..."
        sudo rm -rf "$merged_dir/home/appuser/.cache/torch_extensions"
    else
        echo "No torch_extensions found for $container"
    fi

    echo "Starting $container..."
    docker start "$container" >/dev/null
    echo "Done with $container"
done
