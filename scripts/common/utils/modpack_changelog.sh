#!/usr/bin/env bash
# shellcheck shell=bash

set -euo pipefail

# modpack_changelog.sh
# Generate a Markdown changelog for a modpack update:
#   <PROJECT_ROOT>/changelogs/<version>.md
#
# - Auto-detects PROJECT_ROOT based on script location
# - Defaults: OLD=production-server/mods, NEW=test-server/mods
# - Prompts for --version if omitted
# - Finds the most recent previous version from changelogs/*.md and shows it in the header
#
# Usage:
#   scripts/common/utils/modpack_changelog.sh [--version 1.2.1] [--old DIR] [--new DIR] [--show-unchanged] [--raw-diff] [--yes]

# ----- locate project root & defaults -----
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

OLD_DIR_DEFAULT="$PROJECT_ROOT/production-server/mods"
NEW_DIR_DEFAULT="$PROJECT_ROOT/test-server/mods"
CHANGELOGS_DIR="$PROJECT_ROOT/changelogs"

VERSION=""
OLD_DIR="$OLD_DIR_DEFAULT"
NEW_DIR="$NEW_DIR_DEFAULT"
SHOW_UNCHANGED="false"
RAW_DIFF="false"
ASSUME_YES="false"

usage() {
	cat <<EOF
Usage: $(basename "$0") [--version X.Y.Z] [--old DIR] [--new DIR] [--show-unchanged] [--raw-diff] [--yes]

Defaults:
  --old $OLD_DIR_DEFAULT
  --new $NEW_DIR_DEFAULT
  --out <PROJECT_ROOT>/changelogs/<version>.md

Options:
  --version X.Y.Z        Target modpack version (e.g., 1.2.1). If omitted, you'll be prompted.
  --old PATH             Path to OLD mods directory (default: production-server/mods)
  --new PATH             Path to NEW mods directory (default: test-server/mods)
  --show-unchanged       Include Unchanged section
  --raw-diff             Append raw filename lists for reference
  --yes                  Do not prompt before overwrite if file exists
  -h, --help             Show this help
EOF
}

# ---------- arg parse ----------
while [[ $# -gt 0 ]]; do
	case "$1" in
	--version)
		VERSION="${2:-}"
		shift 2
		;;
	--old)
		OLD_DIR="${2:-}"
		shift 2
		;;
	--new)
		NEW_DIR="${2:-}"
		shift 2
		;;
	--show-unchanged)
		SHOW_UNCHANGED="true"
		shift
		;;
	--raw-diff)
		RAW_DIFF="true"
		shift
		;;
	--yes)
		ASSUME_YES="true"
		shift
		;;
	-h | --help)
		usage
		exit 0
		;;
	*)
		echo "[ERROR] Unknown arg: $1"
		usage
		exit 1
		;;
	esac
done

# ---------- version prompt & validation ----------
if [[ -z "${VERSION}" ]]; then
	read -rp "Enter target version (e.g., 1.2.1): " VERSION
fi
if [[ -z "${VERSION}" ]]; then
	echo "[ERROR] Version is required."
	exit 1
