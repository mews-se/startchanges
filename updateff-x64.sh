#!/usr/bin/env bash

# Fetch the latest fastfetch release URL for linux-amd64 deb file
FASTFETCH_URL=$(curl -s https://api.github.com/repos/fastfetch-cli/fastfetch/releases/latest | grep "browser_download_url.*linux-amd64.deb" | cut -d '"' -f 4)

# Download the latest fastfetch deb file
curl -sL $FASTFETCH_URL -o /tmp/fastfetch_latest_amd64.deb

# Install the downloaded deb file using apt-get
sudo apt-get install /tmp/fastfetch_latest_amd64.deb
