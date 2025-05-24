#!/bin/bash
set -euo pipefail

VM_NAME="aurora-orchestrator-test"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTIL_PATH="$SCRIPT_DIR/../test-utils/multipass-utils.sh"
TEMP_USER="tempdockertest"
REMOTE_PROJECT_DIR="/opt/aurora-bound-production"
REMOTE_SCRIPTS_DIR="$REMOTE_PROJECT_DIR/scripts"

# Determine path to scripts/common/
COMMON_DIR="$(cd "$SCRIPT_DIR/../../../" && pwd)/common"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../" && pwd)"

# Source reusable multipass logic
source "$UTIL_PATH"

# --- Cleanup handler on exit or failure ---
cleanup_on_exit() {
  echo "[INFO] Cleaning up leftover VM if running..."
  if multipass info "$VM_NAME" &>/dev/null; then
    echo "[INFO] Deleting leftover VM '$VM_NAME'..."
    multipass delete "$VM_NAME"
    multipass purge
    echo "[OK] VM '$VM_NAME' cleaned up."
  fi
}
trap cleanup_on_exit EXIT

# --- Ensure multipass is available ---
if ! check_multipass_available; then
  echo "[ERROR] Multipass is required to run this test. Exiting."
  exit 1
fi

# --- Remove any stale VM from a failed run ---
if multipass info "$VM_NAME" &>/dev/null; then
  echo "[WARNING] VM '$VM_NAME' already exists. Deleting it before continuing..."
  multipass delete "$VM_NAME"
  multipass purge
fi

# --- Launch VM ---
launch_test_vm "$VM_NAME" "1G" "5G"

# --- Create test user inside VM ---
echo "[INFO] Creating temporary user '$TEMP_USER' inside VM..."
multipass exec "$VM_NAME" -- sudo useradd -m -s /bin/bash "$TEMP_USER"
multipass exec "$VM_NAME" -- sudo bash -c "echo '$TEMP_USER ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$TEMP_USER"

# --- Create project structure in VM ---
echo "[INFO] Creating simulated project structure in VM at $REMOTE_PROJECT_DIR..."
multipass exec "$VM_NAME" -- sudo mkdir -p "$REMOTE_SCRIPTS_DIR/common"

# --- Debugging: Display the contents of COMMON_DIR ---
echo "[DEBUG] COMMON_DIR is: $COMMON_DIR"
ls -la "$COMMON_DIR"

# --- Transfer script files ---
echo "[INFO] Transferring scripts/common files..."
multipass transfer --recursive "$COMMON_DIR/" "$VM_NAME:/home/ubuntu/"

# --- Move transferred contents into scripts/common ---
echo "[INFO] Moving transferred common directories into scripts/..."
multipass exec "$VM_NAME" -- sudo mv /home/ubuntu/common/deps /home/ubuntu/common/templates "$REMOTE_SCRIPTS_DIR/common/"
multipass exec "$VM_NAME" -- sudo chown -R "$TEMP_USER:$TEMP_USER" "$REMOTE_SCRIPTS_DIR/common"
multipass exec "$VM_NAME" -- sudo chmod -R +x "$REMOTE_SCRIPTS_DIR/common"

# --- Install tree for directory listing (optional) ---
echo "[INFO] Installing tree for directory listing..."
multipass exec "$VM_NAME" -- sudo apt update
multipass exec "$VM_NAME" -- sudo apt install -y tree

# --- Display directory structure for debugging ---
echo "[INFO] Displaying directory structure of $REMOTE_PROJECT_DIR..."
multipass exec "$VM_NAME" -- tree "$REMOTE_PROJECT_DIR"

# --- Run orchestrator.sh as the temp user ---
ORCH_PATH="$REMOTE_SCRIPTS_DIR/common/deps/orchestrator.sh"
echo "[INFO] Running orchestrator.sh as $TEMP_USER from $ORCH_PATH..."
multipass exec "$VM_NAME" -- bash -c "cd $(dirname "$ORCH_PATH") && sudo -u $TEMP_USER env AURORA_TEST_MODE=1 ./orchestrator.sh"

# --- Option to keep VM for debugging ---
read -p "[INFO] Delete VM '$VM_NAME' after test? (y/N): " confirm
if [[ "$confirm" =~ ^[Yy]$ ]]; then
  cleanup_on_exit
else
  echo "[INFO] VM preserved. You can connect using: multipass shell $VM_NAME"
  trap - EXIT
fi

echo "[OK] Orchestrator test completed successfully."
