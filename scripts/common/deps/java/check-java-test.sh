#!/bin/bash
set -euo pipefail

VM_NAME="aurora-java-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTIL_PATH="$SCRIPT_DIR/../test-utils/multipass-utils.sh"
TEMP_USER="tempjavatest"
REMOTE_DIR="/opt/java"

# Project root
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Source reusable multipass helpers
source "$UTIL_PATH"

# --- Cleanup ---
cleanup_on_exit() {
  echo "[INFO] Cleaning up VM if needed..."
  if multipass info "$VM_NAME" &>/dev/null; then
    multipass delete "$VM_NAME"
    multipass purge
    echo "[OK] VM '$VM_NAME' cleaned up."
  fi
}
trap cleanup_on_exit EXIT

# --- Launch VM ---
if multipass info "$VM_NAME" &>/dev/null; then
  echo "[WARNING] Deleting stale VM '$VM_NAME'..."
  multipass delete "$VM_NAME"
  multipass purge
fi

launch_test_vm "$VM_NAME" "1G" "5G"

# --- Install Java 11 to simulate mismatch ---
echo "[INFO] Installing Java 11 to simulate incompatible version..."
multipass exec "$VM_NAME" -- sudo apt update
multipass exec "$VM_NAME" -- sudo apt install -y openjdk-11-jre-headless

# --- Create temp user ---
echo "[INFO] Creating temp user..."
multipass exec "$VM_NAME" -- sudo useradd -m -s /bin/bash "$TEMP_USER"
multipass exec "$VM_NAME" -- sudo bash -c "echo '$TEMP_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$TEMP_USER"

# --- Transfer Java check script ---
echo "[INFO] Transferring check-java.sh..."
# Copy to ubuntu's home directory
multipass transfer "$SCRIPT_DIR/check-java.sh" "$VM_NAME:/home/ubuntu/check-java.sh"
# Create destination directory and move file into it
multipass exec "$VM_NAME" -- sudo mkdir -p "$REMOTE_DIR"
multipass exec "$VM_NAME" -- sudo mv /home/ubuntu/check-java.sh "$REMOTE_DIR/check-java.sh"

multipass exec "$VM_NAME" -- sudo chown -R "$TEMP_USER:$TEMP_USER" "$REMOTE_DIR"
multipass exec "$VM_NAME" -- sudo chmod +x "$REMOTE_DIR/check-java.sh"

# --- Run check as test user ---
echo "[INFO] Running Java version check as $TEMP_USER..."
multipass exec "$VM_NAME" -- sudo -u "$TEMP_USER" bash "$REMOTE_DIR/check-java.sh"

# --- Prompt to delete VM ---
read -p "[INFO] Delete VM '$VM_NAME' after test? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  cleanup_on_exit
else
  echo "[INFO] VM preserved. You can connect using: multipass shell $VM_NAME"
  trap - EXIT
fi

echo "[OK] Java check test completed."
