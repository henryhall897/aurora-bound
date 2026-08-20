#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

# ---- Paths on host ----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CURSEFORGE_DIR="$SCRIPT_DIR"                         # scripts/common/deps/curseforge
UTILS_DIR="$SCRIPT_DIR/../../utils"                  # scripts/common/utils
REPO_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"   # project root
MANIFESTS_DIR_ON_HOST="$REPO_ROOT/modpack-manifests" # host manifests dir
HOST_ENV_FILE="$HOME/.aurora-bound.env"              # expected location per api-key.sh

VM_NAME="modtest-vm"
TEST_VERSION="${1:-}"

# ---- Absolute paths inside VM (host-known, no $HOME) ----
VM_HOME="/home/ubuntu"
VM_WORKSPACE_HOST="$VM_HOME/aurora-test"
VM_MOUNT_TARGET_HOST="$VM_WORKSPACE_HOST/modpack-manifests"
VM_MODS_DIR_HOST="$VM_WORKSPACE_HOST/mods"

# ---- Helpers (Multipass) ----
# shellcheck source=/dev/null
source "$SCRIPT_DIR/../test-utils/multipass-utils.sh"

check_multipass_available

cleanup_on_exit() {
	echo "[INFO] Cleaning up VM mounts and VM (if present)..."
	multipass umount "$VM_NAME:$VM_MOUNT_TARGET_HOST" 2>/dev/null || true
	if multipass info "$VM_NAME" &>/dev/null; then
		multipass delete "$VM_NAME" || true
		multipass purge || true
		echo "[OK] VM '$VM_NAME' cleaned up."
	fi
}
trap cleanup_on_exit EXIT

# ---- Always recreate VM for a fresh test ----
if multipass info "$VM_NAME" &>/dev/null; then
	echo "[INFO] Recreating existing VM '$VM_NAME'..."
	multipass umount "$VM_NAME:$VM_MOUNT_TARGET_HOST" 2>/dev/null || true
	multipass stop "$VM_NAME" 2>/dev/null || true
	multipass delete "$VM_NAME" || true
	multipass purge || true
fi

launch_test_vm "$VM_NAME" "2G" "10G" # helper logs internally

# ---- Quick host-side visibility for the .env file ----
echo "[TEST][HOST] HOME: $HOME"
echo "[TEST][HOST] Expecting: $HOST_ENV_FILE"
if [[ -e "$HOST_ENV_FILE" ]]; then
	ls -l "$HOST_ENV_FILE" || true
	echo -n "[TEST][HOST] First line (visible): "
	sed -n '1p' "$HOST_ENV_FILE" | sed -n 'l' || true
else
	echo "[TEST][HOST] File missing."
fi

# ---- Prepare workspace in VM ----
multipass exec "$VM_NAME" -- bash -lc "
  mkdir -p \"$VM_WORKSPACE_HOST/deps/jq\" \
           \"$VM_WORKSPACE_HOST/deps/curl\" \
           \"$VM_WORKSPACE_HOST/utils\" \
           \"$VM_MODS_DIR_HOST\"
"

# ---- Ensure mount target & mount manifests ----
multipass exec "$VM_NAME" -- sudo mkdir -p "$VM_MOUNT_TARGET_HOST"
echo "[INFO] Mounting manifests from host to VM..."
multipass mount "$MANIFESTS_DIR_ON_HOST" "$VM_NAME:$VM_MOUNT_TARGET_HOST"

# ---- Inject ~/.aurora-bound.env into VM (fail-safe: file or env var) ----
if [[ -r "$HOST_ENV_FILE" ]]; then
	echo "[INFO] Injecting host .aurora-bound.env into VM (byte-for-byte)…"
	if base64 --help 2>&1 | grep -q -- '-w'; then
		B64_ENV="$(base64 -w0 "$HOST_ENV_FILE")"
	else
		B64_ENV="$(base64 "$HOST_ENV_FILE" | tr -d '\n')"
	fi
	multipass exec "$VM_NAME" -- bash -lc "
    umask 077
    echo '$B64_ENV' | base64 -d > ~/.aurora-bound.env
    echo -n '[TEST][VM] env line: '; sed -n '1p' ~/.aurora-bound.env | sed -n 'l'
  "
