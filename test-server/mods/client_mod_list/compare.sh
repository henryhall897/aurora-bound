#!/bin/bash

# Paths to server mods folder and client mod list file
SERVER_MODS=~/minecraft-server/modpacks/VanillaPlusV1/mods/
CLIENT_MOD_LIST=client_mod_list.txt

# Output file for comparison
OUTPUT_FILE=mod_diff.txt

# Ensure the client mod list file exists
if [ ! -f "$CLIENT_MOD_LIST" ]; then
    echo "Client mod list file ($CLIENT_MOD_LIST) not found!"
    exit 1
fi

# Read server mod filenames and client mod list into arrays
server_mods=($(ls "$SERVER_MODS" | sort))
client_mods=($(cat "$CLIENT_MOD_LIST" | sort))

# Use associative arrays for base name comparison
declare -A server_mods_map
declare -A client_mods_map

# Function to extract base name of a mod (ignores version and extension)
extract_base_name() {
    local mod="$1"
    # Remove file extension and version information
    echo "$mod" | sed -E 's/-[0-9]+\..*//; s/(\.jar)//'
}

# Populate server and client mod maps
for mod in "${server_mods[@]}"; do
    base_name=$(extract_base_name "$mod")
    server_mods_map["$base_name"]="$mod"
done

for mod in "${client_mods[@]}"; do
    base_name=$(extract_base_name "$mod")
    client_mods_map["$base_name"]="$mod"
done

# Initialize difference lists
mods_only_on_server=()
mods_only_on_client=()
mods_with_different_versions=()

# Compare server mods
for base_name in "${!server_mods_map[@]}"; do
    if [[ -z "${client_mods_map[$base_name]}" ]]; then
        mods_only_on_server+=("${server_mods_map[$base_name]}")
    elif [[ "${server_mods_map[$base_name]}" != "${client_mods_map[$base_name]}" ]]; then
        mods_with_different_versions+=("Server: ${server_mods_map[$base_name]} | Client: ${client_mods_map[$base_name]}")
    fi
done

# Compare client mods
for base_name in "${!client_mods_map[@]}"; do
    if [[ -z "${server_mods_map[$base_name]}" ]]; then
        mods_only_on_client+=("${client_mods_map[$base_name]}")
    fi
done

# Write comparison results to the output file
{
    echo "Comparing Server and Client Mods"
    echo "--------------------------------"
    
    echo "Mods only on Server:"
    for mod in "${mods_only_on_server[@]}"; do
        echo "$mod"
    done

    echo ""
    echo "Mods only on Client:"
    for mod in "${mods_only_on_client[@]}"; do
        echo "$mod"
    done

    echo ""
    echo "Mods with Different Versions:"
    for mod in "${mods_with_different_versions[@]}"; do
        echo "$mod"
    done
} > "$OUTPUT_FILE"

echo "Comparison complete! See $OUTPUT_FILE for details."
