#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

UP_TEMPLATE="$PROJECT_ROOT/scripts/common/templates/up.sh"
DISPATCHER_PATH="$PROJECT_ROOT/scripts/dispatchers/aurora.sh"

# Set required env vars for the up template
COMPOSE_FILE="$SCRIPT_DIR/docker-compose.yml"
CONTAINER_NAME="aurora-bound-production"

# Use the reusable up logic
source "$UP_TEMPLATE" "$@"
