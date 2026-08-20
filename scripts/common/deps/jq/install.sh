#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

echo "[INFO] Aurora Bound - jq Dependency Installer"

# --- Check and install jq ---
if ! command -v jq &>/dev/null; then
	echo "[INFO] jq not found. Installing 'jq'..."
	sudo apt update
	sudo apt install -y jq
	echo "[OK] jq installed successfully."
else
	echo "[OK] jq is already installed: $(jq --version)"
fi
