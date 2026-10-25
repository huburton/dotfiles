-- ============================================================================
-- hyprland-git runtime config injection
-- hyprland-git parses only the top-level hyprland.lua and IGNORES `source=`
-- directives, so we translate ~/.config/hypr/{hyprland,custom}/*.conf into a
-- single hl.config() + hl.window_rule() + hl.layer_rule() batch here.
-- ============================================================================

pcall(function() hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 5,
    gaps_workspaces = 50,
    border_size = 1,
    ["col.active_border"] = "rgba(6c708680)",
    ["col.inactive_border"] = "rgba(31313600)",
    resize_on_border = true,
    no_focus_fallback = true,
    allow_tearing = true,
    snap = {
      enabled = true,
      window_gap = 4,
      monitor_gap = 5,
      respect_gaps = true,
    },
  },
  input = {
    kb_layout = "fr",
    kb_variant = "",
    follow_mouse = 1,
    sensitivity = 0.0,
    accel_profile = "flat",
    numlock_by_default = true,
    repeat_delay = 250,
    repeat_rate = 35,
    off_window_axis_events = 2,
    touchpad = {
      natural_scroll = true,
      tap_to_click = true,
      disable_while_typing = true,
      clickfinger_behavior = true,
      scroll_factor = 0.7,
    },
  },
  decoration = {
    rounding = 18,
    rounding_power = 2,
    -- Real transparency for inactive windows (visible via terminal windowrule)
    active_opacity = 1.0,
    inactive_opacity = 0.98,
    fullscreen_opacity = 1.0,
    dim_inactive = true,
    dim_strength = 0.08,
    dim_special = 0.3,
    blur = {
      enabled = true,
      size = 16,
      passes = 4,
      new_optimizations = true,
      ignore_opacity = true,
      xray = false,
      noise = 0.03,
      contrast = 1.15,
      brightness = 0.88,
      vibrancy = 0.2,
      vibrancy_darkness = 0.35,
      popups = false,
      popups_ignorealpha = 0.6,
      input_methods = true,
      input_methods_ignorealpha = 0.8,
    },
    shadow = {
      enabled = true,
      range = 20,
      offset = "0 2",
      render_power = 4,
      color = "rgba(00000020)",
    },
  },
  animations = { enabled = true },
  dwindle = { preserve_split = true, smart_split = false, smart_resizing = false },
  misc = {
    disable_hyprland_logo = true,
    disable_splash_rendering = true,
    vrr = 2,
    mouse_move_enables_dpms = true,
    key_press_enables_dpms = true,
    animate_manual_resizes = false,
    animate_mouse_windowdragging = false,
    enable_swallow = false,
    swallow_regex = "(foot|kitty|allacritty|Alacritty)",
    on_focus_under_fullscreen = 2,
    allow_session_lock_restore = true,
    session_lock_xray = true,
    initial_workspace_tracking = false,
    focus_on_activate = true,
  },
  binds = { scroll_event_delay = 0, hide_special_on_workspace_change = true },
  cursor = { zoom_factor = 1, zoom_rigid = false, zoom_disable_aa = true, hotspot_padding = 1 },
  xwayland = { force_zero_scaling = true },
  gestures = {
    workspace_swipe_distance = 250,
    workspace_swipe_invert = true,
    workspace_swipe_min_speed_to_force = 30,
    workspace_swipe_cancel_ratio = 0.15,
    workspace_swipe_create_new = true,
    workspace_swipe_direction_lock = true,
    workspace_swipe_direction_lock_threshold = 10,
    workspace_swipe_forever = true,
    workspace_swipe_use_r = true,
  },
}) end)

-- ============================================================================
-- Bezier curves + animations
-- ============================================================================
local function bez(name, x1, y1, x2, y2)
  pcall(hl.curve, name, { type = "bezier", points = { { x1, y1 }, { x2, y2 } } })
end
bez("expressiveFastSpatial",    0.42, 1.67, 0.21, 0.90)
bez("expressiveSlowSpatial",    0.39, 1.29, 0.35, 0.98)
bez("expressiveDefaultSpatial", 0.38, 1.21, 0.22, 1.00)
bez("emphasizedDecel",          0.05, 0.70, 0.10, 1.00)
bez("emphasizedAccel",          0.30, 0.00, 0.80, 0.15)
bez("standardDecel",            0.00, 0.00, 0.00, 1.00)
bez("menu_decel",               0.10, 1.00, 0.00, 1.00)
bez("menu_accel",               0.52, 0.03, 0.72, 0.08)
bez("stall",                    1.00,-0.10, 0.70, 0.85)

pcall(hl.animation, { leaf = "windowsIn",           enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "popin 80%" })
pcall(hl.animation, { leaf = "fadeIn",              enabled = true, speed = 3,   bezier = "emphasizedDecel" })
pcall(hl.animation, { leaf = "windowsOut",          enabled = true, speed = 2,   bezier = "emphasizedDecel", style = "popin 90%" })
pcall(hl.animation, { leaf = "fadeOut",             enabled = true, speed = 2,   bezier = "emphasizedDecel" })
pcall(hl.animation, { leaf = "windowsMove",         enabled = true, speed = 3,   bezier = "emphasizedDecel", style = "slide" })
pcall(hl.animation, { leaf = "border",              enabled = true, speed = 10,  bezier = "emphasizedDecel" })
pcall(hl.animation, { leaf = "layersIn",            enabled = true, speed = 2.7, bezier = "emphasizedDecel", style = "popin 93%" })
pcall(hl.animation, { leaf = "layersOut",           enabled = true, speed = 2.4, bezier = "menu_accel",      style = "popin 94%" })
pcall(hl.animation, { leaf = "fadeLayersIn",        enabled = true, speed = 0.5, bezier = "menu_decel" })
pcall(hl.animation, { leaf = "fadeLayersOut",       enabled = true, speed = 2.7, bezier = "stall" })
pcall(hl.animation, { leaf = "workspaces",          enabled = true, speed = 7,   bezier = "menu_decel",      style = "slide" })
pcall(hl.animation, { leaf = "specialWorkspaceIn",  enabled = true, speed = 2.8, bezier = "emphasizedDecel", style = "slidevert" })
pcall(hl.animation, { leaf = "specialWorkspaceOut", enabled = true, speed = 1.2, bezier = "emphasizedAccel", style = "slidevert" })
pcall(hl.animation, { leaf = "zoomFactor",          enabled = true, speed = 3,   bezier = "standardDecel" })

-- ============================================================================
-- Window rules (from hyprland/rules.conf + custom/rules.conf)
-- Everything wrapped in pcall so unknown fields don't abort the file.
-- ============================================================================

-- Disable blur for every window (glass effect only applies to quickshell layers)
pcall(hl.window_rule, { match = { class = ".*" }, no_blur = true })

-- Terminals: real transparency + focus/unfocus differential (this is what you SEE)
pcall(hl.window_rule, { match = { class = "^(kitty|foot|Alacritty)$" }, opacity = "0.97 0.90" })

-- Video/media apps: stay fully opaque + no dim when unfocused
for _, cls in ipairs({
  "zen", "org.mozilla.zen", "zen-browser", "zen-alpha",
  "firefox", "librewolf", "chromium", "google-chrome-stable", "brave", "brave-browser", "microsoft-edge",
  "mpv", "vlc", "com.obsproject.Studio", "obs", "io.mpv.mpv",
  "steam_app_.*", "gamescope", "cs2", "faceit", "steam",
  "spotify", "com.spotify.Client",
  "netflix", "prime", "disney",
  "google-chrome", "chrome",
  "telegram-desktop", "signal-desktop",
  -- opaques à la demande de Hugo (2026-10-19)
  "discord", "Discord", "vesktop", "BambuStudio", "bambu-studio", "fusion360\\.exe",
}) do
  pcall(hl.window_rule, { match = { class = "^(" .. cls .. ")$" }, opacity = "1.0 1.0" })
  pcall(hl.window_rule, { match = { class = "^(" .. cls .. ")$" }, no_dim = true })
end
-- Discord, Bambu Studio, Fusion (Wine) : on ignore aussi la couche alpha de leurs fenêtres
for _, cls in ipairs({ "discord", "Discord", "vesktop", "BambuStudio", "bambu-studio", "fusion360\\.exe" }) do
  pcall(hl.window_rule, { match = { class = "^(" .. cls .. ")$" }, opaque = true })
end
-- Any fullscreen window stays fully opaque + no dim
pcall(hl.window_rule, { match = { fullscreen = true }, opacity = "1.0 1.0" })
pcall(hl.window_rule, { match = { fullscreen = true }, no_dim = true })

-- No shadow on tiled windows
pcall(hl.window_rule, { match = { float = false }, no_shadow = true })

-- Floats
local floats = {
  "pavucontrol", "org.pulseaudio.pavucontrol",
  "nm-connection-editor",
  "nwg-look", "wdisplays", "blueman-manager",
  "blueberry.py", "guifetch",
  "Zotero",
  "dev.warp.Warp",
}
for _, cls in ipairs(floats) do
  pcall(hl.window_rule, { match = { class = "^(" .. cls .. ")$" }, float = true })
end

-- Center + size for known floats
for _, cls in ipairs({ "pavucontrol", "org.pulseaudio.pavucontrol", "nm-connection-editor", "Zotero" }) do
  pcall(hl.window_rule, { match = { class = "^(" .. cls .. ")$" }, center = true })
  pcall(hl.window_rule, { match = { class = "^(" .. cls .. ")$" }, size = "45% 45%" })
end

-- wdisplays (Super+Ctrl+D): centred and big enough for the layout preview
pcall(hl.window_rule, { match = { class = "^(wdisplays)$" }, center = true })
pcall(hl.window_rule, { match = { class = "^(wdisplays)$" }, size = "1000 650" })

-- Mission Center (task manager: bar resources widget, Ctrl+Shift+Esc): floating, centred
pcall(hl.window_rule, { match = { class = "^(io.missioncenter.MissionCenter)$" }, float = true })
pcall(hl.window_rule, { match = { class = "^(io.missioncenter.MissionCenter)$" }, center = true })
pcall(hl.window_rule, { match = { class = "^(io.missioncenter.MissionCenter)$" }, size = "1180 760" })

-- KDE portals + illogical-impulse windows
pcall(hl.window_rule, { match = { class = ".*plasmawindowed.*" }, float = true })
pcall(hl.window_rule, { match = { class = "kcm_.*" }, float = true })
pcall(hl.window_rule, { match = { class = ".*bluedevilwizard" }, float = true })
pcall(hl.window_rule, { match = { title = ".*Welcome" }, float = true })
pcall(hl.window_rule, { match = { title = "^(illogical-impulse Settings)$" }, float = true })
pcall(hl.window_rule, { match = { title = ".*Shell conflicts.*" }, float = true })

-- Common file dialogs float+center
for _, ttl in ipairs({ "Open File", "Select a File", "Choose wallpaper", "Open Folder", "Save As", "Library", "File Upload" }) do
  pcall(hl.window_rule, { match = { title = "^(" .. ttl .. ")(.*)$" }, float = true })
  pcall(hl.window_rule, { match = { title = "^(" .. ttl .. ")(.*)$" }, center = true })
end

-- Picture-in-Picture
pcall(hl.window_rule, { match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, float = true })
pcall(hl.window_rule, { match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, pin = true })
pcall(hl.window_rule, { match = { title = "^([Pp]icture[-\\s]?[Ii]n[-\\s]?[Pp]icture)(.*)$" }, keep_aspect_ratio = true })

-- Tearing (games)
pcall(hl.window_rule, { match = { class = "^(steam_app).*" }, immediate = true })
pcall(hl.window_rule, { match = { class = "^(gamescope)$" }, immediate = true })
pcall(hl.window_rule, { match = { title = ".*minecraft.*" }, immediate = true })

-- Media apps to specific workspaces (visible mouse-focus friendly)
pcall(hl.window_rule, { match = { class = "^(Spotify|spotify)$" }, workspace = "4 silent" })
pcall(hl.window_rule, { match = { class = "^(discord|Discord)$" }, workspace = "5 silent" })

-- ============================================================================
-- Layer rules — THE actual fix for the transparent bar. quickshell layers get
-- blur + ignore_alpha so backgrounds render opaque/glassmorphism.
-- ============================================================================

-- All quickshell layers: blur + blur_popups + ignore_alpha 0.79
pcall(hl.layer_rule, { match = { namespace = "^quickshell:.*" }, blur = true })
pcall(hl.layer_rule, { match = { namespace = "^quickshell:.*" }, blur_popups = true })
pcall(hl.layer_rule, { match = { namespace = "^quickshell:.*" }, ignore_alpha = 0.79 })

-- Bar: force opaque (ignore_alpha 0) so the bar is fully readable
pcall(hl.layer_rule, { match = { namespace = "quickshell:bar" }, ignore_alpha = 0 })

-- OSD / notifications / session / sidebars: slightly more transparent for depth
pcall(hl.layer_rule, { match = { namespace = "quickshell:onScreenDisplay" }, ignore_alpha = 0 })
pcall(hl.layer_rule, { match = { namespace = "quickshell:notifications" }, ignore_alpha = 0.4 })
pcall(hl.layer_rule, { match = { namespace = "^quickshell:sidebar.*" }, ignore_alpha = 0.2 })
pcall(hl.layer_rule, { match = { namespace = "quickshell:session" }, ignore_alpha = 0 })

-- Layer animations (mac-like: slide from edges)
pcall(hl.layer_rule, { match = { namespace = "quickshell:sidebarRight" }, animation = "slide right" })
pcall(hl.layer_rule, { match = { namespace = "quickshell:sidebarLeft" }, animation = "slide left" })
pcall(hl.layer_rule, { match = { namespace = "quickshell:bar" }, animation = "slide" })
-- Cheatsheet: no animation, it must appear instantly
pcall(hl.layer_rule, { match = { namespace = "quickshell:cheatsheet" }, no_anim = true })
pcall(hl.layer_rule, { match = { namespace = "quickshell:dock" }, animation = "slide bottom" })
pcall(hl.layer_rule, { match = { namespace = "quickshell:osk" }, animation = "slide bottom" })
pcall(hl.layer_rule, { match = { namespace = "quickshell:wallpaperSelector" }, animation = "slide top" })
pcall(hl.layer_rule, { match = { namespace = "quickshell:notificationPopup" }, animation = "fade" })
pcall(hl.layer_rule, { match = { namespace = "quickshell:screenCorners" }, animation = "popin 120%" })

-- No animation for overlays that appear instantly
for _, ns in ipairs({ "quickshell:overlay", "quickshell:overview", "quickshell:actionCenter",
                     "quickshell:polkit", "quickshell:regionSelector", "quickshell:screenshot",
                     "quickshell:reloadPopup", "quickshell:lockWindowPusher" }) do
  pcall(hl.layer_rule, { match = { namespace = ns }, no_anim = true })
end

-- Tooltip / popup: no transparent artifacts
pcall(hl.layer_rule, { match = { namespace = "quickshell:popup" }, xray = false })
pcall(hl.layer_rule, { match = { namespace = "quickshell:popup" }, ignore_alpha = 1 })
pcall(hl.layer_rule, { match = { namespace = "quickshell:mediaControls" }, ignore_alpha = 1 })
pcall(hl.layer_rule, { match = { namespace = "quickshell:overlay" }, ignore_alpha = 1 })

-- All layers: xray for correct blur under
pcall(hl.layer_rule, { match = { namespace = ".*" }, xray = true })

-- Fast layers: skip animations for launchers etc
for _, ns in ipairs({ "walker", "selection", "overview", "anyrun", "osk", "hyprpicker",
                     "indicator.*", "gtk4-layer-shell", "noanim" }) do
  pcall(hl.layer_rule, { match = { namespace = ns }, no_anim = true })
end

-- ============================================================================
-- Workspace rule: scratchpad has extra gaps
-- ============================================================================
pcall(hl.workspace_rule, { workspace = "special:special", gaps_out = 30 })

-- ============================================================================
-- Multi-monitor mac-style workspaces (1-10 DP-1, 11-20 DP-2, 21-30 DP-3):
-- rules + logic live in workspaces.lua (loaded by hyprland.lua).
-- ============================================================================

-- ============================================================================
-- Monitor layout: NOT here. Managed by nwg-displays (SUPER+CTRL+D) and loaded
-- from monitors-<hostname>.lua by hyprland.lua.
-- ============================================================================
