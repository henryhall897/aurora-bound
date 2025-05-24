#!/bin/bash
set -euo pipefail

# --- Create a temporary user ---
create_temp_user() {
  local user="$1"
  echo "[INFO] Creating temporary user: $user"

  if id "$user" &>/dev/null; then
    echo "[WARNING] User '$user' already exists. Attempting to remove..."
    if ! sudo userdel -r "$user" &>/dev/null; then
      echo "[WARNING] Could not fully remove existing user '$user'" >&2
    else
      echo "[OK] Existing user '$user' removed."
    fi
  fi

  sudo useradd -m -s /bin/bash "$user"
  echo "$user:password" | sudo chpasswd
  echo "[OK] User '$user' created with default password."
}

# --- Remove a temporary user ---
cleanup_temp_user() {
  local user="$1"
  echo "[INFO] Cleaning up user: $user"

  if ! sudo userdel -r "$user" &>/dev/null; then
    echo "[WARNING] Could not fully remove test user '$user'" >&2
  else
    echo "[OK] User '$user' removed."
  fi
}
