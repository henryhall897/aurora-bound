#!/usr/bin/env bash
# shellcheck shell=bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

MODS_DIR="${MODS_DIR:-$SCRIPT_DIR/../../../../production-server/mods}"
MANIFESTS_DIR="${MANIFESTS_DIR:-$SCRIPT_DIR/../../../../modpack-manifests}"
DEPS_DIR="${DEPS_DIR:-$SCRIPT_DIR/../deps}"
UTILS_DIR="${UTILS_DIR:-$SCRIPT_DIR/../../utils}"
VERSION="${1:-}"

echo "[DEBUG] MODS_DIR=$MODS_DIR"
echo "[DEBUG] MANIFESTS_DIR=$MANIFESTS_DIR"
echo "[DEBUG] DEPS_DIR=$DEPS_DIR"
echo "[DEBUG] UTILS_DIR=$UTILS_DIR"

# Tools check
# jq check
if ! command -v jq >/dev/null; then
	echo "[INFO] jq not found. Installing via deps/jq/install.sh..."
	bash "$DEPS_DIR/jq/install.sh"
else
	echo "[OK] jq is installed: $(jq --version)"
fi

# curl check
if ! command -v curl >/dev/null; then
	echo "[INFO] curl not found. Installing via deps/curl/install.sh..."
	bash "$DEPS_DIR/curl/install.sh"
else
	echo "[OK] curl is installed: $(curl --version | head -n1)"
fi

# Ensure API key is set
# shellcheck source=/dev/null
source "$UTILS_DIR/api-key.sh"

# Determine manifest file
if [[ -z "$VERSION" ]]; then
	echo "[WARN] No version specified; picking most recently modified manifest"
	# Use find+sort to avoid locale surprises
	mapfile -t manifests < <(find "$MANIFESTS_DIR" -maxdepth 1 -type f -name '*.json' -printf '%T@ %p\n' | sort -nr | awk '{ $1=""; sub(/^ /,""); print }')
	[[ ${#manifests[@]} -gt 0 ]] || {
		echo "[ERROR] No manifests in $MANIFESTS_DIR"
		exit 1
	}
	MANIFEST_FILE="${manifests[0]}"
else
	MANIFEST_FILE="$MANIFESTS_DIR/$VERSION.json"
fi

[[ -f "$MANIFEST_FILE" ]] || {
	echo "[ERROR] Manifest not found: $MANIFEST_FILE"
	exit 1
}
echo "[INFO] Using manifest: $MANIFEST_FILE"

mkdir -p "$MODS_DIR"

# Iterate safely; avoid subshell side-effects
jq -c '.files[]' "$MANIFEST_FILE" | while IFS= read -r mod; do
	projectID="$(jq -r '.projectID' <<<"$mod")"
	fileID="$(jq -r '.fileID' <<<"$mod")"

	# Fetch file metadata (fail on HTTP errors)
	mod_info="$(curl -fsS --retry 3 --retry-delay 1 \
		-H "x-api-key: $CURSEFORGE_API_KEY" \
		"https://api.curseforge.com/v1/mods/$projectID/files/$fileID")" || {
		echo "[ERROR] API request failed for project $projectID file $fileID"
		continue
	}

	downloadUrl="$(jq -r '.data.downloadUrl // empty' <<<"$mod_info")"
	if [[ -z "$downloadUrl" ]]; then
		echo "[WARN] No downloadUrl for project $projectID file $fileID (may be archived or requires token)"
		continue
	fi

	fileName="$(basename -- "$downloadUrl")"
	dest="$MODS_DIR/$fileName"

	if [[ -f "$dest" ]]; then
		echo "[OK] $fileName already exists."
		continue
	fi

	echo "[INFO] Downloading $fileName..."
	curl -fsSL --retry 3 --retry-delay 1 "$downloadUrl" -o "$dest" || {
		echo "[ERROR] Download failed: $fileName"
		rm -f "$dest"
		continue
	}
done

echo "[DONE] Mod installation complete for version: ${VERSION:-latest}"
