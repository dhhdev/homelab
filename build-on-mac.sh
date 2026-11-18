#!/usr/bin/env bash

# Ensure local build directory exists
mkdir -p build

# Build container image
docker build --platform linux/amd64 -t proxmox-builder .

# Run the builder with correct source and destination paths
docker run --platform linux/amd64 --rm -v "$(pwd)":/workspace -w /workspace/proxmox proxmox-builder bash build-iso.sh ../assets/proxmox-ve_9.2-1.iso
