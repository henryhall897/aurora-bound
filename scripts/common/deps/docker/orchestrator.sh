#!/bin/bash
set -euo pipefail

# --- Path Resolution ---
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"  # Go up to the project root
INSTALL_SCRIPT="$SCRIPT_DIR/../docker/install.sh"
GROUP_CHECK_SCRIPT="$SCRIPT_DIR/../docker/group-check.sh"
REQUIRED_COMPOSE_VERSION="3.8"

echo "[INFO] Aurora Bound - Docker Environment Orchestrator"
echo "[INFO] Project root: $PROJECT_ROOT"

# --- Step 1: Install Docker and Compose if needed ---
echo "[INFO] Running Docker installation script..."
bash "$INSTALL_SCRIPT"

# --- Step 2: Ensure current user is in docker group ---
echo "[INFO] Running Docker group membership check..."
bash "$GROUP_CHECK_SCRIPT"

# --- Step 5: Check Docker daemon availability ---
if [[ -z "${AURORA_TEST_MODE:-}" ]]; then
  if ! docker info &>/dev/null; then
    echo "[ERROR] Docker daemon is not running or permission is denied. You may need to log out and log back in, or restart your system."
    exit 1
  else
    echo "[OK] Docker daemon is accessible."
  fi
else
  echo "[INFO] Skipping 'docker info' check in test mode."
fi

