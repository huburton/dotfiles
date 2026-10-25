# dotfiles: my Arch Linux + Hyprland desktop

The configuration of my daily desktop: Arch Linux, Hyprland configured in **Lua**, a
[Quickshell](https://quickshell.org) shell based on end-4's
[illogical-impulse](https://github.com/end-4/dots-hyprland) (ii), three monitors and an NVIDIA GPU,
in a Secure Boot dual-boot with Windows.

This is a snapshot of a working machine, not an installer. Paths, monitor names and keyboard codes
match my hardware; adapt them before reusing anything.

## What is in it

| Part | What it does |
|---|---|
| `hypr/hyprland.lua`, `config.lua`, `binds.lua` | Whole Hyprland config in Lua (hyprland-git ignores `.conf` files): settings, window rules, 160+ binds. Every bind carries a `description = "Section\|Text"` that the shell reads live to build the cheatsheet. |
| `hypr/workspaces.lua` | Per-monitor workspaces, "macOS Spaces" style: monitor 1 owns 1–10, monitor 2 owns 11–20, monitor 3 owns 21–30. Small Lua API (`hypr_ws.go`, `rel`, `move`, `focus_id`) used by the binds and the shell. |
| `hypr/tests/workspaces-test.py` | Regression test with real input (ydotool + `hyprctl`): 155 checks across the three monitors. |
| `hypr/monitors-<hostname>.lua` | Layout per machine (`~/.config` is shared over NFS with my laptop). Written by `bin/hypr-monitors-save` while `wdisplays` is open, since wdisplays applies a layout but saves nothing. |
| `hypr/shaders/qdoled-fringe.frag` + `bin/oled-fringe` | Fix for colour fringes on a QD-OLED panel, whose subpixels are triangles. The shader resamples each channel at its real subpixel position, in linear light, on that monitor only, and steps aside for fullscreen games. |
| `bin/wallpaper-video` | Video wallpaper: one `mpvpaper` for all outputs, with guards (VRAM free, CPU use, memory, crash loops) and a static fallback. |
| `bin/oled-screensaver`, `hypr/hypridle.conf` | Two-minute idle screensaver for the OLED, nothing else (no auto-suspend). |
| `bin/session-daemons`, `bin/hyprland-conf-session` | Session start and supervision: the shell, idle daemon, scratchpads and clipboard history restart by themselves; if the shell dies while the screen is locked, it locks again on restart. |
| `bin/ai-mode`, `bin/pc-status` | Switch the GPU between the desktop (video wallpaper) and a local LLM server, and expose that state to my home server. |
| `system/sbin/maj-auto` + units | Automatic updates: packages download and install in the background (never while a game runs); kernel, NVIDIA, Hyprland and Qt install at shutdown, then the script checks the DKMS module, the unified kernel image and its signature. |
| `quickshell-ii/` | Only the files I added to ii (Alt+Tab with live thumbnails, settings pages, push-to-talk dictation, voice-assistant panel…). See [`quickshell-ii/README.md`](quickshell-ii/README.md). |
| `docs/secure-boot.md` | How the dual boot works with Secure Boot on: shim → GRUB → unified kernel image. |

## Layout

```
hypr/            Hyprland (Lua), shader, tests
bin/             session and desktop scripts (~/.local/bin)
systemd/user/    user units for the services above
system/          root-owned parts (updates), installed by hand
quickshell-ii/   my additions to end-4's illogical-impulse shell
docs/            notes (Secure Boot chain)
```

## Notes

- Keyboard is French AZERTY: workspace binds use keycodes (`code:10`–`code:19`), not keysyms.
- Comments are partly in French, the language I work in.
- Things I learned the hard way on hyprland-git are written next to the code that works around them
  (dead Lua options that fail silently, `hyprctl dispatch` taking Lua, monitor JSON quirks).

## Screenshots

TODO

## License

GPL-3.0, like illogical-impulse, since `quickshell-ii/` builds on it. See [LICENSE](LICENSE).
