import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "SpaiModel.js" as SpaiModel

BarWidget {
  id: root
  moduleName: "jara.spai"

  property string spaiDataPath: Quickshell.env("HOME") + "/.local/share/spai/tasks.json"
  property var rawItems: []
  property var stats: ({ total: 0, todo: 0, working: 0, waiting: 0, done: 0, cancelled: 0, notes: 0, ideas: 0, pendingTotal: 0 })

  function loadData(rawText) {
    rawItems = SpaiModel.parseItems(rawText)
    stats = SpaiModel.getStats(rawItems)
  }

  FileView {
    id: dataFile
    path: root.spaiDataPath
    watchChanges: true
    printErrors: false
    onLoaded: root.loadData(text())
    onLoadFailed: root.loadData("[]")
    onFileChanged: reload()
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰄲 " + (root.stats.pendingTotal > 0 ? root.stats.pendingTotal : "0")
    tooltipText: "SPAI Tasks (" + root.stats.pendingTotal + " active)\n" +
                 "○ Todo: " + root.stats.todo + "  ·  ◐ Work: " + root.stats.working + "  ·  ⏳ Wait: " + root.stats.waiting + "\n" +
                 "✓ Done: " + root.stats.done + "  ·  󰎞 Notes: " + root.stats.notes + "  ·  󰌵 Ideas: " + root.stats.ideas + "\n" +
                 "• Left-click: Kanban Board\n• Right-click: Quick Capture"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", root.moduleName, "{\"mode\":\"kanban\"}"])
      } else if (buttonCode === Qt.RightButton) {
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", root.moduleName, "{\"mode\":\"capture\"}"])
      }
    }
  }
}