elif [[ -n "${CURSEFORGE_API_KEY:-}" ]]; then
	echo "[WARN] Host env file missing; using host CURSEFORGE_API_KEY to create VM env file."
	KEY_ESCAPED="$(printf '%q' "$CURSEFORGE_API_KEY")"
	multipass exec "$VM_NAME" -- bash -lc "
    umask 077
    printf 'export CURSEFORGE_API_KEY=%s\n' $KEY_ESCAPED > ~/.aurora-bound.env
    echo -n '[TEST][VM] env line: '; sed -n '1p' ~/.aurora-bound.env | sed -n 'l'
  "
else
	echo "[ERROR] No host file and no host CURSEFORGE_API_KEY. Cannot proceed."
	exit 1
fi

# ---- Transfer downloader & utils into VM workspace ----
echo "[INFO] Transferring downloader & utils..."
multipass transfer "$CURSEFORGE_DIR/download-mods.sh" "$VM_NAME:$VM_WORKSPACE_HOST/download-mods.sh"
multipass transfer "$UTILS_DIR/api-key.sh" "$VM_NAME:$VM_WORKSPACE_HOST/utils/api-key.sh"
multipass transfer "$SCRIPT_DIR/../jq/install.sh" "$VM_NAME:$VM_WORKSPACE_HOST/deps/jq/install.sh"
multipass transfer "$SCRIPT_DIR/../curl/install.sh" "$VM_NAME:$VM_WORKSPACE_HOST/deps/curl/install.sh"

# ---- Make scripts executable ----
multipass exec "$VM_NAME" -- bash -lc "
  chmod +x \"$VM_WORKSPACE_HOST/download-mods.sh\" \
           \"$VM_WORKSPACE_HOST/utils/api-key.sh\" \
           \"$VM_WORKSPACE_HOST/deps/jq/install.sh\" \
           \"$VM_WORKSPACE_HOST/deps/curl/install.sh\"
"
# Verify .aurora-bound.env in VM
multipass exec "$VM_NAME" -- bash -lc "
  echo '[HOST] HOME is:' \"\$HOME\"
  echo '[HOST] Expecting:' \"\$HOME/.aurora-bound.env\"
  ls -l \"\$HOME/.aurora-bound.env\" || true
  head -n1 \"\$HOME/.aurora-bound.env\" | sed -n 'l' || true

  set +u
  # shellcheck disable=SC1090
  source \"\$HOME/.aurora-bound.env\" 2>/dev/null || true
  set -u

  if [ -n \"\${CURSEFORGE_API_KEY+x}\" ]; then
    echo \"len=\${#CURSEFORGE_API_KEY} prefix=\${CURSEFORGE_API_KEY:0:6}\"
  else
    echo 'key missing'
  fi
"

# ---- Run downloader with explicit envs (paths do not depend on repo layout) ----
echo "[INFO] Running mod download in VM..."
if [[ -z "$TEST_VERSION" ]]; then
	multipass exec "$VM_NAME" -- bash -lc "
    export MODS_DIR=\"$VM_MODS_DIR_HOST\"
    export MANIFESTS_DIR=\"$VM_MOUNT_TARGET_HOST\"
    export DEPS_DIR=\"$VM_WORKSPACE_HOST/deps\"
    export UTILS_DIR=\"$VM_WORKSPACE_HOST/utils\"
    cd \"$VM_WORKSPACE_HOST\" && ./download-mods.sh
  "
else
	multipass exec "$VM_NAME" -- bash -lc "
    export MODS_DIR=\"$VM_MODS_DIR_HOST\"
    export MANIFESTS_DIR=\"$VM_MOUNT_TARGET_HOST\"
    export DEPS_DIR=\"$VM_WORKSPACE_HOST/deps\"
    export UTILS_DIR=\"$VM_WORKSPACE_HOST/utils\"
    cd \"$VM_WORKSPACE_HOST\" && ./download-mods.sh \"$TEST_VERSION\"
  "
fi

# ---- List results ----
echo "[INFO] Listing downloaded mods:"
multipass exec "$VM_NAME" -- bash -lc "ls -l \"$VM_MODS_DIR_HOST\""

# ---- Prompt to keep or clean up (unmount happens in trap either way) ----
read -r -p 'Press Enter to delete the test VM (or Ctrl+C to keep it running)... ' _
cleanup_test_vm "$VM_NAME"
