#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
UTIL_PATH="$SCRIPT_DIR/../test-utils/temp-user.sh"
MP_UTIL_PATH="$SCRIPT_DIR/../test-utils/multipass-utils.sh"
VM_NAME="aurora-jq-install-test"

# --- Source shared utilities ---
if [[ -r "$UTIL_PATH" ]]; then
	# shellcheck source=/dev/null
	source "$UTIL_PATH"
fi
if [[ -r "$MP_UTIL_PATH" ]]; then
	# shellcheck source=/dev/null
	source "$MP_UTIL_PATH"
fi

# --- Ensure Multipass is installed ---
if ! check_multipass_available; then
	echo "[ERROR] Multipass is required for this test. Exiting."
	exit 1
fi

# --- Launch lightweight VM ---
launch_test_vm "$VM_NAME" "1G" "5G"

# --- Purge jq if already present ---
echo "[INFO] Removing jq if preinstalled on VM '$VM_NAME'..."
multipass exec "$VM_NAME" -- sudo apt purge -y jq || true
multipass exec "$VM_NAME" -- sudo apt autoremove -y || true

# --- Transfer install.sh into VM ---
echo "[INFO] Transferring install.sh into VM '$VM_NAME'..."
multipass transfer "$INSTALL_SCRIPT" "$VM_NAME:/home/ubuntu/install.sh"
multipass exec "$VM_NAME" -- chmod +x /home/ubuntu/install.sh

# --- Run install.sh inside VM ---
echo "[INFO] Running install.sh inside VM '$VM_NAME'..."
multipass exec "$VM_NAME" -- sudo /home/ubuntu/install.sh

# --- Verify jq installation ---
echo "[INFO] Verifying jq installation..."
if multipass exec "$VM_NAME" -- bash -c 'command -v jq >/dev/null && jq --version'; then
	echo "[OK] jq is installed and functional."
else
	echo "[ERROR] jq verification failed."
	echo "[INFO] Leaving VM running for inspection: multipass shell $VM_NAME"
	exit 1
fi

# --- Prompt for cleanup ---
printf "[INFO] Delete VM '%s' after test? (y/N): " "$VM_NAME"
IFS= read -r confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
	cleanup_test_vm "$VM_NAME"
	echo "[OK] VM '$VM_NAME' deleted."
else
	echo "[INFO] VM preserved. Connect with: multipass shell $VM_NAME"
fi

echo "[OK] jq install test completed successfully."
