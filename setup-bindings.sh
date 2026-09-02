#!/usr/bin/env bash
set -euo pipefail

# SPAI Hyprland Keybindings Setup Script
# Safely configures Ctrl+Alt+K (Kanban) and Ctrl+Alt+Space (Capture) in ~/.config/hypr/bindings.lua

BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"

echo "==> Configuring Hyprland keybindings for SPAI..."

if [[ ! -f "$BINDINGS_FILE" ]]; then
  mkdir -p "$(dirname "$BINDINGS_FILE")"
  touch "$BINDINGS_FILE"
fi

# Check if bindings already exist
if grep -q "jara.spai" "$BINDINGS_FILE" 2>/dev/null; then
  echo "✔ SPAI keybindings are already present in $BINDINGS_FILE"
else
  # Backup existing bindings file
  BACKUP_FILE="${BINDINGS_FILE}.bak.$(date +%s)"
  cp "$BINDINGS_FILE" "$BACKUP_FILE"
  echo "✔ Backed up existing bindings to: $BACKUP_FILE"

  # Append bindings
  cat << 'EOF' >> "$BINDINGS_FILE"

-- SPAI Quick Capture & Kanban Board
o.bind("CTRL + ALT + SPACE", "SPAI Quick Capture", "omarchy-shell shell toggle jara.spai '{\"mode\":\"capture\"}'")
o.bind("CTRL + ALT + K", "SPAI Kanban Board", "omarchy-shell shell toggle jara.spai '{\"mode\":\"kanban\"}'")
EOF

  echo "✔ Added shortcuts to $BINDINGS_FILE"
fi

# Reload Hyprland config if hyprctl is available
if command -v hyprctl &>/dev/null; then
  echo "==> Reloading Hyprland configuration..."
  hyprctl reload >/dev/null 2>&1 || true
  echo "✔ Hyprland reloaded successfully!"
  echo ""
  echo "✨ Shortcuts are now active:"
  echo "   • Ctrl + Alt + K     → Open/Close Kanban Board"
  echo "   • Ctrl + Alt + Space → Open/Close Quick Capture modal"
else
  echo "ℹ Hyprland is not running or hyprctl is not in PATH. Keybindings will take effect on next login."
fi
