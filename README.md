# SPAI Tasks & Kanban for Omarchy

A fast, keyboard-first task manager, 5-column Kanban board, notes & ideas tracker, and quick capture overlay for [Omarchy](https://omarchy.org/) desktop based on the **SPAI** standard syntax.

---

## ✨ Features

- 📋 **5-Column Kanban Board**: `Todo` (`.`), `In Progress` (`/`), `Waiting` (`/.`), `Done` (`x` / `X`), and `Cancelled` (`z` / `Z`).
- ⚡ **Quick Capture Overlay**: Rapid capture modal summoned globally via `Ctrl + Alt + Space` with live syntax detection.
- 💡 **Notes & Ideas Hub**: Dedicated tabs for notes (`-`) and ideas (`?`) with 1-click & keyboard conversion to tasks.
- 🎯 **SPAI Syntax Support**:
  - Prefixes: `.` (todo), `/` (working), `/.` (waiting), `x` (done), `z` (cancelled), `-` (note), `?` (idea)
  - Priority: `!` (Urgent / High Priority)
  - Deadlines: `@today`, `@tomorrow`, `@YYYY-MM-DD`, `@DD.MM.`, `@DD.MM.YYYY`
  - Tags: `:tag1:tag2:`
- 📊 **Status Bar Widget**: Shows active pending task counter in the Omarchy bar.
- ⌨️ **Full Keyboard Control**: Vim-style navigation, 2-tier spatial arrow navigation (`↑` to Tabs, `↓` to Board), instant status moves (`1..5`), spacebar rotation loop, and Undo (`U`).

---

## 📦 Quick Installation

### Option 1: One-Line Installer (Recommended)

This automatically installs the plugin into Omarchy and prompts to configure the Hyprland shortcuts for you:

```bash
curl -sL https://raw.githubusercontent.com/mastnacek/omarchy-spai/main/install.sh | bash
```

### Option 2: Omarchy CLI

```bash
# 1. Install & enable via Omarchy CLI
omarchy plugin add https://github.com/mastnacek/omarchy-spai.git --enable

# 2. Automatically configure global Hyprland shortcuts
~/.config/omarchy/plugins/jara.spai/setup-bindings.sh
```

---

## ⌨️ Keyboard Shortcuts

### Global Hyprland Shortcuts

The setup script automatically adds these to `~/.config/hypr/bindings.lua` (or you can add them manually):

```lua
-- SPAI Quick Capture
o.bind("CTRL + ALT + SPACE", "SPAI Quick Capture", "omarchy-shell shell toggle jara.spai '{\"mode\":\"capture\"}'")

-- SPAI Kanban Board
o.bind("CTRL + ALT + K", "SPAI Kanban Board", "omarchy-shell shell toggle jara.spai '{\"mode\":\"kanban\"}'")
```

### In-App Shortcuts (Kanban / Notes / Ideas)

| Key | Action |
| --- | --- |
| `Ctrl + Alt + Space` | Open Quick Capture modal |
| `Ctrl + Alt + K` | Toggle Kanban Board overlay |
| `Space` | Rotate status to next stage / Convert note or idea to task |
| `1` / `.` / `t` | Move task / convert to **Todo** |
| `2` / `/` / `w` | Move task / convert to **Working** |
| `3` / `/.` / `p` | Move task / convert to **Waiting** |
| `4` / `x` / `d` | Move task / convert to **Done** |
| `5` / `z` / `c` | Move task / convert to **Cancelled** |
| `6` / `-` | Convert to **Note** / Switch to Notes tab |
| `7` / `?` | Convert to **Idea** / Switch to Ideas tab |
| `U` / `Ctrl + Z` | **Undo** last deletion |
| `↑` / `↓` or `k` / `j` | Navigate cards (`↑` on top card switches to Tab navigation) |
| `←` / `→` or `h` / `l` | Switch columns / switch tabs |
| `N` or `A` | New Item / Quick Capture |
| `/` | Focus search filter |
| `Delete` / `Backspace` | Delete selected card |
| `Esc` | Clear filter / Close overlay |

---

## 🛠 Validation

Validate the plugin against Omarchy specifications:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/jara.spai
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
