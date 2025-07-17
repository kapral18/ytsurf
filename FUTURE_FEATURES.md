# Future Feature Ideas

This document lists potential features for future development.

### 1. Playlist Support
- **Idea:** Add a `--playlist` flag to search for and select YouTube playlists.
- **Implementation:** When a playlist is selected, the script could either play the entire playlist sequentially in `mpv` or open a second `fzf` menu to allow the user to pick a specific video from it.
- **Benefit:** Expands the script's capability from single videos to entire series or music albums.

### 2. Subscription/Channel Feed Mode
- **Idea:** Create a `--subscriptions` mode that fetches the latest videos from a predefined list of favorite channels.
- **Implementation:** Users would maintain a simple text file of channel URLs (e.g., `~/.config/ytsurf/subscriptions.txt`). This mode would parse the list, fetch the most recent videos from each channel, and present them in a single, chronologically sorted `fzf` menu.
- **Benefit:** Creates a powerful, terminal-based YouTube subscription feed, turning `ytsurf` into a content aggregator.

### 3. Video Queueing
- **Idea:** Allow the user to select multiple videos in `fzf` to create a temporary playback queue.
- **Implementation:** Use `fzf`'s multi-select feature (e.g., by pressing `Tab` on multiple entries). The script would gather the selected video URLs and pass them to `mpv` to be played sequentially.
- **Benefit:** Ideal for creating on-the-fly music playlists or watching several short videos without interruption.
