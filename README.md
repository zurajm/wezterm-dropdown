# WezTerm Dropdown for KDE Plasma 6 (Wayland)

A native drop-down terminal powered by [WezTerm](https://wezfurlong.org/wezterm/) on **KDE Plasma 6 + Wayland**, with smooth slide animations and multi-monitor support.

> **Platform:** Arch Linux · KDE Plasma 6 · Wayland  
> **Dependencies:** `wezterm` · `kdotool` · `python3` (`kscreen-doctor` ships with `plasma-workspace`)

---

## Credits

Forked from [kevinSC/Wezterm-Dropdown](https://github.com/kevinSC/Wezterm-Dropdown)
(GPLv3), which provides the original toggle-script architecture and the
Plasma 6 / Wayland integration foundation. This fork adds mux-backed launch
(no KWin placement race on repeat F12), 1/3 monitor height + automatic
Plasma top-panel offset detection, tab bar support, multi-Activity
visibility, taskbar hiding, and various stability fixes.

See `git log` for the full history of changes.

---

## Features

- **Slide-in/out animation** — cubic easing (ease-out on show, ease-in on hide) at ~28 fps
- **Multi-monitor aware** — the terminal always appears on the monitor where the mouse cursor is
- **Plasma top-panel aware** — drops down *below* the panel, not behind it
- **Instant toggle** — a single keyboard shortcut shows/hides the dropdown
- **Borderless** — no title bar, full monitor width, anchored to the top
- **Mux-backed** — the dropdown's `wezterm-gui` stays running between F12 presses; `wezterm cli spawn` creates new windows in-process (no KWin placement race)
- **Activity-aware** — visible across all KDE Activities
- **Taskbar-hidden** — not shown in icon-only or regular taskbar (set via KWin scripting at window creation)
- **Separate config** — dropdown instance uses its own `dropdown.lua` + `dropdown_base.lua`, independent of your normal WezTerm config

---

## Requirements

System packages (Arch):

- `wezterm` — terminal emulator
- `kdotool` (AUR) — Wayland-native window-control utility
- `python3` — used by `wezterm-toggle.sh` for mouse-position parsing
- `ttf-jetbrains-mono-nerd` (AUR) — see font note below
- `kscreen-doctor` — bundled with `plasma-workspace`

Font note: `dropdown_base.lua` uses `JetBrainsMono NFM`, which resolves to
*JetBrainsMono Nerd Font Mono*. With plain `JetBrainsMono`, WezTerm spawns a
"Configuration Error" modal that occludes the dropdown window. Install
`ttf-jetbrains-mono-nerd` to avoid this.

---

## Setup

### 1. Clone and install

```bash
git clone https://github.com/zurajm/wezterm-dropdown.git ~/path/to/repo
cd ~/path/to/repo
./install.sh
```

The installer creates symlinks in `~/.config/wezterm/` pointing to the repo
files. You can `git pull` to update everything — no manual file copying.

> The repo can live anywhere. The installer resolves paths from its own
> directory; the path you choose during `git clone` is what gets symlinked.

### 2. Bind a key (F12 recommended)

- Open **System Settings → Shortcuts → Add Command / URL**
- Click **Add new → Command**
- **Name:** `WezTerm Dropdown`
- **Command:** `~/.config/wezterm/bin/wezterm-toggle.sh`
- **Shortcut:** `F12` (or your preference)

### 3. Test it

```bash
~/.config/wezterm/bin/wezterm-toggle.sh
```

Press the shortcut again to hide. Move your mouse to another monitor and press
again — the terminal follows the cursor.

---

## What the Lua config does (and why)

The toggle script requires three specific Lua settings to work. Everything
else in `dropdown.lua` / `dropdown_base.lua` is preference and can be
changed freely:

| Setting | Required? | Purpose |
|---|---|---|
| `config.window_decorations = "RESIZE"` | **Yes** | Without this, WezTerm declares itself a native fullscreen surface to KDE Wayland. KWin then memorises the original monitor size and forces it on every minimise/restore — the dropdown would be stuck at one size and would not respond to multi-monitor changes. |
| `config.unix_domains = {{ name = "dropdown" }}` | **Yes** | Without this, the toggle script's `wezterm cli spawn --domain-name dropdown` fails with "invalid domain dropdown" and falls back to spawning a fresh `wezterm-gui` per F12 press — reintroducing the KWin placement race. |
| `config.font = wezterm.font_with_fallback({...})` with a valid font | **Yes** | Without a resolvable font, WezTerm spawns a "Configuration Error" modal that occludes the dropdown window. Any valid font works; `JetBrainsMono NFM` is the recommended Nerd Font Mono shorthand. |
| Everything else (color scheme, opacity, font size, tab bar) | No | Cosmetic. Change freely. |

The install script creates **symlinks** from the standard system paths to this repo:

| System path | Points to |
|---|---|
| `~/.config/wezterm/dropdown.lua` | `wezterm/dropdown.lua` |
| `~/.config/wezterm/dropdown_base.lua` | `wezterm/dropdown_base.lua` |
| `~/.config/wezterm/bin/wezterm-toggle.sh` | `scripts/wezterm-toggle.sh` |

This means you can `git pull` to update everything — no manual file copying needed.

The installer intentionally does **not** overwrite `~/.config/wezterm/wezterm.lua`, so you can keep your own normal WezTerm config or pair this repo with another one.

---

## Uninstall

```bash
./uninstall.sh
```

Removes all symlinks. If a file was backed up during install (`*.bak`), it is restored automatically.

---

## Repository structure

```
.
├── install.sh                    ← creates symlinks
├── uninstall.sh                  ← removes symlinks
├── wezterm/
│   ├── dropdown.lua              ← dropdown-specific config (window decorations, mux domain, tab bar)
│   ├── dropdown_base.lua         ← shared defaults (font, color scheme, opacity)
│   └── wezterm.lua               ← optional launcher example with matching style
└── scripts/
    └── wezterm-toggle.sh         ← toggle script (kdotool-based window management + KWin scripting)
```

---

## License

GPLv3
