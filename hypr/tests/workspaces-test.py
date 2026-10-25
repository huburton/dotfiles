#!/usr/bin/env python3
"""Real-input test matrix for per-monitor workspaces (ydotool + hyprctl).

Run from a terminal, hands off the mouse (~3 min): python3 ~/.config/hypr/tests/workspaces-test.py
Moves the cursor and switches workspaces on all monitors, then restores them.
Bar button coordinates in MON are measured for the 2026-09 layout (bar_x0 = first button).
"""
import json, subprocess, time, sys

MON = {  # name: (base, center_x, center_y, bar_x0, bar_y)  logical coords
    "DP-1": (0, 767 + 1376, 347 + 576, 767 + 1260, 347 + 20),
    "DP-2": (10, 2279 + 960, 1499 + 540, 2279 + 843, 1499 + 20),
    "DP-3": (20, 358 + 960, 1499 + 540, 358 + 843, 1499 + 20),
}
ROW = [2, 3, 4, 5, 6, 7, 8, 9, 10, 11]          # evdev KEY_1..KEY_0
PAD = [79, 80, 81, 75, 76, 77, 71, 72, 73, 82]  # evdev KP1..KP9, KP0
META, SHIFT, ALT, CTRL = 125, 42, 56, 29
RIGHT, LEFT, UP, DOWN, PGDN, PGUP, TAB = 106, 105, 103, 108, 109, 104, 15
results = []

def sh(*a):
    return subprocess.run(a, capture_output=True, text=True).stdout

def hj(*a):
    return json.loads(sh("hyprctl", *a, "-j"))

def dispatch(lua):
    sh("hyprctl", "dispatch", lua)

def state():
    mons = hj("monitors")
    cur = hj("cursorpos")
    under = None
    for m in mons:
        w, h = m["width"] / m["scale"], m["height"] / m["scale"]
        if m["x"] <= cur["x"] < m["x"] + w and m["y"] <= cur["y"] < m["y"] + h:
            under = m["name"]
    return {
        "ws": {m["name"]: m["activeWorkspace"]["name"] for m in mons},
        "focused": next(m["name"] for m in mons if m["focused"]),
        "under": under,
    }

def key(*codes):
    args = [f"{c}:1" for c in codes] + [f"{c}:0" for c in reversed(codes)]
    sh("ydotool", "key", *args)
    time.sleep(0.18)

def click():
    sh("ydotool", "click", "0xC0")
    time.sleep(0.25)

def cursor(x, y):
    dispatch(f"hl.dsp.cursor.move({{ x = {x}, y = {y} }})")
    time.sleep(0.05)

def focus_mon(name):
    dispatch(f'hl.dsp.focus({{ monitor = "{name}" }})')
    time.sleep(0.1)

def go(id_):
    dispatch(f"function() hypr_ws.focus_id({id_}) end")
    time.sleep(0.12)

def check(label, cond, detail=""):
    results.append((label, cond, detail))
    if not cond:
        print(f"ÉCHEC {label} {detail}", flush=True)

def expect_ws(label, mon, want, before, extra=None):
    st = state()
    ok = st["ws"][mon] == str(want)
    others_ok = all(st["ws"][m] == before["ws"][m] for m in MON if m != mon)
    ok = ok and others_ok and (extra(st) if extra else True)
    check(label, ok, json.dumps(st))
    return st

def clients(cls):
    return [c for c in hj("clients") if c["class"] == cls]

