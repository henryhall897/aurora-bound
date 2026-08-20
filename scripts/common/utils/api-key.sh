#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

ENV_FILE="$HOME/.aurora-bound.env"

_dbg() { printf '[api-key.sh][DEBUG] %s\n' "$*" >&2; }
# Show which file the script is trying to read
echo "[HOST] HOME is: $HOME"
echo "[HOST] Expecting: $HOME/.aurora-bound.env"

# Permissions and first line (visible control chars)
ls -l "$HOME/.aurora-bound.env" || echo "[HOST] env file not found!"
sed -n '1p' "$HOME/.aurora-bound.env" | sed -n 'l'

if [[ -z "${CURSEFORGE_API_KEY:-}" ]]; then
	echo "[INFO] No API key found in environment."
	if [[ -r "$ENV_FILE" ]]; then
		echo "[INFO] Loading from $ENV_FILE..."
		_dbg "ENV_FILE exists: $(ls -l "$ENV_FILE")"
		_dbg "ENV_FILE (visible chars): $(head -n1 "$ENV_FILE" | sed -n 'l')"

		# Temporarily allow unset to avoid nounset explosions on weird lines
		set +u
		# shellcheck source=/dev/null
		source "$ENV_FILE"
		set -u

		# Show what we got, without leaking full secret
		if [[ -n "${CURSEFORGE_API_KEY:-}" ]]; then
			_dbg "Loaded CURSEFORGE_API_KEY len=${#CURSEFORGE_API_KEY}"
			_dbg "Prefix preview: ${CURSEFORGE_API_KEY:0:6}…"
		else
			_dbg "After sourcing, CURSEFORGE_API_KEY still empty."
		fi
	fi
fi

if [[ -z "${CURSEFORGE_API_KEY:-}" ]]; then
	echo "No API key detected. You can get one at https://console.curseforge.com"
	IFS= read -r -s -p "Enter your CurseForge API Key: " key
	echo
	umask 077
	printf 'export CURSEFORGE_API_KEY=%q\n' "$key" >"$ENV_FILE"
	echo "[INFO] Saved key to $ENV_FILE"
else
	echo "[OK] API key already configured."
fi
