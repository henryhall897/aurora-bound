#!/bin/bash
set -euo pipefail

echo "[INFO] Aurora Bound - Docker Dependency Installer"

# --- Check and install Docker (docker.io) ---
if ! command -v docker &>/dev/null; then
  echo "[INFO] Docker not found. Installing 'docker.io'..."
  sudo apt update
  sudo apt install -y docker.io
  echo "[OK] Docker installed successfully."
else
  echo "[OK] Docker is already installed."
fi

# --- Enable and start Docker service ---
if ! sudo systemctl is-active --quiet docker; then
  echo "[INFO] Starting and enabling Docker service..."
  sudo systemctl enable --now docker
  echo "[OK] Docker service started."
else
  echo "[OK] Docker service is already running."
fi

# --- Check and install Docker Compose (v1) ---
if ! command -v docker-compose &>/dev/null; then
  echo "[INFO] Docker Compose not found. Installing 'docker-compose'..."
  sudo apt install -y docker-compose
  echo "[OK] Docker Compose installed successfully."
else
  echo "[OK] Docker Compose is already installed."
fi
