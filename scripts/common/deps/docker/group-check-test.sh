#!/bin/bash
set -euo pipefail

TEMP_USER="tempdockertest"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="$SCRIPT_DIR/group-check.sh"
UTIL_PATH="$SCRIPT_DIR/../test-utils/temp-user.sh"

# Source reusable temp user logic
source "$UTIL_PATH"

echo "[INFO] Creating temporary user for group check test..."
create_temp_user "$TEMP_USER"

echo "[INFO] Running group check as root, targeting '$TEMP_USER'..."
sudo bash "$SCRIPT_PATH" "$TEMP_USER"

echo "[INFO] Displaying group membership for '$TEMP_USER'..."
id "$TEMP_USER"

echo "[INFO] Cleaning up temporary user..."
cleanup_temp_user "$TEMP_USER"

echo "[OK] Group check test completed. Temporary user removed."
