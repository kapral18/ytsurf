#!/usr/bin/env bash
set -euo pipefail

#=============================================================================
# ytsurf - search, stream, or download YouTube videos from your terminal 🎵📺
# Version: 1.8.0
#=============================================================================

# Exit if not running in bash
if [[ -z "$BASH_VERSION" ]]; then
  echo "This script requires Bash." >&2
  exit 1
fi

#=============================================================================
# CONSTANTS AND DEFAULTS
#=============================================================================

readonly SCRIPT_VERSION="1.8.0"
readonly SCRIPT_NAME="ytsurf"

# Default configuration values
DEFAULT_LIMIT=10
DEFAULT_AUDIO_ONLY=false
DEFAULT_USE_ROFI=false
DEFAULT_DOWNLOAD_MODE=false
DEFAULT_HISTORY_MODE=false
DEFAULT_FORMAT_SELECTION=false
DEFAULT_MAX_HISTORY_ENTRIES=100

# System directories
readonly CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/$SCRIPT_NAME"
readonly CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/$SCRIPT_NAME"
readonly HISTORY_FILE="$CACHE_DIR/history.json"
readonly CONFIG_FILE="$CONFIG_DIR/config"
readonly FIRST_RUN_FILE="$CACHE_DIR/.ytsurf_first_run_complete"

#=============================================================================
# GLOBAL VARIABLES
#=============================================================================

# Configuration variables (will be set from defaults, config file, and CLI args)
limit="$DEFAULT_LIMIT"
audio_only="$DEFAULT_AUDIO_ONLY"
use_rofi="$DEFAULT_USE_ROFI"
download_mode="$DEFAULT_DOWNLOAD_MODE"
history_mode="$DEFAULT_HISTORY_MODE"
format_selection="$DEFAULT_FORMAT_SELECTION"
download_dir="${XDG_DOWNLOAD_DIR:-$HOME/Downloads}"
max_history_entries="$DEFAULT_MAX_HISTORY_ENTRIES"

# Runtime variables
query=""
TMPDIR=""

#=============================================================================
# UTILITY FUNCTIONS
#=============================================================================

# Print help message
print_help() {
  cat <<EOF
$SCRIPT_NAME - search, stream, or download YouTube videos from your terminal 🎵📺

USAGE:
  $SCRIPT_NAME [OPTIONS] [QUERY]

OPTIONS:
  --audio         Play/download audio-only version
  --download      Download instead of playing
  --format        Interactively choose format/resolution
  --rofi          Use rofi instead of fzf for menus
  --history       Show and replay from viewing history
  --limit <N>     Limit number of search results (default: $DEFAULT_LIMIT)
  --help, -h      Show this help message
  --version       Show version info

CONFIG:
  $CONFIG_FILE can contain default options like:
    limit=15
    audio_only=true
    use_rofi=true
    download_dir=~/Videos/YouTube

EXAMPLES:
  $SCRIPT_NAME lo-fi study mix
  $SCRIPT_NAME --audio orchestral soundtrack
  $SCRIPT_NAME --download --format jazz piano
  $SCRIPT_NAME --history

ENVIRONMENT:
  YTSURF_SHOW_INFO=true  Show optional dependency information
EOF
}

# Print version information
print_version() {
  echo "$SCRIPT_NAME v$SCRIPT_VERSION"
}

# Initialize directories and files
init_directories() {
  mkdir -p "$CACHE_DIR" "$CONFIG_DIR"
  if [[ ! -f "$HISTORY_FILE" ]]; then
    echo "[]" >"$HISTORY_FILE"
  elif ! jq -e 'type == "array"' "$HISTORY_FILE" >/dev/null 2>&1; then
    echo "Warning: History file corrupted, resetting" >&2
    echo "[]" >"$HISTORY_FILE"
  fi
}

