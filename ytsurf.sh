#!/bin/bash
set -euo pipefail

# CONFIG
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ytsurf"
mkdir -p "$CACHE_DIR"
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

#creating the history file
HISTORY_FILE="$CACHE_DIR/history.log"
touch "$HISTORY_FILE"

# Parse arguments
use_rofi=false
audio_only=false
channel_mode=false
history_mode=false
query=""

limit=10  # default search result limit

while [[ $# -gt 0 ]]; do
	case "$1" in
	--rofi)
		use_rofi=true
		shift
		;;
	--audio)
		audio_only=true
		shift
		;;
	--channel)
		channel_mode=true
		shift
		;;
	--history)
		history_mode=true
		shift
		;;
	--limit)
		shift
		if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
			limit="$1"
			shift
		else
			echo "Error: --limit requires a number"
			exit 1
		fi
		;;
	*)
		query="$*"
		break
		;;
	esac
done


if [[ "$history_mode" = true ]]; then
	if [[ ! -s "$HISTORY_FILE" ]]; then
		echo "No watched history yet."
		exit 0
	fi

	mapfile -t history_ids < <(jq -r '.id' "$HISTORY_FILE")
	mapfile -t history_titles < <(jq -r '.title' "$HISTORY_FILE")

	# Check if menu is empty
	if [[ ${#history_titles[@]} -eq 0 || ${#history_ids[@]} -eq 0 ]]; then
		echo "No history empty"
		exit 0
	fi

	declare -p history_ids >/tmp/history_ids.sh
	export TMPDIR

	if [[ "$use_rofi" = true ]]; then
		selected_title=$(printf "%s\n" "${history_titles[@]}" | rofi -dmenu -p "Watch history:")
	else
		selected_title=$(
			printf "%s\n" "${history_titles[@]}" | fzf --prompt="Watch history: " \
				--preview="bash -c '
            source /tmp/history_ids.sh
            idx=\$((\$1))
            id=\"\${history_ids[\$idx]}\"
            if [[ -n \"\$id\" && \"\$id\" != \"null\" ]]; then
               thumb=\"https://i.ytimg.com/vi/\$id/hqdefault.jpg\"
               img_path=\"\$TMPDIR/thumb_\$id.jpg\"

            [[ ! -f \"\$img_path\" ]] && curl -fsSL \"\$thumb\" -o \"\$img_path\"
            chafa --symbols=block --size=80x40 \"\$img_path\" || echo \"(failed to render thumbnail)\"
			      fi        
      ' -- {n}"
		)
	fi

	[ -z "$selected_title" ] && exit 1

	selected_index=-1
	for i in "${!history_titles[@]}"; do
		if [[ "${history_titles[$i]}" == "${selected_title}" ]]; then
			selected_index=$i
			break
		fi
	done

	if [[ $selected_index -lt 0 ]]; then
		echo "Could not resolve selected video. Exiting."
		exit 1
	fi

	video_id="${history_ids[$selected_index]}"
	video_url="https://www.youtube.com/watch?v=$video_id"

	echo "▶ Launching: $selected_title"
	if [[ "$audio_only" = true ]]; then
		mpv --no-video "$video_url"
	else
		mpv "$video_url"
	fi
	exit 0
fi

if [[ -z "$query" ]]; then
	read -rp "Enter Youtube: " query
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

	if [[ "$channel_mode" = true ]]; then
		search_expr="ytsearch${limit}:$query channel"
	else
		search_expr="ytsearch10${limit}:$query"
	fi
	json_data=$(yt-dlp "$search_expr" --flat-playlist --print-json --no-warnings | jq -s '.')
	echo "$json_data" >"$cache_file"
fi

# Build menu list with jq: show truncated title, duration (formatted), uploader, view count
mapfile -t menu_list < <(echo "$json_data" | jq -r '
  def pad2(n): if n < 10 then "0" + (n|tostring) else (n|tostring) end;
  def format_views(n):
    if n >= 1000000 then (n / 1000000 | floor | tostring) + "M views"
    elif n >= 1000 then (n / 1000 | floor | tostring) + "K views"
    else (n | tostring) + " views"
    end;

  .[] |
  .title as $title |
  .duration as $dur |
  .uploader as $uploader |
  .view_count as $views |
  (
    pad2($dur / 3600 | floor) + ":" +
    pad2(($dur % 3600) / 60 | floor) + ":" +
    pad2($dur % 60 | floor)
  ) as $duration_fmt |
  (
    ($title | if length > 30 then .[:30] + "..." else . end)
    + " [" + $duration_fmt + "] by " + $uploader
    + " (" + format_views($views) + ")"
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

# Choose item with fzf+chafa
selected_title=""

if [[ "$use_rofi" = true ]] && command -v rofi &>/dev/null; then
	selected_title=$(printf "%s\n" "${menu_list[@]}" | rofi -dmenu -p "Search YouTube:")
elif command -v fzf &>/dev/null && command -v chafa &>/dev/null; then
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

#Add the video to the history
jq -n --arg title "$selected_title" --arg id "$video_id" '{title: $title, id: $id}' >>"$HISTORY_FILE"

echo "▶ Launching: $selected_title"

if [[ "$audio_only" = true ]]; then
	mpv --no-video "$video_url"
else
	mpv "$video_url"
fi
query=""
