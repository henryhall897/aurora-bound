#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
DEPS_ORCHESTRATOR="$PROJECT_ROOT/scripts/common/deps/orchestrator.sh"

usage() {
  echo ""
  echo "Usage: aurora {prod|test} {start|stop|logs|status|restart} [--no-logs]"
  echo "       aurora alias   # install 'aurora' shell alias"
  echo ""
  echo "Examples:"
  echo "  aurora prod start"
  echo "  aurora prod stop"
  echo "  aurora prod start --no-logs"
  echo "  aurora test logs"
  echo "  aurora test restart"
  echo ""
  exit 1
}

# Handle help or alias command
if [[ $# -eq 0 || "$1" == "help" || "$1" == "--help" ]]; then
  usage
fi

if [[ "$1" == "alias" ]]; then
  ALIAS_SCRIPT="$PROJECT_ROOT/scripts/common/templates/alias.sh"
  bash "$ALIAS_SCRIPT" aurora "$SCRIPT_DIR/aurora.sh"
  exit 0
fi

# Shortcut: if only an action is passed, default to prod
if [[ "$1" =~ ^(start|stop|logs|status|restart)$ ]]; then
  ENV="prod"
  ACTION="$1"
  EXTRA_ARGS="${@:2}"
else
  ENV="${1:-}"
  ACTION="${2:-}"
  EXTRA_ARGS="${@:3}"
fi

case "$ENV" in
prod)
  ENV_DIR="$PROJECT_ROOT/production-server"
  COMPOSE_FILE="$ENV_DIR/docker-compose.yml"
  CONTAINER_NAME="aurora-bound-production"
  ;;
test)
  ENV_DIR="$PROJECT_ROOT/test-server"
  COMPOSE_FILE="$ENV_DIR/docker-compose.yml"
  CONTAINER_NAME="aurora-bound-test"
  ;;
*)
  echo "[ERROR] Unknown environment: $ENV"
  usage
  ;;
esac

case "$ACTION" in
start)
  bash "$DEPS_ORCHESTRATOR"
  echo "[INFO] Starting server in $ENV_DIR..."
  "$ENV_DIR/up.sh" "${EXTRA_ARGS[@]}"
  ;;

stop)
  "$ENV_DIR/down.sh"
  ;;

logs)
  if docker ps -a --format '{{.Names}}' | grep -q "^$CONTAINER_NAME\$"; then
    echo "[INFO] Showing logs for $CONTAINER_NAME (Ctrl+C to exit)..."
    docker logs -f "$CONTAINER_NAME"
  else
    echo "[WARN] Container '$CONTAINER_NAME' is not running or does not exist."
    exit 1
  fi
  ;;
status)
  docker-compose -f "$COMPOSE_FILE" ps
  ;;
restart)
  "$0" "$ENV" stop
  "$0" "$ENV" start $EXTRA_ARGS
  ;;
*)
  usage
  ;;
esac
