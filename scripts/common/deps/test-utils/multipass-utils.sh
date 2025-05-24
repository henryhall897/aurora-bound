#!/bin/bash
set -euo pipefail

# --- Check if Multipass is available ---
check_multipass_available() {
  if ! command -v multipass &>/dev/null; then
    echo "[WARNING] Multipass is not installed."
    echo "          Please install it from https://multipass.run"
    echo "          Or run install.sh directly on a test system."
    return 1
  fi
}

# --- Launch a test VM ---
launch_test_vm() {
  local vm_name="$1"
  local mem="${2:-1G}"
  local disk="${3:-5G}"

  echo "[INFO] Launching VM '$vm_name' with $mem RAM and $disk disk..."
  multipass launch --name "$vm_name" --memory "$mem" --disk "$disk"
}

# --- Cleanup a test VM ---
cleanup_test_vm() {
  local vm_name="$1"

  echo "[INFO] Deleting VM '$vm_name'..."
  multipass delete "$vm_name"
  multipass purge
}

# --- Self-check if the script is run directly ---
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  echo "[INFO] Performing self-check for Multipass availability..."
  if check_multipass_available; then
    echo "[OK] Multipass is available."
  else
    echo "[ERROR] Multipass is not available or not in PATH."
    exit 1
  fi
fi