fi
# semver-ish: 1.2.3 or 1.2.3-rc.1
if ! [[ "$VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+([\-\.][A-Za-z0-9\.]+)?$ ]]; then
	echo "[ERROR] Version '$VERSION' is not valid. Use e.g. 1.2.1 or 1.2.1-rc.1"
	exit 1
fi

# ---------- validate dirs & prepare output ----------
[[ -d "$OLD_DIR" ]] || {
	echo "[ERROR] Old mods dir not found: $OLD_DIR"
	exit 1
}
[[ -d "$NEW_DIR" ]] || {
	echo "[ERROR] New mods dir not found: $NEW_DIR"
	exit 1
}
mkdir -p "$CHANGELOGS_DIR"
OUT_FILE="$CHANGELOGS_DIR/$VERSION.md"

if [[ -f "$OUT_FILE" && "$ASSUME_YES" != "true" ]]; then
	read -rp "Output file '$OUT_FILE' exists. Overwrite? [y/N]: " ans
	ans="${ans,,}"
	if [[ "$ans" != "y" && "$ans" != "yes" ]]; then
		echo "[INFO] Aborted."
		exit 0
	fi
fi

# ---------- previous version detection ----------
# Extract versions from existing changelogs like X.Y.Z*.md, sort with -V, pick latest below the target
prev_version=""
if compgen -G "$CHANGELOGS_DIR/*.md" >/dev/null; then
	# get basenames without .md
	mapfile -t _cand < <(find "$CHANGELOGS_DIR" -maxdepth 1 -type f -name '*.md' -printf '%f\n' |
		sed -E 's/\.md$//' |
		grep -E '^[0-9]+\.[0-9]+\.[0-9]+([\-\.][A-Za-z0-9\.]+)?$' |
		grep -v -F -- "$VERSION" || true)
	if ((${#_cand[@]})); then
		# sort semver-ish with GNU sort -V, pick the last (highest)
		# shellcheck disable=SC2207
		_sorted=($(printf '%s\n' "${_cand[@]}" | sort -V))
		prev_version="${_sorted[-1]}"
	fi
fi

# ---------- change type (major/minor/patch) ----------
change_type=""
if [[ -n "$prev_version" ]]; then
	IFS='.-' read -r pv_major pv_minor pv_patch _ <<<"$prev_version"
	IFS='.-' read -r v_major v_minor v_patch _ <<<"$VERSION"
	if [[ "$pv_major" != "$v_major" ]]; then
		change_type="major"
	elif [[ "$pv_minor" != "$v_minor" ]]; then
		change_type="minor"
	elif [[ "$pv_patch" != "$v_patch" ]]; then
		change_type="patch"
	else
		change_type="metadata"
	fi
else
	change_type="first-recorded"
fi

# ---------- helpers ----------
normalize_filename() {
	local s="$1"
	s="${s%.jar}"
	s="${s%.JAR}"
	s="${s// /-}"
	s="${s//_/-}"
	s="$(echo "$s" | sed -E 's/-{2,}/-/g')"
	printf '%s' "$(echo "$s" | tr '[:upper:]' '[:lower:]')"
}
split_tokens() {
	local s="$1"
	IFS='-' read -r -a TOKS <<<"$s"
	echo "${TOKS[@]}"
}
is_version_token() { [[ "$1" =~ ^v?[0-9] ]] || [[ "$1" =~ ^[0-9]+\.[0-9]+ ]]; }
is_mc_token() { [[ "$1" =~ ^([mM][cC])?[0-9]+(\.[0-9]+)*$ ]]; }
is_noise_token() { case "${1,,}" in forge | fabric | neoforge | quilt | universal | client | server) return 0 ;; *) return 1 ;; esac }

extract_name_version() {
	local filename="$1"
	local base
	base="$(normalize_filename "$filename")"

	local -a toks
	IFS='-' read -r -a toks <<<"$base" # <— no SC2207

	local ver_idx=""
	local i t
	[[ ${#toks[@]} -eq 0 ]] && {
		echo "$filename|unknown"
		return
	}
	for ((i = 0; i < ${#toks[@]}; i++)); do
		t="${toks[$i]}"
		if is_version_token "$t"; then
			ver_idx="$i"
			break
		fi
	done
	if [[ -z "$ver_idx" ]]; then
		for ((i = 0; i < ${#toks[@]}; i++)); do
			t="${toks[$i]}"
			if is_mc_token "$t"; then
				ver_idx="$i"
				break
			fi
		done
	fi
	local name ver
	if [[ -z "$ver_idx" ]]; then
		name="${toks[0]}"
		ver="unknown"
	else
		if ((ver_idx > 0)); then name="$(
			IFS='-'
			echo "${toks[*]:0:ver_idx}"
		)"; else name="${toks[0]}"; fi
		local cleaned=()
		for ((i = ver_idx; i < ${#toks[@]}; i++)); do
			t="${toks[$i]}"
			if is_mc_token "$t"; then continue; fi
			if is_noise_token "$t" && [[ ! "$t" =~ [0-9] ]]; then continue; fi
			cleaned+=("$t")
		done
		if ((${#cleaned[@]} == 0)); then ver="$(
			IFS='-'
			echo "${toks[*]:ver_idx}"
		)"; else ver="$(
			IFS='-'
			echo "${cleaned[*]}"
		)"; fi
	fi
	[[ -n "$name" ]] || name="${toks[0]}"
	echo "$name|$ver"
}

read_mod_id() {
	local jar="$1"
	local id=""

	# Forge / NeoForge
	id="$(unzip -p "$jar" META-INF/mods.toml 2>/dev/null |
		awk -F= '/^[[:space:]]*modId[[:space:]]*=/{print $2; exit}')"
	if [[ -z "$id" ]]; then
		id="$(unzip -p "$jar" META-INF/neoforge.mods.toml 2>/dev/null |
			awk -F= '/^[[:space:]]*modId[[:space:]]*=/{print $2; exit}')"
	fi

	# Fabric
	if [[ -z "$id" ]]; then
		id="$(unzip -p "$jar" fabric.mod.json 2>/dev/null |
			sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]\+\)".*/\1/p' | head -n1)"
	fi

	# Sanitize: drop inline comments and CR, trim
	if [[ -n "$id" ]]; then
		id="${id%%#*}" # strip after '#'
		id="${id%%;*}" # strip after ';'
		id="$(echo -n "$id" | tr -d '\r' | sed -E 's/^[[:space:]]+|[[:space:]]+$//g')"
		id="${id,,}" # lowercase for consistency
	fi

	echo "$id"
}
canonicalize_name_key() {
	echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9]+//g'
}

declare -A OLD_VER OLD_FILE NEW_VER NEW_FILE
# shellcheck disable=SC2034,SC3043
scan_dir() {
	local dir="$1"
	local -n VERMAP="$2" # nameref (Bash 4.3+)
	local -n FILEMAP="$3"

	# Mark as read to satisfy ShellCheck without changing logic
	: "${VERMAP[@]+x}" "${FILEMAP[@]+x}"

	shopt -s nullglob
	for f in "$dir"/*.jar "$dir"/*.JAR; do
		local fname
		fname="$(basename "$f")"

		# 1) Try to read a true mod ID from the jar
		local mod_id
		mod_id="$(read_mod_id "$f")"

		# 2) Fallback to filename parsing if no ID found
		local key ver
		if [[ -n "$mod_id" ]]; then
			key="${mod_id,,}" # lowercase
			ver="$(extract_name_version "$fname" | awk -F'|' '{print $2}')"
		else
			local nv
			nv="$(extract_name_version "$fname")"
			key="$(canonicalize_name_key "${nv%%|*}")"
			ver="${nv##*|}"
			ver="${ver// /-}"
		fi

		VERMAP["$key"]="$ver"
		FILEMAP["$key"]="$fname"
	done
	shopt -u nullglob
}

scan_dir "$OLD_DIR" OLD_VER OLD_FILE
scan_dir "$NEW_DIR" NEW_VER NEW_FILE

mapfile -t OLD_NAMES < <(printf '%s\n' "${!OLD_VER[@]}" | sort)
mapfile -t NEW_NAMES < <(printf '%s\n' "${!NEW_VER[@]}" | sort)

declare -A SET_OLD SET_NEW
for n in "${OLD_NAMES[@]}"; do SET_OLD["$n"]=1; done
for n in "${NEW_NAMES[@]}"; do SET_NEW["$n"]=1; done

ADDED=()
REMOVED=()
COMMON=()
for n in "${NEW_NAMES[@]}"; do [[ -z "${SET_OLD[$n]:-}" ]] && ADDED+=("$n"); done
for n in "${OLD_NAMES[@]}"; do [[ -z "${SET_NEW[$n]:-}" ]] && REMOVED+=("$n"); done
for n in "${NEW_NAMES[@]}"; do [[ -n "${SET_OLD[$n]:-}" ]] && COMMON+=("$n"); done

UPDATED=()
UNCHANGED=()
for n in "${COMMON[@]}"; do
	if [[ "${OLD_VER[$n]}" != "${NEW_VER[$n]}" ]]; then UPDATED+=("$n"); else UNCHANGED+=("$n"); fi
done

# Compute repo-relative paths for header
ROOT_ABS="$(realpath "$PROJECT_ROOT")"
OLD_ABS="$(realpath "$OLD_DIR")"
NEW_ABS="$(realpath "$NEW_DIR")"

if [[ "$OLD_ABS" == "$ROOT_ABS"* ]]; then
	rel_old="${OLD_ABS#"$ROOT_ABS/"}"
else
	rel_old="$OLD_ABS" # outside repo; show absolute
fi

if [[ "$NEW_ABS" == "$ROOT_ABS"* ]]; then
	rel_new="${NEW_ABS#"$ROOT_ABS/"}"
else
	rel_new="$NEW_ABS"
fi

# ---------- write markdown ----------
ts="$(date '+%Y-%m-%d %H:%M:%S')"
{
	if [[ -n "$prev_version" ]]; then
		echo "# Aurora Bound Changelog ${VERSION} (from ${prev_version})"
	else
		echo "# Aurora Bound Changelog ${VERSION}"
	fi
	echo "_Generated on ${ts}_"
	echo
	echo "**Old mods dir:** \`./$rel_old\`  "
	echo "**New mods dir:** \`./$rel_new\`  "

	if [[ -n "$prev_version" ]]; then
		echo "**Previous version:** \`${prev_version}\`  "
		echo "**Change type:** \`${change_type}\`  "
	else
		echo "**Previous version:** _none (first recorded release)_  "
		echo "**Change type:** \`${change_type}\`  "
	fi
	echo

	echo "## Updated"
	if ((${#UPDATED[@]})); then
		for n in "${UPDATED[@]}"; do
			echo "- **$n**: \`${OLD_VER[$n]}\` → \`${NEW_VER[$n]}\`"
		done
	else
		echo "_No updates_"
	fi
	echo

	echo "## Added"
	if ((${#ADDED[@]})); then
		for n in "${ADDED[@]}"; do
			echo "- **$n** \`${NEW_VER[$n]}\`  (_${NEW_FILE[$n]}_)"
		done
	else
		echo "_No new mods_"
	fi
	echo

	echo "## Removed"
	if ((${#REMOVED[@]})); then
		for n in "${REMOVED[@]}"; do
			echo "- **$n** \`${OLD_VER[$n]}\`  (_${OLD_FILE[$n]}_)"
		done
	else
		echo "_No removals_"
	fi
	echo

	if [[ "$SHOW_UNCHANGED" == "true" ]] && ((${#UNCHANGED[@]})); then
		echo "## ⁉ Unchanged"
		for n in "${UNCHANGED[@]}"; do
			echo "- **$n** \`${OLD_VER[$n]}\`"
		done
		echo
	fi

	if [[ "$RAW_DIFF" == "true" ]]; then
		echo "---"
		echo "## Raw filename lists (reference)"
		echo "### Old"
		for n in "${OLD_NAMES[@]}"; do echo "- ${OLD_FILE[$n]}"; done
		echo
		echo "### New"
		for n in "${NEW_NAMES[@]}"; do echo "- ${NEW_FILE[$n]}"; done
		echo
	fi
} >"$OUT_FILE"

echo "[OK] Wrote changelog to: $OUT_FILE"
