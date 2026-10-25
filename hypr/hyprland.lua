-- Root Hyprland lua config
-- Enough to satisfy hyprland-git so it doesn't trip emergency mode.
-- Then loads the full config + binds from separate files.

-- Minimum bind so hyprland-git detects at least one lua bind and doesn't emergency
pcall(hl.bind, "SUPER + Q", hl.dsp.window.close())

-- Load runtime config settings (input, decoration, general, blur, gestures, ...)
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/config.lua")

-- Per-monitor workspace stacks (rules + the hypr_ws API used by binds.lua and the shell)
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/workspaces.lua")

-- Load all binds converted from ~/.config/hypr/hyprland/keybinds.conf + custom/keybinds.conf
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/binds.lua")

-- Shell-side overrides (game mode, anti-flashbang...), written by quickshell's
-- scripts/hyprland/hypr_overrides.py
pcall(dofile, os.getenv("HOME") .. "/.config/hypr/shell-overrides.lua")

-- Monitors: set with wdisplays (Super+Ctrl+D, launched via
-- ~/.local/bin/wdisplays-persist), which saves the live layout with
-- ~/.local/bin/hypr-monitors-save. ~/.config is shared over NFS with the laptop,
-- so each machine has its own file: monitors-<hostname>.lua, falling back to monitors.lua.
do
  local dir = os.getenv("HOME") .. "/.config/hypr/"
  local host = ""
  pcall(function() local f = io.open("/etc/hostname"); host = f:read("*l") or ""; f:close() end)
  if not pcall(dofile, dir .. "monitors-" .. host .. ".lua") then
    pcall(dofile, dir .. "monitors.lua")
  end
end

-- Env vars (Wayland + NVIDIA)
pcall(hl.env, "MOZ_ENABLE_WAYLAND",         "1")
pcall(hl.env, "QT_QPA_PLATFORM",            "wayland")
pcall(hl.env, "XDG_SESSION_TYPE",           "wayland")
pcall(hl.env, "GBM_BACKEND",                "nvidia-drm")
pcall(hl.env, "__GLX_VENDOR_LIBRARY_NAME",  "nvidia")
pcall(hl.env, "LIBVA_DRIVER_NAME",          "nvidia")
