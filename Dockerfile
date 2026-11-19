FROM --platform=linux/amd64 debian:trixie-slim

RUN apt-get update && apt-get dist-upgrade -y && apt-get install -y \
    ca-certificates \
    gettext-base \
    golang-go \
    wget \
    gnupg \
    xorriso \
    && rm -rf /var/lib/apt/lists/*

RUN wget -O /etc/apt/trusted.gpg.d/proxmox-release-trixie.gpg https://enterprise.proxmox.com/debian/proxmox-release-trixie.gpg \
    && echo "deb [arch=amd64] http://download.proxmox.com/debian/pve trixie pve-no-subscription" > /etc/apt/sources.list.d/pve-install-repo.list \
    && apt-get update \
    && apt-get install -y proxmox-auto-install-assistant \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
