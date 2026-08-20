#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

echo "[INFO] Aurora Bound - cURL Dependency Installer"

# --- Check and install curl ---
if ! command -v curl &>/dev/null; then
	echo "[INFO] curl not found. Installing 'curl'..."
	sudo apt update
	sudo apt install -y curl
	echo "[OK] curl installed successfully."
else
	echo "[OK] curl is already installed."
fi
