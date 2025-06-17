#!/bin/bash
set -euo pipefail

# CONFIG
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ytsurf"
mkdir -p "$CACHE_DIR"
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# Read search query
if [[ $# -eq 0 ]]; then
	read -rp "Enter Youtube: " query
else
	query="$*"
fi
[[ -z "$query" ]] && {
	echo "No query entered. Exiting."
	exit 1
}

# Cache keys and file
cache_key=$(echo -n "$query" | sha256sum | cut -d' ' -f1)
cache_file="$CACHE_DIR/$cache_key.json"

# Fetch and cache JSON data
if [[ -f "$cache_file" && $(find "$cache_file" -mmin -10) ]]; then
	# Cache is fresh, use it
	json_data=$(cat "$cache_file")
else
	# Fetch fresh data from yt-dlp as JSON lines, convert to JSON array
	json_data=$(yt-dlp "ytsearch10:$query" --flat-playlist --print-json --no-warnings | jq -s '.')
	echo "$json_data" >"$cache_file"
fi

# Build menu list with jq: show truncated title, duration (formatted), uploader
mapfile -t menu_list < <(echo "$json_data" | jq -r '
    def pad2(n): if n < 10 then "0" + (n|tostring) else (n|tostring) end;
    .[] |
    .title as $title |
    .duration as $dur |
    .uploader as $uploader |
    (
      pad2($dur / 3600 | floor) + ":" +
      pad2(($dur % 3600) / 60 | floor) + ":" +
      pad2($dur % 60 | floor)
    ) as $duration_fmt |
    (
      ($title | if length > 30 then .[:30] + "..." else . end)
      + " [" + $duration_fmt + "] by " + $uploader
    )
  ')

# Check if menu is empty
if [ ${#menu_list[@]} -eq 0 ]; then
	echo "No results found for '$query'"
	exit 0
fi

# Export variables to be accessible by the fzf preview subshell
export json_data
export TMPDIR

# Choose item with fzf+chafa or rofi
selected_title=""
if command -v fzf &>/dev/null && command -v chafa &>/dev/null; then
	selected_title=$(
		printf "%s\n" "${menu_list[@]}" | fzf --prompt="Search YouTube: " \
			--preview="bash -c '
                # This script is now explicitly run with bash.
                # The line number {n} is passed as an argument, which we access via \$1.
                idx=\$((\$1))
                
                # Get video ID from the exported json_data
                id=\$(echo \"\$json_data\" | jq -r \".[\$idx].id\")
                
                if [[ -n \"\$id\" && \"\$id\" != \"null\" ]]; then
                    thumb=\"https://i.ytimg.com/vi/\$id/hqdefault.jpg\"
                    img_path=\"\$TMPDIR/thumb_\$id.jpg\"
                    
                    # Download thumbnail only if it does not already exist
                    [[ ! -f \"\$img_path\" ]] && curl -fsSL \"\$thumb\" -o \"\$img_path\"
                    
                    # Render thumbnail using chafa
                    chafa --symbols=block --size=80x40 \"\$img_path\" || echo \"(failed to render thumbnail)\"
                fi
            ' -- {n}"
	)
elif command -v rofi &>/dev/null; then
	selected_title=$(printf "%s\n" "${menu_list[@]}" | rofi -dmenu -p "Search YouTube:")
else
	echo "fzf with chafa, or rofi is required." >&2
	exit 1
fi

[ -z "$selected_title" ] && exit 1

# Find index of selection
selected_index=-1
for i in "${!menu_list[@]}"; do
	if [[ "${menu_list[$i]}" == "$selected_title" ]]; then
		selected_index=$i
		break
	fi
done

if [[ $selected_index -lt 0 ]]; then
	echo "Could not resolve selected video. Exiting."
	exit 1
fi

# Get video id and build the correct URL
video_id=$(echo "$json_data" | jq -r ".[$selected_index].id")
video_url="https://www.youtube.com/watch?v=$video_id"

echo "▶ Launching: $selected_title"
mpv "$video_url"
