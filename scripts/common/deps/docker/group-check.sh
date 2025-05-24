#!/bin/bash
set -euo pipefail

TARGET_USER="${1:-$(whoami)}"

# --- Check if user is already in the docker group ---
if groups "$TARGET_USER" | grep -qw docker; then
  echo "[OK] User '$TARGET_USER' is already in the 'docker' group."
else
  echo "[INFO] User '$TARGET_USER' is not in the 'docker' group. Attempting to add..."
  sudo usermod -aG docker "$TARGET_USER"

  echo
  echo "============================================================"
  echo "NOTICE: '$TARGET_USER' has been added to the 'docker' group."
  echo "Running 'newgrp docker' in the current shell for immediate access."
  echo "You now have temporary access via 'newgrp docker'."
  echo "To fully apply group changes across all sessions, please log out and back in, or reboot your system."
  echo "============================================================"
  echo

  # Apply group change in current shell if acting on self
  if [[ "$TARGET_USER" == "$(whoami)" ]]; then
    echo "[INFO] Activating 'docker' group in the current shell for user '$TARGET_USER'..."
    if [[ -z "${AURORA_TEST_MODE:-}" ]]; then
      exec newgrp docker
    else
      echo "[INFO] Skipping 'newgrp' because this is a test environment."
    fi
  else
    echo "[INFO] Skipping 'newgrp' because current user is not the target user."
  fi
fi