# Validate configuration value
validate_config_value() {
  local key="$1"
  local value="$2"

  case "$key" in
  limit | max_history_entries)
    if ! [[ "$value" =~ ^[0-9]+$ ]] || [[ "$value" -lt 1 ]] || [[ "$value" -gt 100 ]]; then
      echo "Warning: Invalid $key value '$value', using default" >&2
      return 1
    fi
    ;;
  audio_only | use_rofi | download_mode | history_mode | format_selection)
    if [[ "$value" != "true" && "$value" != "false" ]]; then
      echo "Warning: Invalid $key value '$value', using default" >&2
      return 1
    fi
    ;;
  download_dir)
    # Just check if it's not empty
    if [[ -z "$value" ]]; then
      echo "Warning: Empty download_dir, using default" >&2
      return 1
    fi
    ;;
  esac
  return 0
}

# Load configuration from file
load_config() {
  if [[ -f "$CONFIG_FILE" ]]; then
    # Read config line by line for safer parsing
    while IFS='=' read -r key value; do
      # Skip comments and empty lines
      [[ "$key" =~ ^[[:space:]]*# ]] && continue
      [[ -z "$key" ]] && continue

      # Remove leading/trailing whitespace
      key="${key// /}"
      value="${value#"${value%%[![:space:]]*}"}"
      value="${value%"${value##*[![:space:]]}"}"

      # Validate and set values
      if validate_config_value "$key" "$value"; then
        case "$key" in
        limit) limit="$value" ;;
        audio_only) audio_only="$value" ;;
        use_rofi) use_rofi="$value" ;;
        download_mode) download_mode="$value" ;;
        format_selection) format_selection="$value" ;;
        download_dir) download_dir="$value" ;;
        max_history_entries) max_history_entries="$value" ;;
        esac
      fi
    done <"$CONFIG_FILE"
  fi
}

# Setup cleanup trap
setup_cleanup() {
  TMPDIR=$(mktemp -d)
  trap 'rm -rf "$TMPDIR"' EXIT
}

# Check if this is the first run
is_first_run() {
  [[ ! -f "$FIRST_RUN_FILE" ]]
}

# Mark first run as complete
mark_first_run_complete() {
  touch "$FIRST_RUN_FILE"
}

