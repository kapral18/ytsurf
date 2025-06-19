# ytsurf

A simple shell script to search YouTube videos from your terminal and play them with mpv.

## Demo

https://github.com/user-attachments/assets/8c0d4057-db7b-457d-88cf-39aa782a1c6c

## Features

- Search YouTube from terminal
- Interactive selection with fzf (thumbnail previews) or rofi
- 10-minute result caching
- Direct mpv playback

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

Add `~/.local/bin` to your PATH if needed:

```bash
export PATH="$HOME/.local/bin:$PATH"
```

## Dependencies

Required: `bash`, `yt-dlp`, `jq`, `curl`, `mpv`, `fzf`, `chafa` (for thumbnails)
Optional: `rofi`

Install on Arch: `sudo pacman -S yt-dlp jq curl mpv fzf chafa rofi`

## Usage

```bash
ytsurf lofi hip hop study
```

Or run without arguments to enter interactive mode:

```bash
ytsurf
```

Navigate results with arrows, press Enter to play with mpv.

## License

This script is released under the [GNU General Public License v3.0](LICENSE).
