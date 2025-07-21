#!/bin/bash
set -euo pipefail

# -- CONFIGURATION --
# The script sources a config file for default settings.
# You can override these by creating a file at ~/.config/ytsurf/config
# Example config:
#
# # Default number of search results
# limit=20
# # Always use audio-only mode
# audio_only=true
# # Use rofi by default
# use_rofi=false
# # Set default download directory
# download_dir="$HOME/Downloads"

# Default values
limit=10
audio_only=false
use_rofi=false
download_mode=false
history_mode=false
channel_mode=false
format_selection=false
download_dir="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"

# System directories
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/ytsurf"
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/ytsurf"
mkdir -p "$CACHE_DIR" "$CONFIG_DIR"
HISTORY_FILE="$CACHE_DIR/history.json"
touch "$HISTORY_FILE"

# Source user config file if it exists
CONFIG_FILE="$CONFIG_DIR/config"
if [[ -f "$CONFIG_FILE" ]]; then
	# shellcheck source=/dev/null
	source "$CONFIG_FILE"
fi

# Temporary directory for thumbnails
TMPDIR=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR"; }
trap cleanup EXIT

# -- ARGUMENT PARSING --
query=""
# Command-line flags override config file settings
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
	--download)
		download_mode=true
		shift
		;;
	--format)
		format_selection=true
		shift
		;;
	--limit)
		shift
		if [[ -n "$1" && "$1" =~ ^[0-9]+$ ]]; then
			limit="$1"
			shift
		else
			echo "Error: --limit requires a number" >&2
			exit 1
		fi
		;;
	*)
		query="$*"
		break
		;;
	esac
done

# -- FUNCTIONS --

