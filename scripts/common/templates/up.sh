#!/bin/bash
set -euo pipefail

if [[ -z "${COMPOSE_FILE:-}" ]]; then
  echo "[ERROR] COMPOSE_FILE must be set before sourcing this script."
  exit 1
fi

if [[ -z "${CONTAINER_NAME:-}" ]]; then
  echo "[ERROR] CONTAINER_NAME must be set before sourcing this script."
  exit 1
fi

REQUIRED_COMPOSE_VERSION="3.8"
SHOW_LOGS=true

for arg in "$@"; do
  case "$arg" in
  --no-logs)
    SHOW_LOGS=false
    ;;
  --*) # future: handle more flags
    echo "[ERROR] Unknown flag: $arg"
    echo "Usage: up.sh [--no-logs]"
    exit 1
    ;;
  *) ;; # ignore unknown positional args like "start"
  esac
done

# --- Verify docker-compose.yml exists ---
if [[ ! -f "$COMPOSE_FILE" ]]; then
  echo "[ERROR] docker-compose.yml not found: $COMPOSE_FILE"
  exit 1
fi

# --- Check version ---
COMPOSE_VERSION=$(grep -E '^version:' "$COMPOSE_FILE" | awk '{print $2}' | tr -d "'\"")
if [[ "$COMPOSE_VERSION" != "$REQUIRED_COMPOSE_VERSION" ]]; then
  echo "[WARNING] Expected version $REQUIRED_COMPOSE_VERSION, found $COMPOSE_VERSION"
else
  echo "[OK] docker-compose.yml uses correct version: $COMPOSE_VERSION"
fi

# --- Start server ---
echo "[INFO] Starting server using $COMPOSE_FILE..."
docker-compose -f "$COMPOSE_FILE" up -d

# --- Logs ---
if $SHOW_LOGS; then
  echo "[INFO] Showing logs for container '$CONTAINER_NAME'. Ctrl+C to exit."
  docker logs -f "$CONTAINER_NAME"
else
  echo "[OK] Server started successfully (logs suppressed)."
fi
