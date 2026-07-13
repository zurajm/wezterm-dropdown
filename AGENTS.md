# AGENTS.md — WezTerm Dropdown Fork

Instructions for AI coding agents (and humans) working on this fork.

## What this repo is

A WezTerm-based drop-down terminal for **KDE Plasma 6 (Wayland)**, toggled by
a single keyboard shortcut (F12 by default). Forked from
[kevinSC/Wezterm-Dropdown](https://github.com/kevinSC/Wezterm-Dropdown); the
architecture and design rationale live in upstream's commit history. Upstream
is dormant (no rebases expected). This fork's distinguishing work:

- **Mux-backed launch** — one long-running `wezterm-gui` per dropdown session;
  subsequent F12s `cli spawn --new-window` into it. Avoids the KWin
  placement race that a fresh process per F12 would reintroduce.
- **Per-monitor sizing + Plasma top-panel offset** — dropdown opens at 1/3 of
  the monitor's height, anchored below the status bar (not behind it).
- **Tab bar, random wallpaper (optional), multi-Activity visibility, taskbar
  hiding**, plus stability fixes for the KWin scripting path.

No build step, no tests, no CI. Pure shell + Lua config.

## Repository layout

```
Wezterm-Dropdown/
├── AGENTS.md                       this file
├── README.md                       user-facing setup guide
├── install.sh                      symlink installer (re-runnable, backs up *.bak)
├── uninstall.sh                    symlink remover (legacy-safe)
├── .gitignore                      *.bak, __pycache__, OS junk
├── .github/
│   ├── CONTRIBUTING.md             read this before opening a PR upstream
│   └── PULL_REQUEST_TEMPLATE.md
├── scripts/
│   └── wezterm-toggle.sh           the entire toggle logic (~280 lines, bash + inline python)
└── wezterm/
    ├── dropdown.lua                dropdown-specific config (window decorations, mux domain, tab bar, wallpaper hook)
    ├── dropdown_base.lua           shared defaults (color scheme, font, opacity, harfbuzz)
    └── wezterm.lua                 optional launcher config for the *normal* wezterm-gui (style-matched, not installed)
```

Install creates three symlinks in `~/.config/wezterm/`:

| System path | → | Repo file |
|---|---|---|
| `~/.config/wezterm/dropdown.lua` | → | `wezterm/dropdown.lua` |
| `~/.config/wezterm/dropdown_base.lua` | → | `wezterm/dropdown_base.lua` |
| `~/.config/wezterm/bin/wezterm-toggle.sh` | → | `scripts/wezterm-toggle.sh` |

`install.sh` does **not** touch `~/.config/wezterm/wezterm.lua` or
`~/.wezterm.lua`. `uninstall.sh` only removes symlinks it owns (matching by
resolved target == repo path) and restores any `*.bak` backups. It also
removes two legacy paths: `~/.config/wezterm/wezterm.lua` and
`~/.local/share/kwin/scripts/wezterm-dropdown`.

## Commands

| Task | Command |
|---|---|
| Install | `./install.sh` (creates symlinks in `~/.config/wezterm/`) |
| Uninstall | `./uninstall.sh` (removes owned symlinks, restores `.bak`) |
| Manual toggle | `~/.config/wezterm/bin/wezterm-toggle.sh` |
| Lint (bash) | `shellcheck install.sh uninstall.sh scripts/wezterm-toggle.sh` |
| Lint (lua) | `luac -p wezterm/dropdown.lua wezterm/dropdown_base.lua` (syntax only; no project linter) |
| Verify window props | see *Verification before commit* below |

`install.sh` and `uninstall.sh` use `set -euo pipefail`. `wezterm-toggle.sh`
intentionally uses `set -uo pipefail` **without** `-e`: commands like `kdotool
search` legitimately return empty when the window doesn't exist, and
aborting on those would derail Case 1's pre-window polling.

## External dependencies (host packages, not in this repo)

- `wezterm` (pacman) — terminal + mux server
- `kdotool` (AUR) — Wayland-native window control
- `python3` (pacman) — used by the script for `kscreen-doctor` parsing, geometry parsing, animation
- `qdbus6` (pacman, part of `qt6-tools`) — drives the KWin scripting DBus interface
- `ttf-jetbrains-mono-nerd` (AUR) — required for the `JetBrainsMono NFM` font shorthand
- `kscreen-doctor` (bundled with `plasma-workspace`) — multi-monitor geometry

## Code conventions

From `.github/CONTRIBUTING.md` and house style:

- **Bash scripts**: run `shellcheck` before submitting. POSIX where possible;
  Bash 4+isms are OK if justified. The toggle script uses `set -uo pipefail`
  (no `-e` because some commands are deliberately expected to fail, e.g.
  `qdbus6 unloadScript` when nothing's loaded).
- **KWin scripts**: must target KDE Plasma 6. Never use
  `workspace.clientList()` or `workspace.windows` (removed/undefined).
  Use `workspace.windowList()`.
- **Atomic PRs** — one feature or fix per PR.
- **Conventional Commits** — `feature: …`, `fix: …`, `refactor: …`.
- **Open an issue first** for new features or major refactors.
- **No unsolicited comments** — applies to your code edits in this repo too.

## Required Lua settings (the three things the script depends on)

`dropdown.lua` and `dropdown_base.lua` contain several settings, but **only
three are required** for the script to work — the rest are cosmetic. Do not
remove any of these:

| Setting | Why |
|---|---|
| `config.window_decorations = "RESIZE"` | With `"NONE"`, WezTerm declares itself a native fullscreen surface to KDE Wayland. KWin memorises the original monitor size and forces it on every minimise/restore — dropdown gets stuck at one size and stops responding to multi-monitor changes. |
| `config.unix_domains = { { name = "dropdown" } }` | Without this, `wezterm cli spawn --domain-name dropdown` fails with "invalid domain dropdown" — the mux probe's `cli spawn` path breaks, and we fall back to spawning fresh `wezterm-gui` per F12, reintroducing the placement race. |
| A resolvable `config.font` | Without a valid font, WezTerm spawns a "Configuration Error" modal that occludes the dropdown window. Recommended shorthand: `'JetBrainsMono NFM'` (resolves to *JetBrainsMono Nerd Font Mono*); plain `'JetBrainsMono'` resolves to the non-mono variant and triggers the modal. Use `wezterm.font_with_fallback({...})` with a Nerd Font fallback. |

Everything else (color scheme, opacity, font size, tab bar, custom block
glyphs, harfbuzz features) is preference and can be changed freely.

`dropdown_base.lua` is loaded by both `dropdown.lua` and `wezterm.lua` via
`local base = require 'dropdown_base'; base.apply(config)`. Shared defaults
(Dracula colour scheme, 0.85 opacity, font, harfbuzz features) live in one
place. Change defaults there, not in both configs.

## Exact command-line patterns (the ones that broke during dev)

| Intended behaviour | Wrong (silently fails) | Right |
|---|---|---|
| Spawn window with class `X` in workspace `Y` | `wezterm-gui --class X start --workspace Y` | `wezterm-gui start --class X --workspace Y` (`--class`/`--workspace` belong to `start`, not `wezterm-gui`) |
| Spawn into an existing named mux | `wezterm-gui --domain X` | `wezterm cli spawn --domain-name X --new-window` (domain is a Lua `config.unix_domains` entry, not a CLI flag) |
| Avoid process-per-spawn race | `wezterm cli spawn --always-new-process` | Don't use this flag; see "Why `--always-new-process` is wrong" below |

The mux domain `dropdown` is declared in `dropdown.lua`:
`config.unix_domains = { { name = "dropdown" } }`. WezTerm resolves it to
`/tmp/wezterm-$USER/dropdown` by default — leave `socket_path` unset.

## The toggle script (`scripts/wezterm-toggle.sh`)

A single bash script with inline Python heredocs for the parts bash is bad
at (regex parsing, animation timing). Three top-level cases, dispatched by
the result of `kdotool search --class wezterm-dropdown | head -n1`.

### Case 1 — window doesn't exist

1. `mouse_screen` → resolves mouse cursor via `kdotool getmouselocation`,
   then `kscreen-doctor -o` to find the monitor's `Geometry:` rect. ANSI
   colour codes are stripped by Python before regex matching.
2. **Mux probe** — `pgrep -af "wezterm-gui.*--class wezterm-dropdown"`:
   - **Mux up** (process exists) → `wezterm cli spawn --domain-name dropdown --new-window --workspace dropdown`. The spawned window inherits the parent's class (`wezterm-dropdown`) because that's what the long-running process was started with. `cli spawn` does **not** take its own `--class`.
   - **Mux down** (no process) → `nohup wezterm-gui --config-file "$CONFIG" start --class wezterm-dropdown --workspace dropdown &`. This is the long-running process that the mux probe catches on subsequent F12s.
3. Poll every 50ms (max 8s) for the new window via `kdotool search --class`.
4. Apply `NO_BORDER` via `kdotool windowstate --add`, then `ensure_sticky` (see KWin section).
5. Compute `PANEL_OFF` via `panel_offset_for_point`, set `TARGET_Y = TY + PANEL_OFF`, `DROP_H = TH / 3` (the `HEIGHT_FRACTION=3` constant at the top of the script).
6. Move window off-screen (`START_Y = TARGET_Y - DROP_H`), `kdotool windowsize`, `animate … in`.

### Case 2 — window exists and is the active window

Read current geometry, `animate … out` (cubic ease-in, then `windowminimize`).

### Case 3 — window exists but is hidden or in background

Re-resolve the mouse monitor (user may have moved monitors since the window
was last shown), re-run `ensure_sticky` (KWin restart may have lost the
property), set geometry, `kdotool windowactivate`, `animate … in`.
**No minimise step** — `windowactivate` un-minimises if needed, and bouncing
through minimise→restore produces a visible flash.

### Animation (`animate`)

28 steps over 0.22s, invoked via `kdotool windowmove` per step.
- `in` → ease-out cubic (`1 - (1-t)^3`), slides down from above
- `out` → ease-in cubic (`t^3`), slides up, then `windowminimize`

Tune `STEPS` / `DURATION` in the Python heredoc if you want different feel.

### Why `--always-new-process` is the wrong tool here

WezTerm's CLI supports `--always-new-process` which guarantees a fresh
`wezterm-gui` per spawn. **We explicitly don't use it.** Each fresh
`wezterm-gui` is a brand-new window from KWin's POV; KWin's tiling
extension places it at a "smart" position *before* our script can
`windowmove` it — producing a visible flash on every F12 press. The fix is
to keep one `wezterm-gui` running as the mux server (started on first F12
with `nohup … &`) and `cli spawn --new-window` into it on subsequent
presses. The `pgrep` probe in Case 1 distinguishes the two paths.

The original `--always-new-process` reference in this codebase was removed
in commit `25a32bb` ("feat: reuse mux via cli spawn — no KWin placement
race"). Don't reintroduce it without very strong justification and a
regression test.

## The KWin scripting pattern (`ensure_dropdown_properties`)

Window properties (`onAllDesktops`, `skipTaskbar`, `activities=[]`) are set
via a temporary KWin script loaded over DBus, **not** via `kwinrulesrc`:

```bash
tmpscript=$(mktemp --suffix=.js)
plugin_name="wt-props-$$"
cat > "$tmpscript" << 'KWSCRIPT'
var w = workspace.windowList();
for (var i = 0; i < w.length; i++) {
    if (w[i].resourceClass === "wezterm-dropdown") {
        w[i].onAllDesktops = true;
        w[i].skipTaskbar   = true;
        w[i].activities    = [];
    }
}
workspace.windowAdded.connect(function(win) {
    if (win.resourceClass === "wezterm-dropdown") {
        win.onAllDesktops = true;
        win.skipTaskbar   = true;
        win.activities    = [];
    }
});
KWSCRIPT
qdbus6 org.kde.KWin /Scripting unloadScript "$plugin_name" 2>/dev/null || true
qdbus6 org.kde.KWin /Scripting loadScript   "$tmpscript" "$plugin_name" >/dev/null 2>&1
qdbus6 org.kde.KWin /Scripting start        >/dev/null 2>&1
sleep 0.15
qdbus6 org.kde.KWin /Scripting unloadScript "$plugin_name" >/dev/null 2>&1 || true
rm -f "$tmpscript"
```

Called twice per F12:

1. **Case 1** (window just spawned) — apply properties before the user sees the window.
2. **Case 3** (existing hidden window) — re-apply after a KWin restart, which resets client flags.

The `windowAdded` handler ensures properties apply even to windows spawned
later by `cli spawn` after this script unloads.

### Why scripting, not `kwinrulesrc`?

- Opening System Settings → Window Rules **rewrites** `kwinrulesrc` from
  in-memory state, clobbering hand-edited entries.
- Rules apply only on full KWin restart; the DBus `reloadConfig` signal is
  insufficient for the rules subsystem.
- A script applied at `windowAdded` time fires before the user sees the
  window — no flash, no race.

### KDE 6 API notes (verified against the live DBus interface)

- `workspace.clientList()` is **removed** (was X11-era).
- `workspace.windows` is undefined.
- `workspace.windowList()` is the correct KDE 6 replacement — note the
  parentheses, it's a function call returning an array.
- Use `loadScript` + `/Scripting start` — **not** `Script{N}.run()`. The
  `Script{N}` DBus object may not exist yet when `run()` is called, so the
  call silently no-ops.

The script uses `plugin_name="wt-props-$$"` (PID-suffixed) so two F12
presses in quick succession don't collide on the same plugin name.

## Multi-monitor + Plasma panel offset detection

`mouse_screen` and `screen_for_point` walk `kscreen-doctor -o` output, strip
ANSI codes, regex-match `Geometry:\s+X,Y WxH`, and return the rect containing
the mouse cursor.

`panel_offset_for_point mx my` enumerates `kdotool search "plasmashell"`
windows, parses each window's `getwindowgeometry` output (awk splitting on
comma / `x`), and returns the largest height among top-edge panels
(`y == 0`, `h < 200`) that horizontally cover `mx`. Returns `0` if no panel
covers the mouse point. Simpler than Plasma DBus or a longer-lived KWin
script — `kdotool search` works without any state setup.

`TARGET_Y = monitor_y + panel_offset`. Without the offset the dropdown
slides down *behind* the status bar.

## Non-obvious gotchas (the "learned the hard way" list)

1. **`--always-new-process` causes a KWin placement race.** See the toggle
   script section above.
2. **`--class` is a `wezterm-gui start` flag, not a top-level `wezterm-gui`
   flag.** Putting `--class` before `start` fails silently. See the table above.
3. **`--domain` is not a `wezterm-gui` flag.** Mux domain is declared in
   Lua via `config.unix_domains`; `wezterm-gui` picks it up at startup.
4. **`kwinrulesrc` is fragile.** See "Why scripting, not `kwinrulesrc`?" above.
5. **`workspace.clientList()` is removed in KDE 6.** Use `windowList()`. Also
   use `loadScript + /Scripting start`, never `Script{N}.run()`.
6. **awk field indexing skips leading whitespace.** `kdotool
   getwindowgeometry` outputs `  Position: 1920,0` (leading two spaces) →
   fields are `[empty, "Position:", "1920,0"]` = `$1`, `$2`, `$3`. Existing
   parser handles this via `awk '/Position/{split($2,a,","); print a[1]}'`
   (split `$2` on the delimiter, not `$3`).
7. **Plasma top-panel offset via `kdotool search "plasmashell"`.** Filter
   to `y == 0`, `h < 200`, covering the mouse. Take max height. Don't try
   Plasma DBus or KWin scripting for this — `kdotool search` is simpler.
8. **`pgrep` self-termination when piped from a shell.** `kill $(pgrep -f X)`
   can kill the parent shell if it matches `X`. Enumerate PIDs explicitly
   when needed; don't use `kill $(pgrep …)` anywhere.
9. **`kdotool windowstate --add STICKY` is X11-only.** Silently ignored for
   native Wayland clients like WezTerm. Don't try to use it for "show on
   all desktops" — that's what `onAllDesktops` via KWin scripting is for.
10. **`windowactivate` + minimise is a flash.** Don't minimise then restore
    in Case 3 — `windowactivate` already un-minimises if needed.

## Verification before commit

No automated tests. Run by hand:

```bash
~/.config/wezterm/bin/wezterm-toggle.sh            # F12 equivalent

# Confirm window properties after a fresh launch (one-time race is normal):
cat > /tmp/probe.js <<'EOF'
var w = workspace.windowList();
for (var i = 0; i < w.length; i++) {
    if (w[i].resourceClass === "wezterm-dropdown") {
        print(JSON.stringify({
            activities:    w[i].activities,
            skipTaskbar:   w[i].skipTaskbar,
            onAllDesktops: w[i].onAllDesktops
        }));
    }
}
EOF
qdbus6 org.kde.KWin /Scripting loadScript /tmp/probe.js wt-probe >/dev/null 2>&1
qdbus6 org.kde.KWin /Scripting start >/dev/null 2>&1
sleep 0.5
journalctl -n 3 -t kwin_wayland --no-pager 2>/dev/null | tail -3
qdbus6 org.kde.KWin /Scripting unloadScript wt-probe >/dev/null 2>&1
```

Expected: `{"activities":[], "skipTaskbar":true, "onAllDesktops":true}` for
any window with `resourceClass === "wezterm-dropdown"`.

Multi-monitor test: move the cursor to a second monitor, press F12 twice,
confirm dropdown follows the cursor and the panel offset is per-monitor.

## Repository conventions

- **Symlink-based install** — `git pull` updates everything; no copy step.
  Re-running `install.sh` is safe (it skips already-linked paths).
- **Two Lua configs** — `dropdown.lua` (dropdown-specific: decorations,
  mux domain, tab bar, wallpaper hook) and `dropdown_base.lua` (shared
  defaults: font, colour scheme, opacity, harfbuzz). The main
  `~/.wezterm.lua` is intentionally not touched.
- **No upstream rebase expected** — kevinSC's repo has been dormant for
  months. Our fork is independent; we don't track or merge upstream.
- **Fork attribution** — keep `LICENSE` (GPLv3), preserve upstream credit
  in README.

## Related files outside this repo

- `~/.config/wezterm/wallpaper.lua` — optional shared module for random
  wallpaper. Not in this repo because it's also used by `~/.wezterm.lua`.
  If you add wallpaper support here, coordinate with both configs.
- `~/.wezterm.lua` — the main session's config, unrelated to this repo.
  Reference for what's NOT the dropdown's responsibility.
- `~/.config/kglobalshortcutsrc` — has the F12 binding. The dropdown's
  `.desktop` registration isn't shipped here; the README walks the user
  through `System Settings → Shortcuts → Add Command`. Don't hand-edit
  `kglobalshortcutsrc`; use the GUI.
