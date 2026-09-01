# SPAI Tasks & Kanban for Omarchy

A fast, keyboard-first task manager, Kanban board, notes & ideas tracker, and quick capture overlay for [Omarchy](https://omarchy.org/) desktop based on the **SPAI** standard syntax.

![SPAI Omarchy Plugin Preview](preview.png)

---

## ✨ Features

- 📋 **Kanban Board** with 4 interactive columns: `Todo` (`.`), `In Progress` (`/`), `Waiting` (`/.`), and `Done` (`x`).
- ⚡ **Quick Capture Overlay**: Rapid capture modal summoned globally via `Ctrl + Alt + Space`.
- 💡 **Notes & Ideas Hub**: Dedicated tabs for notes (`-`) and ideas (`?`) with 1-click conversion to tasks.
- 🎯 **SPAI Syntax Support**:
  - Prefixes: `.` (todo), `/` (working), `/.` (waiting), `x` (done), `-` (note), `?` (idea)
  - Priority: `!` (Urgent / High Priority)
  - Deadlines: `@YYYY-MM-DD` or `@DD.MM.`
  - Tags: `:tag1:tag2:`
- 📊 **Status Bar Widget**: Shows active pending task counter in the Omarchy bar.
- ⌨️ **Full Keyboard Control**: Vim-style navigation, instant column switching, search filter, and quick actions.

---

## ⌨️ Keyboard Shortcuts

### Global Hyprland Shortcuts

Add these to `~/.config/hypr/bindings.conf`:

```ini
# SPAI Quick Capture
bind = Control+Alt, Space, exec, omarchy-shell shell summon jara.spai '{"mode":"capture"}'

# SPAI Kanban Board
bind = Control+Alt, K, exec, omarchy-shell shell summon jara.spai '{"mode":"kanban"}'
```

### In-App Shortcuts (Kanban / Notes / Ideas)

| Key | Action |
| --- | --- |
| `Ctrl + Alt + Space` | Open Quick Capture modal |
| `N` or `A` | New Item / Quick Capture |
| `/` | Focus search filter |
| `1` / `2` / `3` / `4` | Jump to column (`Todo`, `In Progress`, `Waiting`, `Done`) |
| `5` / `6` | Jump to `Notes` / `Ideas` tab |
| `Tab` / `Shift + Tab` | Cycle active column |
| `H` / `L` or `←` / `→` | Move card between columns |
| `X` or `D` | Toggle card Done |
| `Delete` | Delete selected card |
| `Esc` | Clear filter / Close overlay |

---

## 📦 Installation

### Direct Install via Omarchy CLI

```bash
omarchy plugin add https://github.com/mastnacek/omarchy-spai.git --enable
```

### Local Development / Manual Install

```bash
# Clone into Omarchy plugins directory
mkdir -p ~/.config/omarchy/plugins/jara.spai
cp -r * ~/.config/omarchy/plugins/jara.spai/

# Rescan and enable
omarchy-shell shell rescanPlugins
omarchy plugin enable jara.spai
```

---

## 🛠 Validation

Validate the plugin against Omarchy specifications:

```bash
omarchy plugin validate ~/.config/omarchy/plugins/jara.spai
qmllint -I "$OMARCHY_PATH/shell" ~/.config/omarchy/plugins/jara.spai/BarWidget.qml
```

---

## 📄 License

MIT License. See [LICENSE](LICENSE) for details.
