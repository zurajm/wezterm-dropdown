#!/usr/bin/env bash
# wezterm-toggle.sh — Drop-down terminal toggle with multi-monitor support
# Dependencies: kdotool, kscreen-doctor, python3, wezterm, qdbus6
#
# Virtual desktop behaviour: uses the KWin scripting API (via qdbus6) to set
# client.onAllDesktops=true. kdotool windowstate --add STICKY is X11-only and
# is silently ignored for native Wayland clients like WezTerm.

set -uo pipefail

# ── Configuration ─────────────────────────────────────────────────────────── #
readonly CLASS="wezterm-dropdown"
readonly CONFIG="$HOME/.config/wezterm/dropdown.lua"
readonly POLL_INTERVAL=0.05
readonly POLL_MAX=160
# Dropdown height as a fraction of monitor height (3 = 1/3 of screen).
# Tweak this if you want a taller/shorter dropdown.
readonly HEIGHT_FRACTION=3

# ── Helpers ───────────────────────────────────────────────────────────────── #

# ensure_sticky
# Sets onAllDesktops=true via KWin scripting (qdbus6), so the window exists
# on every virtual desktop and activating it never triggers a desktop switch.
#
# KDE6 API notes (verified via journalctl):
#   - workspace.clientList() → REMOVED in KDE6 (was X11-era API)
#   - workspace.windows      → undefined in KDE6
#   - workspace.windowList() → correct KDE6 replacement (it's a function)
#   - Execution: loadScript() + /Scripting start() — NOT Script{N}.run()
#     (the Script{N} DBus object may not exist yet when run() is called)
ensure_sticky() {
    local tmpscript plugin_name
    tmpscript=$(mktemp --suffix=.js)
    plugin_name="wt-sticky-$$"
    cat > "$tmpscript" << 'KWSCRIPT'
var w = workspace.windowList();
for (var i = 0; i < w.length; i++) {
    if (w[i].resourceClass === "wezterm-dropdown") {
        w[i].onAllDesktops = true;
    }
}
KWSCRIPT
    qdbus6 org.kde.KWin /Scripting unloadScript "$plugin_name" 2>/dev/null || true
    qdbus6 org.kde.KWin /Scripting loadScript "$tmpscript" "$plugin_name" 2>/dev/null
    qdbus6 org.kde.KWin /Scripting start 2>/dev/null || true
    sleep 0.1
    qdbus6 org.kde.KWin /Scripting unloadScript "$plugin_name" 2>/dev/null || true
    rm -f "$tmpscript"
}

# screen_for_point <mx> <my>
# Prints "X Y W H" of the monitor containing the given point.
# kscreen-doctor embeds ANSI colour codes — Python strips them before parsing.
screen_for_point() {
    python3 - "$1" "$2" << 'PYEOF'
import subprocess, re, sys
mx, my = int(sys.argv[1]), int(sys.argv[2])
raw  = subprocess.run(['kscreen-doctor', '-o'], capture_output=True, text=True).stdout
text = re.compile(r'\x1B(?:[@-Z\\-_]|\[[0-?]*[ -/]*[@-~])').sub('', raw)
for line in text.splitlines():
    m = re.search(r'Geometry:\s+(\d+),(\d+)\s+(\d+)x(\d+)', line)
    if m:
        x, y, w, h = map(int, m.groups())
        if x <= mx < x + w and y <= my < y + h:
            print(x, y, w, h)
            break
PYEOF
}

# mouse_screen — prints "X Y W H" of the monitor where the mouse cursor is.
mouse_screen() {
    local loc mx my
    loc=$(kdotool getmouselocation 2>/dev/null)
    mx=$(grep -oP 'x:\K[0-9]+' <<< "$loc")
    my=$(grep -oP 'y:\K[0-9]+' <<< "$loc")
    screen_for_point "$mx" "$my"
}

# panel_offset_for_point <mx> <my>
# Prints the height (in pixels) of any Plasma top panel that covers (mx, my).
# Returns 0 if no panel covers that point. Used to offset the dropdown below
# the status bar instead of hiding behind it.
#
# Implementation: enumerate plasmashell windows via kdotool, filter to ones
# whose geometry covers (mx, my) with a small height (real panels, not full-
# screen containments), and return the largest matching panel height.
panel_offset_for_point() {
    local mx=$1 my=$2
    local max_h=0
    local wid geom gx gy gw gh

    while IFS= read -r wid; do
        [[ -z "$wid" ]] && continue
        geom=$(kdotool getwindowgeometry "$wid" 2>/dev/null) || continue
        # Parse "  Position: X,Y\n  Geometry: WxH".
        # Awk skips leading whitespace, so the field index differs by line:
        #   Position  -> $1="Position:" $2="X,Y"   (split further on comma)
        #   Geometry  -> $1="Geometry:" $2="WxH"   (split further on x)
        local x y w h
        x=$(awk '/Position/{split($2,a,","); print a[1]; exit}' <<< "$geom")
        y=$(awk '/Position/{split($2,a,","); print a[2]; exit}' <<< "$geom")
        w=$(awk '/Geometry/{split($2,a,"x"); print a[1]; exit}' <<< "$geom")
        h=$(awk '/Geometry/{split($2,a,"x"); print a[2]; exit}' <<< "$geom")
        # Only consider panels at the top edge (y == 0) with sensible height.
        # Skip full-screen containments (no panel) and anything that's clearly
        # not a top-edge panel (y > 50 or no height).
        [[ -z "$h" || "$y" != "0" || "$h" -ge 200 ]] && continue
        # Does this top-edge panel cover the mouse horizontally?
        if (( x <= mx && mx < x + w )); then
            (( h > max_h )) && max_h=$h
        fi
    done < <(kdotool search "plasmashell" 2>/dev/null)

    echo "$max_h"
}

