# ytsurf

A simple shell script to search YouTube videos from your terminal and play them with mpv.

## Demo

<img width="1366" height="768" alt="250814_13h56m36s_screenshot" src="https://github.com/user-attachments/assets/0771f53b-ad16-41a2-9938-9aaaf0eaa1ae" />

## Features

- Search YouTube from your terminal
- Interactive selection with `fzf` (thumbnail previews), `rofi`, or simple numbered menu fallback
- Download videos or audio
- Select video format/quality
- External config file for default options
- 10-minute result caching
- Playback history
- Audio-only mode
- Channel search
- Limit search results
- Graceful fallback when advanced tools aren't available
- Desktop and terminal notifications

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
- `ffmpeg` - for video processing

**Note:** Optional dependency warnings are suppressed by default. To see them, set `YTSURF_SHOW_INFO=true` before running ytsurf.

**Install on Arch Linux:**

Minimal installation (required only)
`sudo pacman -S yt-dlp jq curl mpv`

Full installation (recommended)
`sudo pacman -S yt-dlp jq curl mpv fzf chafa libnotify ffmpeg rofi`

**Install on Debian/Ubuntu:**

Minimal installation (required only)
`sudo apt install yt-dlp jq curl mpv`

Full installation (recommended)
`sudo apt install yt-dlp jq curl mpv fzf chafa libnotify-bin ffmpeg rofi`

## Usage

```bash
# Basic search
ytsurf lofi hip hop study

# Search with 25 results instead of the default 10
ytsurf --limit 25 dnb mix

# Audio-only playback
ytsurf --audio npr tiny desk

# Download the selected video
ytsurf --download how to make ramen

# Select a specific video format before playback/download
ytsurf --format space video

# View watch history
ytsurf --history

# Use rofi instead of fzf (requires rofi to be installed)
ytsurf --rofi

# interactive use
ytsurf

```

You can also run `ytsurf` without arguments to enter interactive search mode. All flags can be combined.

## Configuration

You can set default options by creating a config file at `~/.config/ytsurf/config`. Command-line flags will always override the config file.

**Example Config:**

```bash
# ~/.config/ytsurf/config

# Set a higher default search limit
limit=25

# Always use audio-only mode by default
audio_only=true

# Set a custom download directory
download_dir="$HOME/Videos/YouTube"

# Use rofi by default (requires rofi to be installed)
use_rofi=true
```

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
