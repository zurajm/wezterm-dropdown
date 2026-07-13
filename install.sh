#!/usr/bin/env bash
# install.sh — Set up WezTerm Dropdown on a new system.
#
# Creates symlinks from the system config paths to this repo, so you can
# manage everything from a single git repository without copying files.
#
# Usage:
#   git clone <repo> ~/Experiments/Wezterm/Wezterm-Dropdown
#   cd ~/Experiments/Wezterm/Wezterm-Dropdown
#   ./install.sh
#
# Any clone path works; REPO_DIR is resolved dynamically from this script.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

info()    { echo -e "${GREEN}[install]${NC} $*"; }
warn()    { echo -e "${YELLOW}[warn]${NC}    $*"; }
error()   { echo -e "${RED}[error]${NC}   $*"; }

# safe_link <target_in_repo> <link_path_in_system>
# Creates a symlink. If the path already exists (and is not a symlink to us),
# backs it up with a .bak suffix before replacing it.
safe_link() {
    local target="$1"
    local link="$2"
    local link_dir
    link_dir="$(dirname "$link")"

    # Create parent directory if needed
    mkdir -p "$link_dir"

    if [[ -L "$link" ]]; then
        local current_target
        current_target="$(readlink -f "$link" || true)"
        if [[ "$current_target" == "$(readlink -f "$target")" ]]; then
            info "Already linked: $link → already points to repo. Skipping."
            return
        else
            warn "Replacing existing symlink: $link → $current_target"
            rm "$link"
        fi
    elif [[ -e "$link" ]]; then
        warn "Backing up existing file: $link → ${link}.bak"
        mv "$link" "${link}.bak"
    fi

    ln -s "$target" "$link"
    info "Linked: $link → $target"
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  WezTerm Dropdown — Install"
echo "  Repo: $REPO_DIR"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# ── Dropdown-specific WezTerm configs ────────────────────────────────────── #
safe_link "$REPO_DIR/wezterm/dropdown.lua"      "$HOME/.config/wezterm/dropdown.lua"
safe_link "$REPO_DIR/wezterm/dropdown_base.lua" "$HOME/.config/wezterm/dropdown_base.lua"

# ── Toggle script ────────────────────────────────────────────────────────── #
chmod +x "$REPO_DIR/scripts/wezterm-toggle.sh"
safe_link "$REPO_DIR/scripts/wezterm-toggle.sh" "$HOME/.config/wezterm/bin/wezterm-toggle.sh"

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
info "Done! Next steps:"
echo ""
echo "  1. Add the keyboard shortcut in KDE:"
echo "     System Settings → Shortcuts → Add Command"
echo "     Command: $HOME/.config/wezterm/bin/wezterm-toggle.sh"
echo "     Shortcut: F12 (or your preference)"
echo ""
echo "  2. Test it:"
echo "     $HOME/.config/wezterm/bin/wezterm-toggle.sh"
echo ""
echo "  Full setup guide: README.md"
echo ""
