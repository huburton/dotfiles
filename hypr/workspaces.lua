-- ============================================================================
-- Per-monitor workspace stacks ("macOS Spaces")
--   Each monitor owns 10 workspace ids and never shows another monitor's ones:
--     DP-1 (ultrawide, top)        1-10  (default 1)
--     DP-2 (144Hz, bottom right)   11-20 (default 11)
--     DP-3 (AOC OLED, bottom left) 21-30 (default 21)
--   Super+N           -> workspace N of the monitor UNDER THE MOUSE
--   Super+Shift/Alt+N -> move the active window to workspace N of ITS monitor
--   Relative binds (Ctrl+Super+arrows, Super+wheel...) stay inside the range.
--
--   Everything runs here, in Hyprland's Lua state (no hyprctl round-trips).
--   The global `hypr_ws` is also the API for the bar/overview (Quickshell) and
--   hyprland/scripts/workspace_action.sh (Jarvis):
--     hyprctl dispatch 'function() hypr_ws.focus_id(13) end'
-- ============================================================================
local W = {}
W.SIZE = 10
W.BASE = { ["DP-1"] = 0, ["DP-2"] = 10, ["DP-3"] = 20 }

for name, base in pairs(W.BASE) do
  for i = 1, W.SIZE do
    pcall(hl.workspace_rule, { workspace = tostring(base + i), monitor = name, persistent = (i == 1) })
  end
  pcall(hl.workspace_rule, { workspace = tostring(base + 1), monitor = name, ["default"] = true })
end

-- First id - 1 of a monitor's range. Unknown monitors (not in W.BASE) get a
-- free range after the known ones, keyed by their Hyprland id.
function W.base(mon)
  return W.BASE[mon.name] or (30 + W.SIZE * mon.id)
end

-- Monitor that owns workspace `id` (nil if none of the known ranges).
function W.owner(id)
  for name, base in pairs(W.BASE) do
    if id > base and id <= base + W.SIZE then return hl.get_monitor(name) end
  end
end

local function monitor_under_mouse()
  return hl.get_monitor_at_cursor() or hl.get_active_monitor()
end

local function clamp(n)
  return math.max(1, math.min(W.SIZE, n))
end

-- Show workspace `id` on its own monitor. If it somehow lives on another
-- monitor (moved by hand, monitor unplugged...), bring it home first.
function W.focus_id(id)
  local owner = W.owner(id)
  local ws = hl.get_workspace(id)
  if owner and ws and ws.monitor and ws.monitor.name ~= owner.name then
    hl.dispatch(hl.dsp.workspace.move({ workspace = id, monitor = owner.name }))
  end
  if not owner then
    -- Unknown range: create/show it on the monitor under the mouse.
    hl.dispatch(hl.dsp.focus({ monitor = monitor_under_mouse().name }))
  end
  hl.dispatch(hl.dsp.focus({ workspace = id }))
end

-- Workspace n (1..10) of a monitor (default: the one under the mouse).
function W.go(n, mon_name)
  local mon = mon_name and hl.get_monitor(mon_name) or monitor_under_mouse()
  if mon then W.focus_id(W.base(mon) + n) end
end

-- Step through a monitor's range, without wrapping (default: under the mouse).
function W.rel(delta, mon_name)
  local mon = mon_name and hl.get_monitor(mon_name) or monitor_under_mouse()
  local ws = mon and mon.active_workspace
  if not ws or not ws.id then return end
  local base = W.base(mon)
  local target = base + clamp(ws.id - base + delta)
  if target ~= ws.id then W.focus_id(target) end
end

-- Move the active window to workspace n of the window's own monitor.
function W.move(n, silent)
  local win = hl.get_active_window()
  local mon = win and (win.monitor or hl.get_active_monitor())
  if not mon then return end
  hl.dispatch(hl.dsp.window.move({ workspace = W.base(mon) + n, follow = not silent }))
end

function W.move_rel(delta, silent)
  local win = hl.get_active_window()
  local mon = win and (win.monitor or hl.get_active_monitor())
  local ws = win and win.workspace
  if not mon or not ws or not ws.id or ws.special then return end
  local base = W.base(mon)
  local n = clamp(ws.id - base + delta)
  if base + n ~= ws.id then W.move(n, silent) end
end

hypr_ws = W
