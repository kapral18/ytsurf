# ytsurf
## Demo

https://github.com/user-attachments/assets/8c0d4057-db7b-457d-88cf-39aa782a1c6c

**ytsurf** is a simple shell script that allows you to search for YouTube videos from your terminal, select one using fzf (with image previews via chafa) or rofi, and then play it with mpv. It leverages yt-dlp for fetching video information and jq for JSON parsing.

## Features

- **Terminal-based Youtube**: Quickly find videos without leaving your terminal.
- **Interactive selection**: Use fzf (with optional thumbnail previews) or rofi to pick a video.
- **Caching**: Caches search results for 10 minutes to speed up subsequent searches for the same query.
- **mpv integration**: Plays the selected video directly using mpv.
- **Lightweight and fast**: Built with common Unix tools.

## Prerequisites

Before running ytsurf, you need to have the following tools installed on your system:

- **bash**: The shell the script is written in.
- **yt-dlp**: A command-line program to download videos and extract information from YouTube and other video sites.
- **jq**: A lightweight and flexible command-line JSON processor.
- **curl**: Used for downloading video thumbnails.
- **mpv**: A free, open-source, and cross-platform media player.
- **fzf** (Optional, recommended): A general-purpose command-line fuzzy finder.
- **chafa** (Optional, recommended with fzf): A command-line utility to display image previews in the terminal.
- **rofi** (Optional, alternative to fzf): A window switcher, run launcher, dmenu replacement, etc.

You can usually install these using your distribution's package manager. For example:

### Arch Linux:

```bash
sudo pacman -S bash yt-dlp jq curl mpv fzf chafa rofi
```

### Debian/Ubuntu:

```bash
sudo apt update
sudo apt install bash yt-dlp jq curl mpv fzf chafa rofi
```

### Fedora:

```bash
sudo dnf install bash yt-dlp jq curl mpv fzf chafa rofi
```

## Installation

1. **Save the script**:
   Save the provided script content to a file named `ytsurf` (or any name you prefer) in a directory that is in your system's PATH (e.g., `~/bin`, `/usr/local/bin`).

    ```bash
    mkdir -p ~/.local/bin
    curl -o ~/.local/bin/ytsurf https://raw.githubusercontent.com/Stan-breaks/ytsurf/main/ytsurf.sh
    chmod +x ~/.local/bin/ytsurf
    ```

    **Note**: If you're copying and pasting, create the file manually:

    ```bash
    mkdir -p ~/.local/bin
    vim ~/.local/bin/ytsurf # Or nano, or your preferred editor
    # Paste the script content
    # Save and exit
    chmod +x ~/.local/bin/ytsurf
    ```

2. **Ensure ~/.local/bin is in your PATH**:
   If `~/.local/bin` isn't already in your PATH, add the following line to your `~/.bashrc`, `~/.zshrc`, or equivalent shell configuration file:

    ```bash
    export PATH="$HOME/.local/bin:$PATH"
    ```

    Then, reload your shell configuration:

    ```bash
    source ~/.bashrc # Or ~/.zshrc
    ```

## Usage

To search for a YouTube video, simply run `ytsurf` followed by your search query:

```bash
ytsurf "lofi hip hop study"
```

If you run `ytsurf` without any arguments, it will prompt you to enter a search query:

```bash
ytsurf
```

```
Enter Youtube: [type your query here]
```

After entering your query, a fzf (or rofi) menu will appear, listing the top 10 search results.

- **With fzf (and chafa)**: You'll see a list of videos with their truncated titles, durations, and uploaders. As you navigate the list, chafa will display a thumbnail preview of the selected video.
- **With rofi**: You'll see a similar list in a rofi window.

Use your arrow keys or type to fuzzy-search the list, then press Enter to select a video. The script will then launch mpv to play the selected video.

## Configuration

- **CACHE_DIR**: The script uses `~/.cache/ytsurf` by default for caching search results. This adheres to the XDG Base Directory Specification.
- **yt-dlp search limit**: The script is hardcoded to fetch `ytsearch10` results (top 10). You can modify this in the json_data fetching line if you need more or fewer results.
- **Title truncation**: The jq command truncates titles to 30 characters in the menu list. Adjust `length > 30 then .[:30]` to your preference.

## Troubleshooting

- **"No results found"**: Ensure your yt-dlp installation is working correctly and that your query is not too restrictive.
- **fzf / chafa / rofi not found**: Make sure you have installed at least fzf and chafa, or rofi, and that they are in your PATH.
- **Thumbnail issues**: If thumbnails don't display with fzf and chafa, check your curl installation and ensure you have an internet connection. chafa might also have issues with certain terminal emulators or font settings.
- **mpv issues**: If mpv doesn't play the video, verify your mpv installation and ensure it can access YouTube content (it relies on yt-dlp internally for this).

## License

This script is released under the MIT License.