initial = state()
init_cursor = hj("cursorpos")
init_win = hj("activewindow").get("address")
test_wins = []
try:
    # ---------- T1: Super+N, mouse == focus, top row + numpad ----------
    for mon, (base, cx, cy, *_ ) in MON.items():
        focus_mon(mon)
        for kbname, keys in (("rangée", ROW), ("pavé", PAD)):
            for n in (1, 2, 3, 4, 5, 6, 7, 8, 9, 10):
                before = state()
                key(META, keys[n - 1])
                expect_ws(f"T1 {mon} Super+{n} ({kbname})", mon, base + n, before,
                          lambda st, mon=mon: st["focused"] == mon)
        go(base + 1)

    # ---------- T2: mouse on A, keyboard focus on B ----------
    for a in MON:
        for b in MON:
            if a == b:
                continue
            dispatch("function() hl.config({ cursor = { no_warps = true } }) end")
            cursor(MON[a][1], MON[a][2])
            focus_mon(b)
            dispatch("function() hl.config({ cursor = { no_warps = false } }) end")
            st = state()
            check(f"T2 prépa souris {a} / focus {b}", st["focused"] == b and st["under"] == a, json.dumps(st))
            for kbname, keys in (("rangée", ROW), ("pavé", PAD)):
                before = state()
                key(META, keys[2])
                expect_ws(f"T2 souris {a} focus {b} Super+3 ({kbname})", a, MON[a][0] + 3, before)
                go(MON[a][0] + 1)

    # ---------- T3: bar clicks on each monitor (focus elsewhere) ----------
    names = list(MON)
    for idx, mon in enumerate(names):
        base, _, _, bx, by = MON[mon]
        focus_mon(names[(idx + 1) % 3])  # keyboard focus on another monitor
        for i in (0, 1, 2, 3, 5, 6, 7, 8, 9, 4):  # DP-1's 5 is fullscreen (hides the bar): last
            before = state()
            cursor(bx + 26 * i, by)
            click()
            expect_ws(f"T3 clic barre {mon} bouton {i + 1}", mon, base + i + 1, before)
        go(base + 1)

    # ---------- T4: moving windows (Super+Shift = follow, Super+Alt = silent) ----------
    for mon in MON:
        base = MON[mon][0]
        go(base + 9)
        focus_mon(mon)
        n_before = len(clients("wstest"))
        subprocess.Popen(["kitty", "--class", "wstest", "-o", "confirm_os_window_close=0", "sleep", "900"],
                         stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        for _ in range(50):
            time.sleep(0.1)
            if len(clients("wstest")) > n_before:
                break
        time.sleep(0.4)
        addr = [c for c in clients("wstest") if c["address"] not in test_wins][0]["address"]
        test_wins.append(addr)

        def win_ws():
            c = next(c for c in hj("clients") if c["address"] == addr)
            return c["workspace"]["name"], c["monitor"]

        for kbname, keys in (("rangée", ROW), ("pavé", PAD)):
            dispatch(f'hl.dsp.focus({{ window = "address:{addr}" }})'); time.sleep(0.15)
            before = state()
            key(META, SHIFT, keys[3])  # follow to 4
            ws, _ = win_ws()
            expect_ws(f"T4 {mon} Super+Shift+4 ({kbname}) suit", mon, base + 4, before,
                      lambda st: ws == str(base + 4))
            before = state()
            key(META, ALT, keys[6])  # silent to 7
            ws, _ = win_ws()
            expect_ws(f"T4 {mon} Super+Alt+7 ({kbname}) discret", mon, base + 4, before,
                      lambda st: ws == str(base + 7))
            dispatch(f'hl.dsp.focus({{ window = "address:{addr}" }})'); time.sleep(0.15)
        # window focused, mouse on another monitor: move stays on the window's monitor
        other = next(m for m in MON if m != mon)
        dispatch(f'hl.dsp.focus({{ window = "address:{addr}" }})'); time.sleep(0.15)
        cursor(MON[other][1], MON[other][2])
        before = state()
        key(META, ALT, ROW[1])
        ws, m_id = win_ws()
        check(f"T4 {mon} Super+Alt+2 souris sur {other}", ws == str(base + 2), f"ws={ws}")
        # relative window move
        dispatch(f'hl.dsp.focus({{ window = "address:{addr}" }})'); time.sleep(0.15)
        before = state()
        key(CTRL, META, SHIFT, RIGHT)
        ws, _ = win_ws()
        check(f"T4 {mon} Ctrl+Super+Shift+→ (2→3)", ws == str(base + 3), f"ws={ws}")
        # Super+Alt+S: send to scratchpad without showing it
        dispatch(f'hl.dsp.focus({{ window = "address:{addr}" }})'); time.sleep(0.15)
        key(META, ALT, 31)  # KEY_S
        c = next(c for c in hj("clients") if c["address"] == addr)
        m = next(m for m in hj("monitors") if m["name"] == mon)
        check(f"T4 {mon} Super+Alt+S scratchpad discret", c["workspace"]["name"].startswith("special") and not m["specialWorkspace"]["name"], json.dumps({"win": c["workspace"]["name"], "special_shown": m["specialWorkspace"]["name"]}))
        go(base + 1)

    # ---------- T5: relative focus, bounded to the monitor ----------
    for mon in MON:
        base, cx, cy, *_ = MON[mon]
        focus_mon(mon)
        go(base + 1)
        for label, keys, want in (
            ("Ctrl+Super+← au 1er reste", (CTRL, META, LEFT), base + 1),
            ("Ctrl+Super+→ 1→2", (CTRL, META, RIGHT), base + 2),
            ("Super+PgDn 2→3", (META, PGDN), base + 3),
            ("Super+PgUp 3→2", (META, PGUP), base + 2),
            ("Ctrl+Super+↓ 2→7", (CTRL, META, DOWN), base + 7),
            ("Ctrl+Super+↓ 7→10 (borné)", (CTRL, META, DOWN), base + 10),
            ("Ctrl+Super+→ au 10e reste", (CTRL, META, RIGHT), base + 10),
            ("Ctrl+Super+↑ 10→5", (CTRL, META, UP), base + 5),
        ):
            before = state()
            key(*keys)
            expect_ws(f"T5 {mon} {label}", mon, want, before)
        go(base + 1)

    # ---------- T6: Super+Tab stays on the monitor ----------
    focus_mon("DP-1"); go(2); go(3)
    focus_mon("DP-2"); go(12)
    focus_mon("DP-1")
    time.sleep(1.1)
    before = state()
    key(META, TAB)
    expect_ws("T6 Super+Tab sur DP-1 (3→2, DP-2 intact)", "DP-1", 2, before)

    # ---------- T7: workspace_action.sh shim (Jarvis) ----------
    focus_mon("DP-3")
    before = state()
    sh(f"{__import__('os').path.expanduser('~')}/.config/hypr/hyprland/scripts/workspace_action.sh", "workspace", "6")
    time.sleep(0.15)
    expect_ws("T7 workspace_action.sh workspace 6 (souris DP-3)", "DP-3", 26, before)
finally:
    for addr in test_wins:
        dispatch(f'hl.dsp.window.close({{ window = "address:{addr}" }})')
    time.sleep(0.4)
    for mon, ws in initial["ws"].items():
        go(int(ws))
    if init_win:
        dispatch(f'hl.dsp.focus({{ window = "address:{init_win}" }})')
        time.sleep(0.1)
    cursor(init_cursor["x"], init_cursor["y"])
    final = state()
    print("état restauré:", final["ws"] == initial["ws"], json.dumps(final))

ok = sum(1 for r in results if r[1])
print(f"\n{ok}/{len(results)} tests OK")
by_group = {}
for label, cond, _ in results:
    g = label.split()[0]
    by_group.setdefault(g, [0, 0])
    by_group[g][0] += cond
    by_group[g][1] += 1
for g, (a, b) in by_group.items():
    print(f"  {g}: {a}/{b}")
sys.exit(0 if ok == len(results) else 1)
