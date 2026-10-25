# quickshell-ii: my additions to illogical-impulse

The shell is end-4's [illogical-impulse](https://github.com/end-4/dots-hyprland) (GPL-3.0), installed
with its own installer. This folder holds **only the files I added**, at the same paths as in
`~/.config/quickshell/ii/`. They import ii's modules, so they do not run on their own.

## Added files

| Path | What it is |
|---|---|
| `modules/ii/altTab/` | Alt+Tab across all monitors, most-recently-used order, live window thumbnails; releasing Alt commits. |
| `modules/settings/DisplaysConfig.qml` | "Displays" settings page: layout, refresh rate, the QD-OLED fringe correction. |
| `modules/settings/InputConfig.qml` | Mouse and keyboard page; values applied live with `hyprctl eval` and persisted by `hypr_overrides.py`. |
| `modules/settings/AccessibilityConfig.qml` | Accessibility page (anti-flashbang shader, etc.). |
| `modules/settings/KeybindsConfig.qml` | Searchable list of the live binds (`hyprctl binds -j`). |
| `modules/settings/SidebarConfig.qml` | Editor for the quick-toggle tiles of the sidebar. |
| `scripts/hyprland/hypr_overrides.py` | Reads and writes Hyprland options from the shell (game mode, input settings) through `hyprctl eval`, and saves them to `~/.config/hypr/shell-overrides.{json,lua}`. |
| `scripts/dictate/transcribe_live.py` | Push-to-talk dictation with a local Whisper model (faster-whisper, CPU), streaming partial text to the shell. |
| `modules/ii/jarvis/` | Panel for my local voice assistant: listening / thinking / answering states, and a 3D "neural network" orb in Qt Quick 3D ported from its web version. |
| `modules/ii/bar/HeadsetBattery.qml`, `ClaudeLogo.qml` | Bar widgets: wireless headset battery, Claude Code activity. |
| `modules/ii/onScreenDisplay/indicators/KbdBrightnessIndicator.qml` | Keyboard backlight OSD (laptop). |
| `modules/common/panels/lock/pam/face.conf` | PAM file for face unlock on the laptop (Howdy); off on the desktop. |

## Upstream files I changed (not included here)

About ninety ii files differ from upstream on my machine. The main changes:

- `services/HyprlandData.qml`: the Quickshell.Hyprland workspace objects are wrong on hyprland-git
  (no workspace id in the JSON), so the shell reads `hyprctl … -j` itself, with helpers per monitor.
  Its refresh is debounced: an animated window title used to spawn dozens of `hyprctl` per second.
- All dispatch calls ported to Lua (`hl.dsp.*`), since the text syntax of `hyprctl dispatch` is gone.
- Lock screen: writes a marker while locked, so a restarted shell locks again; face unlock is an option.
- `scripts/colors/switchwall.sh`: hands video wallpapers to `bin/wallpaper-video` instead of
  starting one `mpvpaper` per monitor.
- Cheatsheet and settings read the bind descriptions from `binds.lua`; French translations completed.

These edits sit inside upstream files, so they are not copied here; a clean way to publish them would be
patches against a fixed upstream commit.
