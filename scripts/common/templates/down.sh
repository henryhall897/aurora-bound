#!/bin/bash
set -euo pipefail

if [[ -z "${COMPOSE_FILE:-}" ]]; then
    echo "[ERROR] COMPOSE_FILE must be set before sourcing this script."
    exit 1
fi

echo "[INFO] Stopping server defined in $COMPOSE_FILE..."
docker-compose -f "$COMPOSE_FILE" down
echo "[OK] Server stopped."