# Selects a video/audio format based on user input
select_format() {
	local video_url="$1"

	# If --audio is passed with --format, non-interactively select bestaudio.
	if [[ "$audio_only" = true ]]; then
		echo "bestaudio"
		return 0
	fi

	# For video mode, prompt the user to select a quality.
	local format_list
	format_list=$(yt-dlp -F "$video_url")

	if [[ -z "$format_list" ]]; then
		echo "Could not retrieve formats for the selected video." >&2
		exit 1
	fi

	local chosen_format=""
	local prompt="Select video quality:"
	local header="Available Resolutions"
	mapfile -t format_options < <(echo "$format_list" | grep -oE '[0-9]+p[0-9]*' | sort -rn | uniq)

	local chosen_res
	if [[ "$use_rofi" = true ]]; then
		chosen_res=$(printf "%s\n" "${format_options[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
	else
		chosen_res=$(printf "%s\n" "${format_options[@]}" | fzf --prompt="$prompt" --header="$header")
	fi

	if [[ -n "$chosen_res" ]]; then
		if [[ "$chosen_res" == "best" || "$chosen_res" == "worst" ]]; then
			chosen_format="$chosen_res"
		else
			local height=${chosen_res%p*}
			chosen_format="bestvideo[height<=${height}]+bestaudio/best[height<=${height}]"
		fi
	fi

	if [[ -n "$chosen_format" ]]; then
		echo "$chosen_format"
		return 0
	else
		return 1 # User cancelled selection
	fi
}

# Plays or downloads the selected video
perform_action() {
	local video_url="$1"
	local video_title="$2"

	local format_code=""
	if [[ "$format_selection" = true ]]; then
		format_code=$(select_format "$video_url") || exit 1
	fi

	echo "▶ Performing action on: $video_title"
	if [[ "$download_mode" = true ]]; then
		mkdir -p "$download_dir"
		echo "Downloading to $download_dir..."
		if [[ "$audio_only" = true ]]; then
			yt-dlp -x -o "$download_dir/%(title)s [%(id)s].%(ext)s" --audio-format mp3 --audio-quality 0 "$video_url"
		else
			yt-dlp \
				--remux-video mp4 \
				-o "$download_dir/%(title)s [%(id)s].%(ext)s" \
				${format_code:+--format "$format_code"} \
				"$video_url"
		fi
	else
		if [[ "$audio_only" = true ]]; then
			mpv --no-video --really-quiet ${format_code:+--ytdl-format="$format_code"} "$video_url"
		else
			mpv --really-quiet ${format_code:+--ytdl-format="$format_code"} "$video_url"
		fi
	fi
}

# Adds a video to the history log
add_to_history() {
	local video_id="$1"
	local video_title="$2"
	local video_duration="$3"
	local video_author="$4"
	local video_views="$5"
	local tmp_history
	tmp_history="$(mktemp)"
	jq -n --arg title "$video_title" --arg id "$video_id" --arg duration "$video_duration" --arg author "$video_author" --arg views "$video_views" '{title: $title, id: $id, duration: $duration, author: $author, views: $views}' >"$tmp_history"
	jq -c --arg id "$video_id" 'select(.id != $id)' "$HISTORY_FILE" >>"$tmp_history" 2>/dev/null || true
	mv "$tmp_history" "$HISTORY_FILE"
}

# -- SCRIPT LOGIC --

# Handle history mode
if [[ "$history_mode" = true ]]; then
	if [[ ! -s "$HISTORY_FILE" ]]; then
		echo "No watched history yet."
		exit 0
	fi

	mapfile -t history_ids < <(jq -r '.id' "$HISTORY_FILE" 2>/dev/null || echo "")
	mapfile -t history_titles < <(jq -r '.title' "$HISTORY_FILE" 2>/dev/null || echo "")

	if [[ ${#history_titles[@]} -eq 0 || ${#history_ids[@]} -eq 0 ]]; then
		echo "History is empty or corrupted."
		exit 0
	fi
	json_data=$(cat "$HISTORY_FILE")

	export json_data
	declare -p history_ids history_titles >"/tmp/history_ids"
	export TMPDIR

	selected_title=""
	if [[ "$use_rofi" = true ]]; then
		selected_title=$(printf "%s\n" "${history_titles[@]}" | rofi -dmenu -p "Watch history:")
	else
		selected_title=$(printf "%s\n" "${history_titles[@]}" | fzf --prompt="Watch history: " \
			--preview="bash -c '                                                                        
        format_views() {
            local n=\$1
            if [[ \"\$n\" == \"null\" || -z \"\$n\" || \"\$n\" == \"0\" ]]; then
                echo \"N/A\"
            elif (( n >= 1000000 )); then
                echo \"\$((n / 1000000))M views\"
            elif (( n >= 1000 )); then
                echo \"\$((n / 1000))K views\"
            else
                echo \"\$n views\"
            fi
        }

     source /tmp/history_ids                                                  
     idx=\$((\$1))                                                                                  
     id=\"\${history_ids[\$idx]}\"
     title=\"\${history_titles[\$idx]}\"
     duration=\$(echo \"\$json_data\" | jq -r -s \".[\$idx].duration\" 2>/dev/null)
     views=\$(echo \"\$json_data\" | jq -r -s \".[\$idx].views\" 2>/dev/null)
     author=\$(echo \"\$json_data\" | jq -r -s \".[\$idx].author\" 2>/dev/null)


     if [[ -n \"\$id\" && \"\$id\" != \"null\" ]]; then                                             
         echo
         echo
         echo -e \"\\033[1;35mFrom History\\033[0m\"
         echo -e \"\\033[1;36mTitle:\\033[0m \\033[1m\$title\\033[0m\"
         echo -e \"\\033[1;33mDuration:\\033[0m \$duration\"
         echo -e \"\\033[1;32mViews:\\033[0m \$(format_views \"\$views\")\"
         echo -e \"\\033[1;35mAuthor:\\033[0m \$author\"         echo
         echo
         thumb=\"https://i.ytimg.com/vi/\$id/hqdefault.jpg\"                                        
         img_path=\"\$TMPDIR/thumb_\$id.jpg\"                                                       
         [[ ! -f \"\$img_path\" ]] && curl -fsSL \"\$thumb\" -o \"\$img_path\" 2>/dev/null                      
         chafa --symbols=block --size=80x40 \"\$img_path\" 2>/dev/null || echo \"(failed to render thumbnail)\";
         echo
     else
        echo \"No preview available\"
     fi' -- {n}")
	fi

	[ -z "$selected_title" ] && exit 1

	selected_index=-1
	for i in "${!history_titles[@]}"; do
		if [[ "${history_titles[$i]}" == "$selected_title" ]]; then
			selected_index=$i
			break
		fi
	done

	if [[ $selected_index -lt 0 ]]; then
		echo "Could not resolve selected video. Exiting." >&2
		exit 1
	fi

	video_id="${history_ids[$selected_index]}"
	video_url="https://www.youtube.com/watch?v=$video_id"

	add_to_history "$video_id" "$video_title" "$video_duration" "$video_author" "$video_views"
	perform_action "$video_url" "$selected_title"
	exit 0
fi

# Handle search mode
if [[ -z "$query" ]]; then
	if [[ "$use_rofi" = true ]]; then
		query=$(rofi -dmenu -p "Enter YouTube search:")
	else
		read -rp "Enter YouTube search: " query
	fi
fi

[[ -z "$query" ]] && {
	echo "No query entered. Exiting."
	exit 1
}

# Caching logic
cache_key=$(echo -n "$query" | sha256sum | cut -d' ' -f1)
cache_file="$CACHE_DIR/$cache_key.json"

if [[ -f "$cache_file" && $(find "$cache_file" -mmin -10 2>/dev/null) ]]; then
	json_data=$(cat "$cache_file")
else
	search_expr="ytsearch${limit}:${query}"
	[[ "$channel_mode" = true ]] && search_expr+="/channel"
	json_data=$(yt-dlp "$search_expr" --flat-playlist --print-json --no-warnings | jq -s '.')
	echo "$json_data" >"$cache_file"
fi

# Build menu list
mapfile -t menu_list < <(echo "$json_data" | jq -r '.[]|.title' 2>/dev/null)

if [[ ${#menu_list[@]} -eq 0 ]]; then
	echo "No results found for '$query'"
	exit 0
fi

export json_data
export TMPDIR

# Main selection menu
selected_title=""
if [[ "$use_rofi" = true ]] && command -v rofi &>/dev/null; then
	selected_title=$(printf "%s\n" "${menu_list[@]}" | rofi -dmenu -p "Search YouTube:")
elif command -v fzf &>/dev/null && command -v chafa &>/dev/null; then
	selected_title=$(
		printf "%s\n" "${menu_list[@]}" | fzf --prompt="Search YouTube: " \
			--preview="bash -c '
     format_views() {
            local n=\$1
            if [[ \"\$n\" == \"null\" || -z \"\$n\" || \"\$n\" == \"0\" ]]; then
                echo \"N/A\"
            elif (( n >= 1000000 )); then
                echo \"\$((n / 1000000))M views\"
            elif (( n >= 1000 )); then
                echo \"\$((n / 1000))K views\"
            else
                echo \"\$n views\"
            fi
        }

     idx=\$((\$1))                                                                                    
     id=\$(echo \"\$json_data\" | jq -r \".[\$idx].id\" 2>/dev/null)                                          
     title=\$(echo \"\$json_data\" | jq -r \".[\$idx].title\" 2>/dev/null)
     duration=\$(echo \"\$json_data\" | jq -r \".[\$idx].duration_string\" 2>/dev/null)
     views=\$(echo \"\$json_data\" | jq -r \".[\$idx].view_count\" 2>/dev/null)
     author=\$(echo \"\$json_data\" | jq -r \".[\$idx].uploader\" 2>/dev/null)

     if [[ -n \"\$id\" && \"\$id\" != \"null\" ]]; then                                               
         echo 
         echo
         echo -e \"\\033[1;36mTitle:\\033[0m \\033[1m\$title\\033[0m\"
         echo -e \"\\033[1;33mDuration:\\033[0m \$duration\"
         echo -e \"\\033[1;32mViews:\\033[0m \$(format_views \"\$views\")\"
         echo -e \"\\033[1;35mAuthor:\\033[0m \$author\"
         echo 
         echo
         thumb=\"https://i.ytimg.com/vi/\$id/hqdefault.jpg\"                                          
         img_path=\"\$TMPDIR/thumb_\$id.jpg\"                                                         
         [[ ! -f \"\$img_path\" ]] && curl -fsSL \"\$thumb\" -o \"\$img_path\" 2>/dev/null
         chafa --symbols=block --size=80x40 \"\$img_path\" 2>/dev/null || echo \"(failed to render thumbnail)\"   
              else
        echo \"No preview available\"
     fi
 ' -- {n}"
	)
else
	echo "fzf with chafa, or rofi is required for the interactive menu." >&2
	exit 1
fi

[ -z "$selected_title" ] && exit 1

# Resolve selection
selected_index=-1
for i in "${!menu_list[@]}"; do
	if [[ "${menu_list[$i]}" == "$selected_title" ]]; then
		selected_index=$i
		break
	fi
done

if [[ $selected_index -lt 0 ]]; then
	echo "Could not resolve selected video. Exiting." >&2
	exit 1
fi

video_id=$(echo "$json_data" | jq -r ".[$selected_index].id" 2>/dev/null)
video_author=$(echo "$json_data" | jq -r ".[$selected_index].uploader" 2>/dev/null)
video_duration=$(echo "$json_data" | jq -r ".[$selected_index].duration_string" 2>/dev/null)
video_views=$(echo "$json_data" | jq -r ".[$selected_index].view_count" 2>/dev/null)

video_url="https://www.youtube.com/watch?v=$video_id"
video_title="$selected_title"

add_to_history "$video_id" "$video_title" "$video_duration" "$video_author" "$video_views"
perform_action "$video_url" "$video_title"
