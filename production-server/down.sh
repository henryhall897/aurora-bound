#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
DOWN_TEMPLATE="$PROJECT_ROOT/scripts/common/templates/down.sh"

COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"

source "$DOWN_TEMPLATE"