# animate <wid> <x> <y> <w> <h> <in|out>
# Slides the window in (from above) or out (upward), then minimises on 'out'.
# Uses cubic easing: ease-out for 'in' (fast start, soft landing),
# ease-in for 'out' (slow start, fast exit) — feels natural, not mechanical.
animate() {
    python3 - "$@" << 'PYEOF'
import subprocess, time, sys
wid           = sys.argv[1]
x, y, w, h    = int(sys.argv[2]), int(sys.argv[3]), int(sys.argv[4]), int(sys.argv[5])
direction     = sys.argv[6]
STEPS, DURATION = 28, 0.22

def move(cy):
    subprocess.run(['kdotool', 'windowmove', wid, str(x), str(cy)], capture_output=True)

for i in range(STEPS + 1):
    t = i / STEPS
    if direction == 'in':
        ease = 1 - (1 - t) ** 3        # ease-out cubic
        cy = y - h + int(h * ease)
    else:
        ease = t ** 3                   # ease-in cubic
        cy = y - int(h * ease)
    move(cy)
    time.sleep(DURATION / STEPS)

if direction == 'in':
    move(y)
else:
    subprocess.run(['kdotool', 'windowminimize', wid], capture_output=True)
PYEOF
}

# ── Main ──────────────────────────────────────────────────────────────────── #
WINDOW_ID=$(kdotool search --class "$CLASS" 2>/dev/null | head -n 1)

# Case 1: Not running — launch, move off-screen immediately, slide in
if [[ -z "$WINDOW_ID" ]]; then
    read -r TX TY TW TH < <(mouse_screen)
    wezterm --config-file "$CONFIG" start \
        --always-new-process --class "$CLASS" --workspace "dropdown" &

    # Poll every 50ms (up to 8s) — catch the window the moment it appears
    # so we can move it off-screen before the user ever sees it.
    NEW_ID=""
    for (( i=0; i<POLL_MAX; i++ )); do
        NEW_ID=$(kdotool search --class "$CLASS" 2>/dev/null | head -n 1)
        [[ -n "$NEW_ID" ]] && break
        sleep "$POLL_INTERVAL"
    done

    if [[ -n "$NEW_ID" && -n "$TX" ]]; then
        kdotool windowstate --add NO_BORDER "$NEW_ID"
        ensure_sticky  # pin to all virtual desktops via KWin scripting

        # Re-query mouse so we know which monitor we're on for panel offset.
        loc=$(kdotool getmouselocation 2>/dev/null)
        mx=$(grep -oP 'x:\K[0-9]+' <<< "$loc")
        my=$(grep -oP 'y:\K[0-9]+' <<< "$loc")
        PANEL_OFF=$(panel_offset_for_point "$mx" "$my")
        PANEL_OFF=${PANEL_OFF:-0}

        DROP_H=$((TH / HEIGHT_FRACTION))
        TARGET_Y=$((TY + PANEL_OFF))
        START_Y=$((TARGET_Y - DROP_H))

        kdotool windowmove   "$NEW_ID" "$TX" "$START_Y"
        kdotool windowsize   "$NEW_ID" "$TW" "$DROP_H"
        sleep 0.05
        animate "$NEW_ID" "$TX" "$TARGET_Y" "$TW" "$DROP_H" in
    fi
    exit 0
fi

# Case 2: Active and focused — slide it up and hide
if [[ "$WINDOW_ID" == "$(kdotool getactivewindow 2>/dev/null)" ]]; then
    read -r CX CY CW CH < <(
        kdotool getwindowgeometry "$WINDOW_ID" 2>/dev/null \
        | awk '/Position/{split($2,p,","); x=p[1]; y=p[2]}
               /Geometry/{split($2,g,"x"); w=g[1]; h=g[2]}
               END{print x, y, w, h}'
    )
    animate "$WINDOW_ID" "$CX" "$CY" "$CW" "$CH" out
    exit 0
fi

# Case 3: Exists but hidden — teleport to current monitor and slide in
read -r TX TY TW TH < <(mouse_screen)
if [[ -n "$TX" ]]; then
    # Re-ensure onAllDesktops (may have been lost after KWin restart)
    ensure_sticky

    # Re-query mouse for panel offset on this monitor.
    loc=$(kdotool getmouselocation 2>/dev/null)
    mx=$(grep -oP 'x:\K[0-9]+' <<< "$loc")
    my=$(grep -oP 'y:\K[0-9]+' <<< "$loc")
    PANEL_OFF=$(panel_offset_for_point "$mx" "$my")
    PANEL_OFF=${PANEL_OFF:-0}

    DROP_H=$((TH / HEIGHT_FRACTION))
    TARGET_Y=$((TY + PANEL_OFF))
    START_Y=$((TARGET_Y - DROP_H))

    # Set geometry before minimising so KDE records the new position
    kdotool windowmove     "$WINDOW_ID" "$TX" "$START_Y"
    kdotool windowsize     "$WINDOW_ID" "$TW" "$DROP_H"
    kdotool windowminimize "$WINDOW_ID" 2>/dev/null
    sleep 0.15
    kdotool windowactivate "$WINDOW_ID" 2>/dev/null
    sleep 0.05
    animate "$WINDOW_ID" "$TX" "$TARGET_Y" "$TW" "$DROP_H" in
else
    kdotool windowactivate "$WINDOW_ID"
fi
