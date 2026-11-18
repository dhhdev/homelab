#!/usr/bin/env bash

# Ensure local build directory exists
mkdir -p build

# Build container image
docker build --platform linux/amd64 -t proxmox-builder .

# Run the builder and output the ISO into the build folder
docker run --platform linux/amd64 --rm -v "$(pwd)":/workspace -w /workspace/proxmox proxmox-builder bash build-iso.sh ../build/proxmox-ve-homelab-unattended.iso
