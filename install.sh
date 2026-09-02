#!/usr/bin/env bash
set -euo pipefail

# SPAI Automated Installation & Setup Script for Omarchy

PLUGIN_URL="https://github.com/mastnacek/omarchy-spai.git"
PLUGIN_ID="jara.spai"
PLUGIN_DIR="$HOME/.config/omarchy/plugins/$PLUGIN_ID"

echo "========================================="
echo "   SPAI Tasks & Kanban for Omarchy       "
echo "========================================="

# 1. Install / Update Plugin
if [[ -d "$PLUGIN_DIR" ]]; then
  echo "==> Plugin $PLUGIN_ID is already installed. Updating..."
  if command -v omarchy &>/dev/null; then
    omarchy plugin update "$PLUGIN_ID" || true
  fi
else
  echo "==> Installing plugin from $PLUGIN_URL..."
  if command -v omarchy &>/dev/null; then
    omarchy plugin add "$PLUGIN_URL" --enable
  else
    echo "Error: 'omarchy' CLI not found. Make sure you are running on Omarchy Linux." >&2
    exit 1
  fi
fi

# 2. Configure Global Hyprland Shortcuts
echo ""
read -r -p "Do you want to automatically set up Hyprland shortcuts (Ctrl+Alt+K and Ctrl+Alt+Space)? [Y/n] " response
response=${response:-Y}

if [[ "$response" =~ ^[Yy]$ ]]; then
  if [[ -f "$PLUGIN_DIR/setup-bindings.sh" ]]; then
    bash "$PLUGIN_DIR/setup-bindings.sh"
  else
    echo "Warning: setup-bindings.sh not found in $PLUGIN_DIR"
  fi
else
  echo ""
  echo "Skipping automatic shortcut configuration."
  echo "You can set them up manually anytime by adding these lines to ~/.config/hypr/bindings.lua:"
  echo ""
  echo "  o.bind(\"CTRL + ALT + SPACE\", \"SPAI Quick Capture\", \"omarchy-shell shell toggle jara.spai '{\\\"mode\\\":\\\"capture\\\"}'\")"
  echo "  o.bind(\"CTRL + ALT + K\", \"SPAI Kanban Board\", \"omarchy-shell shell toggle jara.spai '{\\\"mode\\\":\\\"kanban\\\"}'\")"
  echo ""
  echo "Or by running:"
  echo "  ~/.config/omarchy/plugins/jara.spai/setup-bindings.sh"
fi

echo ""
echo "========================================="
echo "✔ Installation completed successfully! 🎉"
echo "========================================="
