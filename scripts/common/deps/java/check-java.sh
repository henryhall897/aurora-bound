#!/bin/bash
set -euo pipefail

echo "[INFO] Aurora Bound - Java Dependency Installer"

RECOMMENDED_VERSION="17"
PACKAGE_NAME="openjdk-17-jre-headless"

# --- Check if Java is installed ---
if ! command -v java &>/dev/null; then
  echo "[WARNING] No Java installation detected."
else
  JAVA_VERSION_OUTPUT=$(java -version 2>&1 | head -n 1)
  echo "[INFO] Detected Java version: $JAVA_VERSION_OUTPUT"

  if echo "$JAVA_VERSION_OUTPUT" | grep -q "$RECOMMENDED_VERSION"; then
    echo "[OK] Java 17 is already active."
    exit 0
  else
    echo "[INFO] Java is installed but not version 17."
  fi
fi

# --- Check if Java 17 package is installed ---
if dpkg -l | grep -q "$PACKAGE_NAME"; then
  echo "[OK] Package $PACKAGE_NAME is already installed."
else
  echo "[INFO] Installing $PACKAGE_NAME..."
  sudo apt update
  sudo apt install -y "$PACKAGE_NAME"
  echo "[OK] Installed $PACKAGE_NAME."
fi

# --- Attempt to switch default Java version ---
JAVA_17_PATH=$(update-alternatives --list java | grep "java-${RECOMMENDED_VERSION}" || true)

if [[ -n "$JAVA_17_PATH" ]]; then
  echo "[INFO] Setting Java 17 as the default..."
  sudo update-alternatives --set java "$JAVA_17_PATH"
  echo "[OK] Switched to Java 17: $JAVA_17_PATH"
else
  echo "[ERROR] Java 17 was installed but not registered with update-alternatives."
  echo "[INFO] You may need to run: sudo update-alternatives --config java"
  exit 1
fi

# --- Final verification ---
echo
echo "[INFO] Final Java version:"
java -version
