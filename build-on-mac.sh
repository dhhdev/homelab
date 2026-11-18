#!/usr/bin/env bash

# Build env because I am on macOS
docker build --platform linux/amd64 -t proxmox-builder .

# Actually build the ISO image from the repo root context
docker run --platform linux/amd64 --rm -v "$(pwd)":/workspace -w /workspace/proxmox proxmox-builder bash build-iso.sh /workspace/assets/proxmox-ve_9.2-1.iso