# Validate required dependencies
check_dependencies() {
  local missing_deps=()

  # Required dependencies
  local required_deps=("yt-dlp" "mpv" "jq" "curl")
  for dep in "${required_deps[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
      missing_deps+=("$dep")
    fi
  done

  if [[ ${#missing_deps[@]} -ne 0 ]]; then
    echo "Error: Missing required dependencies: ${missing_deps[*]}" >&2
    echo "Please install the missing packages and try again." >&2
    exit 1
  fi

  # Menu system check (optional - we have fallback)
  local has_advanced_menu=false
  if command -v "fzf" &>/dev/null || command -v "rofi" &>/dev/null; then
    has_advanced_menu=true
  fi

  # Show optional dependency info only on first run or when explicitly requested
  local show_optional_info="${YTSURF_SHOW_INFO:-false}"

  if [[ "$show_optional_info" == "true" ]] || is_first_run; then
    local optional_missing=()

    if [[ "$has_advanced_menu" == false ]]; then
      optional_missing+=("fzf or rofi (using basic menu)")
    fi

    if ! command -v "chafa" &>/dev/null; then
      optional_missing+=("chafa (no thumbnail previews)")
    fi

    if ! command -v "notify-send" &>/dev/null; then
      optional_missing+=("notify-send (using terminal notifications)")
    fi

    if ! command -v "ffmpeg" &>/dev/null; then
      optional_missing+=("ffmpeg (limited format conversion)")
    fi

    if [[ ${#optional_missing[@]} -gt 0 ]] && is_first_run; then
      echo "┌─────────────────────────────────────────────────────┐"
      echo "│ Optional dependencies for enhanced experience:      │"
      echo "├─────────────────────────────────────────────────────┤"
      for dep in "${optional_missing[@]}"; do
        printf "│ • %-49s │\n" "$dep"
      done
      echo "├─────────────────────────────────────────────────────┤"
      echo "│ Set YTSURF_SHOW_INFO=true to see this again        │"
      echo "└─────────────────────────────────────────────────────┘"
      echo
      mark_first_run_complete
    elif [[ "$show_optional_info" == "true" ]]; then
      for dep in "${optional_missing[@]}"; do
        echo "Info: $dep" >&2
      done
    fi
  fi

  if [[ "$has_advanced_menu" == false ]]; then
    use_rofi=false # Force fallback to bash menu
  fi
}

#=============================================================================
# FILE LOCKING FOR THUMBNAILS
#=============================================================================

download_thumbnail_with_lock() {
  local url="$1"
  local output_path="$2"
  local lock_file="${output_path}.lock"

  # Try to acquire lock (timeout after 5 seconds)
  local count=0
  while [[ -f "$lock_file" ]] && [[ $count -lt 50 ]]; do
    sleep 0.1
    ((count++))
  done

  # If file already exists and is valid, return
  if [[ -f "$output_path" ]] && [[ -s "$output_path" ]]; then
    return 0
  fi

  # Create lock file
  echo $$ >"$lock_file"

  # Download thumbnail
  if curl -fsSL "$url" -o "$output_path" 2>/dev/null; then
    rm -f "$lock_file"
    return 0
  else
    rm -f "$lock_file" "$output_path"
    return 1
  fi
}

#=============================================================================
# NOTIFICATION SYSTEM
#=============================================================================

show_notification() {
  local title="$1"
  local message="$2"
  local icon="${3:-}"

  if command -v notify-send &>/dev/null; then
    if [[ -n "$icon" ]] && [[ -f "$icon" ]]; then
      notify-send -t 5000 -i "$icon" "$title" "$message" 2>/dev/null || true
    else
      notify-send -t 5000 "$title" "$message" 2>/dev/null || true
    fi
  else
    # Fallback to terminal output with visual formatting
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "🎵 [$title] $message"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
  fi
}

#=============================================================================
# MENU SYSTEM FALLBACKS
#=============================================================================

bash_select_menu() {
  local prompt="$1"
  shift
  local items=("$@")

  if [[ ${#items[@]} -eq 0 ]]; then
    echo "No items available for selection." >&2
    return 1
  fi

  echo
  echo "── $prompt ──"
  echo

  # Display numbered options
  for i in "${!items[@]}"; do
    printf "%2d) %s\n" "$((i + 1))" "${items[$i]}"
  done

  echo
  while true; do
    if ! read -p "Select option (1-${#items[@]}, or 'q' to quit): " choice; then
      echo "" >&2
      return 1
    fi

    # Handle quit
    if [[ "$choice" == "q" || "$choice" == "Q" ]]; then
      return 1
    fi

    # Validate numeric input
    if [[ "$choice" =~ ^[0-9]+$ ]] && ((choice >= 1 && choice <= ${#items[@]})); then
      echo "${items[$((choice - 1))]}"
      return 0
    else
      echo "Invalid selection. Please enter a number between 1 and ${#items[@]}." >&2
    fi
  done
}

get_user_input() {
  local prompt="$1"
  local input=""

  read -p "$prompt " input
  echo "$input"
}

#=============================================================================
# ARGUMENT PARSING
#=============================================================================

parse_arguments() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --help | -h)
      print_help
      exit 0
      ;;
    --version | -v)
      print_version
      exit 0
      ;;
    --rofi)
      if command -v rofi &>/dev/null; then
        use_rofi=true
      else
        echo "Error: rofi is not installed. Please install rofi or use fzf instead." >&2
        echo "To install on Arch: sudo pacman -S rofi" >&2
        echo "To install on Debian/Ubuntu: sudo apt install rofi" >&2
        exit 1
      fi
      shift
      ;;
    --audio)
      audio_only=true
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
      if [[ -n "${1:-}" && "$1" =~ ^[0-9]+$ ]] && [[ "$1" -ge 1 ]] && [[ "$1" -le 50 ]]; then
        limit="$1"
        shift
      else
        echo "Error: --limit requires a number between 1 and 50" >&2
        exit 1
      fi
      ;;
    *)
      query="$*"
      break
      ;;
    esac
  done
}

#=============================================================================
# ACTION SELECTION
#=============================================================================

select_action() {
  local chosen_action
  local prompt="Select Action:"
  local header="Available Actions"
  local items=("watch" "download")

  if [[ "$use_rofi" == true ]] && command -v rofi &>/dev/null; then
    chosen_action=$(printf "%s\n" "${items[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
  elif [[ "$use_rofi" == false ]] && command -v fzf &>/dev/null; then
    chosen_action=$(printf "%s\n" "${items[@]}" | fzf --prompt="$prompt" --header="$header")
  else
    chosen_action=$(bash_select_menu "$prompt" "${items[@]}")
  fi

  if [[ -z "$chosen_action" ]]; then
    return 1
  elif [[ "$chosen_action" == "watch" ]]; then
    echo false
    return 0
  else
    echo true
    return 0
  fi
}

#=============================================================================
# FORMAT SELECTION
#=============================================================================

select_format() {
  local video_url="$1"

  # If --audio is passed with --format, non-interactively select bestaudio
  if [[ "$audio_only" = true ]]; then
    echo "bestaudio"
    return 0
  fi

  # Get available formats with error handling
  local format_list
  if ! format_list=$(yt-dlp -F "$video_url" 2>/dev/null | grep -E '^[0-9]+'); then
    echo "Error: Could not retrieve formats for the selected video." >&2
    echo "best" # Return default format as fallback
    return 0
  fi

  # Extract unique resolutions
  local format_options=()
  local seen_resolutions=()

  while IFS= read -r line; do
    if [[ "$line" =~ ([0-9]+p) ]]; then
      local res="${BASH_REMATCH[1]}"
      if [[ ! " ${seen_resolutions[*]} " =~ " ${res} " ]]; then
        seen_resolutions+=("$res")
        format_options+=("$res")
      fi
    fi
  done <<<"$format_list"

  # Add special options
  format_options+=("best" "bestaudio")

  if [[ ${#format_options[@]} -eq 0 ]]; then
    echo "best"
    return 0
  fi

  # Present options to user
  local chosen_res
  local prompt="Select video quality:"
  local header="Available Formats"

  if [[ "$use_rofi" = true ]] && command -v rofi &>/dev/null; then
    chosen_res=$(printf "%s\n" "${format_options[@]}" | rofi -dmenu -p "$prompt" -mesg "$header")
  elif [[ "$use_rofi" = false ]] && command -v fzf &>/dev/null; then
    chosen_res=$(printf "%s\n" "${format_options[@]}" | fzf --prompt="$prompt" --header="$header")
  else
    chosen_res=$(bash_select_menu "$prompt" "${format_options[@]}")
  fi

  # Process selection
  if [[ -z "$chosen_res" ]]; then
    return 1 # User cancelled
  fi

  local chosen_format
  if [[ "$chosen_res" == "best" || "$chosen_res" == "bestaudio" ]]; then
    chosen_format="$chosen_res"
  else
    local height=${chosen_res%p*}
    chosen_format="bestvideo[height<=${height}]+bestaudio/best[height<=${height}]"
  fi

  echo "$chosen_format"
  return 0
}

#=============================================================================
# VIDEO ACTIONS
#=============================================================================

perform_action() {
  local video_url="$1"
  local video_title="$2"
  local img_path="$3"

  # Get format if format selection is enabled
  if [[ "$download_mode" == false ]]; then
    local selection
    if ! selection="$(select_action)"; then
      echo "Action selection cancelled" >&2
      return 1
    fi
    download_mode="$selection"
  fi

  local format_code=""
  if [[ "$format_selection" == "true" ]]; then
    if ! format_code=$(select_format "$video_url"); then
      echo "Format selection cancelled." >&2
      return 1
    fi
    echo "Selected format: $format_code"
  fi

  echo "▶ Performing action on: $video_title"

  if [[ "$download_mode" = true ]]; then
    show_notification "$SCRIPT_NAME" "Downloading: $video_title" "$img_path"
    download_video "$video_url" "$format_code"
  else
    show_notification "$SCRIPT_NAME" "Playing: $video_title" "$img_path"
    play_video "$video_url" "$format_code"
  fi
}

download_video() {
  local video_url="$1"
  local format_code="$2"

  if ! mkdir -p "$download_dir"; then
    echo "Error: Cannot create download directory: $download_dir" >&2
    return 1
  fi

  echo "Downloading to $download_dir..."
  local yt_dlp_args=(
    -o "$download_dir/%(title)s [%(id)s].%(ext)s"
    --audio-quality 0
    --no-warnings
  )

  if [[ "$audio_only" = true ]]; then
    yt_dlp_args+=(-x --audio-format mp3)
  else
    if command -v ffmpeg &>/dev/null; then
      yt_dlp_args+=(--remux-video mp4)
    fi
    if [[ -n "$format_code" ]]; then
      yt_dlp_args+=(--format "$format_code")
    fi
  fi

  if yt-dlp "${yt_dlp_args[@]}" "$video_url"; then
    show_notification "$SCRIPT_NAME" "Download complete!" ""
    return 0
  else
    show_notification "$SCRIPT_NAME" "Download failed!" ""
    return 1
  fi
}

play_video() {
  local video_url="$1"
  local format_code="$2"

  local mpv_args=(--really-quiet --geometry=100%x100%+0+0)

  # Fix window size to fit screen properly
  mpv_args+=(--autofit-larger=100%x100% --autofit=85%x85%)

  if [[ "$audio_only" = true ]]; then
    mpv_args+=(--no-video)
  fi

  if [[ -n "$format_code" ]]; then
    mpv_args+=(--ytdl-format="$format_code")
  fi

  mpv "${mpv_args[@]}" "$video_url"
}

#=============================================================================
# HISTORY MANAGEMENT
#=============================================================================

add_to_history() {
  local video_id="$1"
  local video_title="$2"
  local video_duration="$3"
  local video_author="$4"
  local video_views="$5"
  local video_published="$6"
  local video_thumbnail="$7"

  local tmp_history
  tmp_history="$(mktemp)"

  # Validate existing JSON
  if ! jq empty "$HISTORY_FILE" 2>/dev/null; then
    echo "[]" >"$HISTORY_FILE"
  fi

  # Create new entry and merge with existing history
  jq -n \
    --arg title "$video_title" \
    --arg id "$video_id" \
    --arg duration "$video_duration" \
    --arg author "$video_author" \
    --arg views "$video_views" \
    --arg published "$video_published" \
    --arg thumbnail "$video_thumbnail" \
    --argjson max_entries "$max_history_entries" \
    --slurpfile existing "$HISTORY_FILE" \
    '
        {
            title: $title,
            id: $id,
            duration: $duration,
            author: $author,
            views: $views,
            published: $published,
            thumbnail: $thumbnail,
            timestamp: now
        } as $new_entry |
        ([$new_entry] + ($existing[0] | map(select(.id != $id)))) |
        .[0:$max_entries]
        ' >"$tmp_history"

  # Atomic move
  if ! mv "$tmp_history" "$HISTORY_FILE"; then
    echo "Error: Failed to update history file" >&2
    rm -f "$tmp_history"
    return 1
  fi
}

handle_history_mode() {
  if [[ ! -s "$HISTORY_FILE" ]]; then
    echo "No viewing history found."
    exit 0
  fi

  local json_data
  if ! json_data=$(cat "$HISTORY_FILE" 2>/dev/null); then
    echo "Error: Could not read history file." >&2
    exit 1
  fi

  local history_titles=()
  local history_ids=()

  mapfile -t history_ids < <(echo "$json_data" | jq -r '.[].id' 2>/dev/null)
  mapfile -t history_titles < <(echo "$json_data" | jq -r '.[].title' 2>/dev/null)

  if [[ ${#history_titles[@]} -eq 0 ]]; then
    echo "History is empty or corrupted."
    exit 0
  fi

  # Select from history using improved function
  local selected_title
  selected_title=$(select_from_menu "Watch history:" "$json_data" true "${history_titles[@]}")

  if [[ -z "$selected_title" ]]; then
    echo "No selection made."
    exit 1
  fi

  # Find selected video
  local selected_index=-1
  for i in "${!history_titles[@]}"; do
    if [[ "${history_titles[$i]}" == "$selected_title" ]]; then
      selected_index=$i
      break
    fi
  done

  if [[ $selected_index -lt 0 ]]; then
    echo "Error: Could not resolve selected video." >&2
    exit 1
  fi

  # Extract video details
  local video_id video_url
  if [[ $selected_index -ge ${#history_ids[@]} ]]; then
    echo "Error: History data mismatch" >&2
    exit 1
  fi

  video_id="${history_ids[$selected_index]}"
  if [[ -z "$video_id" || "$video_id" == "null" ]]; then
    echo "Error: Invalid video ID in history" >&2
    exit 1
  fi

  video_url="https://www.youtube.com/watch?v=$video_id"

  local video_duration video_author video_views video_published video_thumbnail img_path
  video_duration=$(echo "$json_data" | jq -r ".[$selected_index].duration")
  video_author=$(echo "$json_data" | jq -r ".[$selected_index].author")
  video_views=$(echo "$json_data" | jq -r ".[$selected_index].views")
  video_published=$(echo "$json_data" | jq -r ".[$selected_index].published")
  video_thumbnail=$(echo "$json_data" | jq -r ".[$selected_index].thumbnail")
  img_path="$TMPDIR/thumb_$video_id.jpg"

  # Download thumbnail if needed
  if [[ -n "$video_thumbnail" ]] && [[ "$video_thumbnail" != "null" ]]; then
    download_thumbnail_with_lock "$video_thumbnail" "$img_path"
  fi

  # Update history and perform action
  add_to_history "$video_id" "$selected_title" "$video_duration" "$video_author" "$video_views" "$video_published" "$video_thumbnail"
  perform_action "$video_url" "$selected_title" "$img_path"
}

#=============================================================================
# SEARCH AND SELECTION
#=============================================================================

get_search_query() {
  if [[ -z "$query" ]]; then
    if [[ "$use_rofi" = true ]] && command -v rofi &>/dev/null; then
      query=$(rofi -dmenu -p "Enter YouTube search:")
    else
      query=$(get_user_input "Enter YouTube search:")
    fi
  fi

  if [[ -z "$query" ]]; then
    echo "No query entered. Exiting."
    exit 1
  fi
}

fetch_search_results_ytdlp() {
  local search_query="$1"
  local cache_key cache_file json_data

  # Setup caching
  cache_key=$(echo -n "$search_query" | sha256sum | cut -d' ' -f1)
  cache_file="$CACHE_DIR/$cache_key.json"

  # Check cache (10 minute expiry)
  if [[ -f "$cache_file" ]] && [[ $(find "$cache_file" -mmin -10 2>/dev/null) ]]; then
    if cat "$cache_file" 2>/dev/null; then
      return 0
    fi
  fi

  # Use yt-dlp search instead of scraping
  echo "Searching YouTube..." >&2

  local search_results
  if ! search_results=$(yt-dlp \
    "ytsearch${limit}:${search_query}" \
    --dump-json \
    --flat-playlist \
    --no-warnings \
    --quiet \
    2>/dev/null); then
    echo "Error: Failed to fetch search results using yt-dlp." >&2
    return 1
  fi

  # Parse results into our format
  local parsed_data
  parsed_data=$(echo "$search_results" | jq -s '
    map({
      title: .title,
      id: .id,
      author: (.uploader // .channel // "Unknown"),
      published: (.upload_date // "" |
        if . != "" then
          (.[0:4] + "-" + .[4:6] + "-" + .[6:8])
        else
          "Unknown date"
        end),
      duration: (
        if .duration then
          ((.duration / 60 | floor | tostring) + ":" +
           (.duration % 60 | tostring | if length == 1 then "0" + . else . end))
        else
          "Unknown"
        end
      ),
      views: ((.view_count // 0) | tostring + " views"),
      thumbnail: (.thumbnails | if type == "array" and length > 0 then sort_by(.width) | last.url else null end)
    })
  ' 2>/dev/null)

  if [[ -z "$parsed_data" || "$parsed_data" == "null" || "$parsed_data" == "[]" ]]; then
    echo "Error: No search results found." >&2
    return 1
  fi

  # Cache results
  echo "$parsed_data" >"$cache_file"
  echo "$parsed_data"
}

create_preview_script_fzf() {
  local is_history="${1:-false}"

  cat <<'PREVIEW_SCRIPT'
#!/bin/bash
# fzf passes 1-based line number, convert to 0-based array index
line_num="$1"
idx=$((line_num - 1))
json_file="$2"
is_history="$3"
TMPDIR="$4"

# Read JSON from file
json_data=$(cat "$json_file")

id=$(echo "$json_data" | jq -r ".[$idx].id" 2>/dev/null)
title=$(echo "$json_data" | jq -r ".[$idx].title" 2>/dev/null)
duration=$(echo "$json_data" | jq -r ".[$idx].duration" 2>/dev/null)
views=$(echo "$json_data" | jq -r ".[$idx].views" 2>/dev/null)
author=$(echo "$json_data" | jq -r ".[$idx].author" 2>/dev/null)
published=$(echo "$json_data" | jq -r ".[$idx].published" 2>/dev/null)
thumbnail=$(echo "$json_data" | jq -r ".[$idx].thumbnail" 2>/dev/null)

if [[ -n "$id" && "$id" != "null" ]]; then
    echo
    echo
PREVIEW_SCRIPT

  if [[ "$is_history" = true ]]; then
    echo '    echo -e "\033[1;35m📜 From History\033[0m"'
  fi

  cat <<'PREVIEW_SCRIPT'
    echo -e "\033[1;36m📺 Title:\033[0m \033[1m$title\033[0m"
    echo -e "\033[1;33m⏱  Duration:\033[0m $duration"
    echo -e "\033[1;32m👁  Views:\033[0m $views"
    echo -e "\033[1;35m👤 Author:\033[0m $author"
    echo -e "\033[1;34m📅 Uploaded:\033[0m $published"
    echo
    echo

    if command -v chafa &>/dev/null; then
        img_path="$TMPDIR/thumb_$id.jpg"
        if [[ ! -f "$img_path" ]] && [[ -n "$thumbnail" ]] && [[ "$thumbnail" != "null" ]]; then
            # Download with timeout and silence
            timeout 3 curl -fsSL "$thumbnail" -o "$img_path" 2>/dev/null || true
        fi
        if [[ -f "$img_path" ]]; then
            chafa --symbols=block --size=60x30 "$img_path" 2>/dev/null || echo "(failed to render thumbnail)"
        fi
    fi
    echo
else
    echo "No preview available for item $line_num (index $idx)"
fi
PREVIEW_SCRIPT
}

select_from_menu() {
  local prompt="$1"
  local json_data="$2"
  local is_history="${3:-false}"
  shift 3
  local menu_items=("$@")

  if [[ ${#menu_items[@]} -eq 0 ]]; then
    echo "No items to select from." >&2
    return 1
  fi

  local selected_item=""

  if [[ "$use_rofi" = true ]] && command -v rofi &>/dev/null; then
    # Generate rofi menu with thumbnails
    local rofi_input=""
    local count=0

    for item in "${menu_items[@]}"; do
      local id
      id=$(echo "$json_data" | jq -r ".[$count].id" 2>/dev/null)
      local thumbnail
      thumbnail=$(echo "$json_data" | jq -r ".[$count].thumbnail" 2>/dev/null)

      if [[ -n "$id" ]] && [[ "$id" != "null" ]] && [[ -n "$thumbnail" ]] && [[ "$thumbnail" != "null" ]]; then
        local img_path="$TMPDIR/thumb_$id.jpg"
        download_thumbnail_with_lock "$thumbnail" "$img_path" &
      fi

      rofi_input+="$item\n"
      ((count++))
    done

    # Wait for thumbnail downloads
    wait

    # Show rofi menu
    selected_item=$(echo -e "$rofi_input" | rofi -dmenu -p "$prompt")

  elif [[ "$use_rofi" = false ]] && command -v fzf &>/dev/null; then
    # Create preview script and JSON data file
    local preview_script="$TMPDIR/preview.sh"
    local json_file="$TMPDIR/data.json"

    # Write JSON to file to avoid argument length issues
    echo "$json_data" >"$json_file"

    create_preview_script_fzf "$is_history" >"$preview_script"
    chmod +x "$preview_script"

    # Use fzf with preview
    selected_item=$(printf "%s\n" "${menu_items[@]}" |
      fzf --preview="'$preview_script' {n} '$json_file' '$is_history' '$TMPDIR'" \
        --preview-window=right:50% \
        --prompt="$prompt " \
        --height=100%)
  else
    # Fallback to basic bash menu
    selected_item=$(bash_select_menu "$prompt" "${menu_items[@]}")
  fi

  echo "$selected_item"
}

handle_search_mode() {
  get_search_query

  local json_data
  if ! json_data=$(fetch_search_results_ytdlp "$query"); then
    echo "Failed to fetch search results for '$query'"
    exit 1
  fi

  # Build menu list
  local menu_list=()
  mapfile -t menu_list < <(echo "$json_data" | jq -r '.[].title' 2>/dev/null)

  if [[ ${#menu_list[@]} -eq 0 ]]; then
    echo "No results found for '$query'"
    exit 0
  fi

  # Select video
  local selected_title
  selected_title=$(select_from_menu "Search YouTube:" "$json_data" false "${menu_list[@]}")

  if [[ -z "$selected_title" ]]; then
    echo "No selection made."
    exit 1
  fi

  # Find selected video index
  local selected_index=-1
  for i in "${!menu_list[@]}"; do
    if [[ "${menu_list[$i]}" == "$selected_title" ]]; then
      selected_index=$i
      break
    fi
  done

  if [[ $selected_index -lt 0 ]]; then
    echo "Error: Could not resolve selected video." >&2
    exit 1
  fi

  # Extract video details
  local video_id video_url video_author video_duration video_views video_published video_thumbnail img_path
  video_id=$(echo "$json_data" | jq -r ".[$selected_index].id")

  if [[ -z "$video_id" || "$video_id" == "null" ]]; then
    echo "Error: Invalid video ID" >&2
    exit 1
  fi

  video_url="https://www.youtube.com/watch?v=$video_id"
  video_author=$(echo "$json_data" | jq -r ".[$selected_index].author")
  video_duration=$(echo "$json_data" | jq -r ".[$selected_index].duration")
  video_views=$(echo "$json_data" | jq -r ".[$selected_index].views")
  video_published=$(echo "$json_data" | jq -r ".[$selected_index].published")
  video_thumbnail=$(echo "$json_data" | jq -r ".[$selected_index].thumbnail")
  img_path="$TMPDIR/thumb_$video_id.jpg"

  # Download thumbnail if needed
  if [[ -n "$video_thumbnail" ]] && [[ "$video_thumbnail" != "null" ]]; then
    download_thumbnail_with_lock "$video_thumbnail" "$img_path"
  fi

  # Add to history and perform action
  add_to_history "$video_id" "$selected_title" "$video_duration" "$video_author" "$video_views" "$video_published" "$video_thumbnail"
  perform_action "$video_url" "$selected_title" "$img_path"
}

#=============================================================================
# MAIN EXECUTION
#=============================================================================

main() {
  # Initialize environment
  init_directories
  load_config
  setup_cleanup
  check_dependencies

  # Parse command line arguments
  parse_arguments "$@"

  # Execute appropriate mode
  if [[ "$history_mode" = true ]]; then
    handle_history_mode
  else
    handle_search_mode
  fi
}

# Run main function with all arguments
main "$@"
