#!/bin/bash
set -euo pipefail

TEMP_USER="tempdockertest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
UTIL_PATH="$SCRIPT_DIR/../test-utils/temp-user.sh"
MP_UTIL_PATH="$SCRIPT_DIR/../test-utils/multipass-utils.sh"
VM_NAME="aurora-install-test"

# Source shared utilities
source "$UTIL_PATH"
source "$MP_UTIL_PATH"

# Ensure Multipass is installed
if ! check_multipass_available; then
  echo "[ERROR] Multipass is required for this test. Exiting."
  exit 1
fi

# Launch lightweight VM for safe, isolated install testing
launch_test_vm "$VM_NAME" "1G" "5G"

echo "[INFO] Transferring install.sh into VM '$VM_NAME'..."
multipass transfer "$INSTALL_SCRIPT" "$VM_NAME:/home/ubuntu/install.sh"
multipass exec "$VM_NAME" -- chmod +x /home/ubuntu/install.sh

echo "[INFO] Running install.sh inside VM '$VM_NAME'..."
multipass exec "$VM_NAME" -- sudo /home/ubuntu/install.sh

# Prompt for cleanup
read -p "[INFO] Delete VM '$VM_NAME' after test? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  cleanup_test_vm "$VM_NAME"
  echo "[OK] VM '$VM_NAME' deleted."
else
  echo "[INFO] VM preserved. Connect with: multipass shell $VM_NAME"
fi

echo "[OK] Install test completed successfully."
