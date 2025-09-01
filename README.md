# ytsurf

A simple shell script to search YouTube videos from your terminal and play them with mpv.

## Demo

<img width="1366" height="768" alt="250814_13h56m36s_screenshot" src="https://github.com/user-attachments/assets/0771f53b-ad16-41a2-9938-9aaaf0eaa1ae" />

## Features

- Search YouTube from your terminal using yt-dlp's reliable search API
- Interactive selection with `fzf` (thumbnail previews), `rofi`, or simple numbered menu fallback
- Download videos or audio
- Select video format/quality
- External config file for default options with validation
- 10-minute result caching
- Playback history
- Audio-only mode
- Limit search results (1-50)
- Graceful fallback when advanced tools aren't available
- Desktop and terminal notifications
- Smart dependency notifications (shown only on first run)

## Installation

### Arch Linux (AUR)

```bash
yay -S ytsurf
# or
paru -S ytsurf
```

### Manual Installation

```bash
mkdir -p ~/.local/bin
curl -o ~/.local/bin/ytsurf https://raw.githubusercontent.com/Stan-breaks/ytsurf/main/ytsurf.sh
chmod +x ~/.local/bin/ytsurf
```

Add `~/.local/bin` to your PATH if it's not already there.

## Dependencies

**Required:** `bash`, `yt-dlp`, `jq`, `curl`, `mpv`

**Optional (with fallbacks):**

- `fzf` or `rofi` - for enhanced menus (falls back to simple numbered menu)
- `chafa` - for thumbnail previews (falls back to text-only)
- `notify-send` - for desktop notifications (falls back to terminal output)
- `ffmpeg` - for video format conversion

**Note:** Optional dependency information is shown only on first run. To see it again, run:

```bash
YTSURF_SHOW_INFO=true ytsurf
```

**Install on Arch Linux:**

Minimal installation (required only)

```bash
sudo pacman -S yt-dlp jq curl mpv
```

Full installation (recommended)

```bash
sudo pacman -S yt-dlp jq curl mpv fzf chafa libnotify ffmpeg rofi
```

**Install on Debian/Ubuntu:**

Minimal installation (required only)

```bash
sudo apt install yt-dlp jq curl mpv
```

Full installation (recommended)

```bash
sudo apt install yt-dlp jq curl mpv fzf chafa libnotify-bin ffmpeg rofi
```

## Usage

```bash
# Basic search
ytsurf lofi hip hop study

# Search with 25 results (max: 50)
ytsurf --limit 25 dnb mix

# Audio-only playback
ytsurf --audio npr tiny desk

# Download the selected video
ytsurf --download how to make ramen

# Select a specific video format before playback/download
ytsurf --format space video

# Combine audio-only with format selection (auto-selects best audio)
ytsurf --audio --format podcast

# View watch history
ytsurf --history

# Use rofi instead of fzf (requires rofi to be installed)
ytsurf --rofi jazz fusion

# Interactive use
ytsurf
```

You can also run `ytsurf` without arguments to enter interactive search mode. All flags can be combined.

## Configuration

You can set default options by creating a config file at `~/.config/ytsurf/config`. Command-line flags will always override the config file. Invalid config values will be ignored with a warning.

**Example Config:**

```bash
# ~/.config/ytsurf/config

# Set a higher default search limit (1-50)
limit=25

# Always use audio-only mode by default
audio_only=true

# Set a custom download directory
download_dir="$HOME/Videos/YouTube"

# Use rofi by default (requires rofi to be installed)
use_rofi=true

# Maximum number of history entries to keep (default: 100)
max_history_entries=100
```

## Environment Variables

- `YTSURF_SHOW_INFO=true` - Show optional dependency information even after first run
- `XDG_CACHE_HOME` - Override cache directory location
- `XDG_CONFIG_HOME` - Override config directory location
- `XDG_DOWNLOAD_DIR` - Override default download directory

## Troubleshooting

**No search results found:**

- Ensure yt-dlp is up to date: `yt-dlp -U`
- Check your internet connection

**Format selection not showing options:**

- Some videos may have limited format availability
- The script will fall back to "best" format automatically

**Rofi not working:**

- Ensure rofi is installed: `command -v rofi`
- The script will automatically fall back to fzf or basic menu

**Thumbnails not showing:**

- Install `chafa` for terminal thumbnail previews
- Check that your terminal supports image display

## Contributing

Contributions are welcome! Please read the [Contributing Guidelines](CONTRIBUTING.md) to get started. You can also check out the [Future Features](FUTURE_FEATURES.md) list for ideas.

## License

This script is released under the [GNU General Public License v3.0](LICENSE).

## Star History

<a href="https://www.star-history.com/#Stan-breaks/ytsurf&Date">
 <picture>
   <source media="(prefers-color-scheme: dark)" srcset="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date&theme=dark" />
   <source media="(prefers-color-scheme: light)" srcset="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date" />
   <img alt="Star History Chart" src="https://api.star-history.com/svg?repos=Stan-breaks/ytsurf&type=Date" />
 </picture>
</a>
