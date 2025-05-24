#!/bin/bash
set -euo pipefail

ALIAS_NAME="$1"
TARGET_PATH="$2"
SHELL_RC="$HOME/.bashrc"

# Allow ZSH override
if [[ "$SHELL" == *"zsh" ]]; then
  SHELL_RC="$HOME/.zshrc"
fi

# Add alias if not already present
if ! grep -q "alias $ALIAS_NAME=" "$SHELL_RC"; then
  echo "alias $ALIAS_NAME=\"$TARGET_PATH\"" >>"$SHELL_RC"
  echo "[OK] Alias '$ALIAS_NAME' added to $SHELL_RC"
else
  echo "[INFO] Alias '$ALIAS_NAME' already exists in $SHELL_RC"
fi

# Source or reload shell configuration to apply the alias
echo "[INFO] Reloading your shell to apply alias..."
exec "$SHELL"
