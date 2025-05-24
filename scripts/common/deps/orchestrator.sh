#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_ORCH="$SCRIPT_DIR/docker/orchestrator.sh"
JAVA_CHECK="$SCRIPT_DIR/java/check-java.sh"

echo "[INFO] Running all dependency checks (Docker + Java)..."

bash "$DOCKER_ORCH"
bash "$JAVA_CHECK"

echo "[OK] All dependencies are satisfied."
