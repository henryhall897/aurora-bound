#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_SCRIPT="$SCRIPT_DIR/install.sh"
UTIL_PATH="$SCRIPT_DIR/../test-utils/temp-user.sh"
MP_UTIL_PATH="$SCRIPT_DIR/../test-utils/multipass-utils.sh"
VM_NAME="aurora-curl-install-test"

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

# --- Launch lightweight VM for safe, isolated install testing ---
# Args: <name> <mem> <disk>
launch_test_vm "$VM_NAME" "1G" "5G"

echo "[INFO] Removing preinstalled curl from VM '$VM_NAME'..."
multipass exec "$VM_NAME" -- sudo apt purge -y curl
multipass exec "$VM_NAME" -- sudo apt autoremove -y

echo "[INFO] Transferring install.sh into VM '$VM_NAME'..."
multipass transfer "$INSTALL_SCRIPT" "$VM_NAME:/home/ubuntu/install.sh"
multipass exec "$VM_NAME" -- chmod +x /home/ubuntu/install.sh

echo "[INFO] Running install.sh inside VM '$VM_NAME'..."
multipass exec "$VM_NAME" -- sudo /home/ubuntu/install.sh

# --- Verify curl is installed inside the VM ---
echo "[INFO] Verifying curl installation..."
if multipass exec "$VM_NAME" -- bash -c 'command -v curl >/dev/null && curl --version | head -n1'; then
	echo "[OK] curl is installed and available."
else
	echo "[ERROR] curl verification failed."
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

echo "[OK] cURL install test completed successfully."
