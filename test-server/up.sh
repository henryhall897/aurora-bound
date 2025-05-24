#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
UP_TEMPLATE="$PROJECT_ROOT/aurora-bound/scripts/common/templates/up.sh"

COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
CONTAINER_NAME="aurora-bound-test"

source "$UP_TEMPLATE" "$@"
