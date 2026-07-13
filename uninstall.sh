#!/usr/bin/env bash
# uninstall.sh — Remove WezTerm Dropdown symlinks from the system.
#
# Removes all symlinks created by install.sh.
# If a .bak backup exists, it is restored automatically.

set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[uninstall]${NC} $*"; }
warn() { echo -e "${YELLOW}[warn]${NC}      $*"; }

# safe_unlink_owned <link_path>
# Removes the symlink only if it points into this repo, then restores a .bak backup.
safe_unlink_owned() {
    local link="$1"

    if [[ -L "$link" ]]; then
        local current_target
        current_target="$(readlink -f "$link")"

        if [[ "$current_target" == "$REPO_DIR" || "$current_target" == "$REPO_DIR/"* ]]; then
            rm "$link"
            info "Removed symlink: $link"
            if [[ -e "${link}.bak" ]]; then
                mv "${link}.bak" "$link"
                info "Restored backup: ${link}.bak → $link"
            fi
        else
            warn "Symlink not owned by this repo, skipping: $link → $current_target"
        fi
    elif [[ -e "$link" ]]; then
        warn "Not a symlink, skipping: $link"
    else
        warn "Does not exist, skipping: $link"
    fi
}

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  WezTerm Dropdown — Uninstall"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

safe_unlink_owned "$HOME/.config/wezterm/dropdown.lua"
safe_unlink_owned "$HOME/.config/wezterm/dropdown_base.lua"
safe_unlink_owned "$HOME/.config/wezterm/bin/wezterm-toggle.sh"

# Legacy cleanup: older versions also owned ~/.config/wezterm/wezterm.lua
# and a KWin script at ~/.local/share/kwin/scripts/wezterm-dropdown.
safe_unlink_owned "$HOME/.config/wezterm/wezterm.lua"
safe_unlink_owned "$HOME/.local/share/kwin/scripts/wezterm-dropdown"

echo ""
info "Done. Remember to remove the KDE keyboard shortcut manually:"
echo "     System Settings → Shortcuts → search 'WezTerm'"
echo ""
