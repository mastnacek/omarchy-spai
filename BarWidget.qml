import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "SpaiModel.js" as SpaiModel

BarWidget {
  id: root
  moduleName: "jara.spai"

  property string spaiDataPath: Quickshell.env("HOME") + "/Documents/spai/.index.json"
  property var rawItems: []
  property var stats: ({ total: 0, todo: 0, working: 0, waiting: 0, done: 0, cancelled: 0, notes: 0, ideas: 0, pendingTotal: 0 })

  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false
  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function open() { if (panelLoader.item) panelLoader.item.open() }
  function close() { if (panelLoader.item) panelLoader.item.close() }
  function toggle() { if (panelLoader.item) panelLoader.item.toggle() }
  function closeForPopoutSwitch() { if (panelLoader.item) panelLoader.item.closeForPopoutSwitch() }

  function injectPanel() {
    if (!panelLoader.item) return
    panelLoader.item.bar = root.bar
    panelLoader.item.anchorItem = button
    panelLoader.item.hostWidget = root
  }

  onBarChanged: injectPanel()

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

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "󰄲 " + (root.stats.pendingTotal > 0 ? root.stats.pendingTotal : "0")
    tooltipText: "○ " + root.stats.todo + " Todo  ·  ◐ " + root.stats.working + " Work  ·  ⏳ " + root.stats.waiting + " Wait  ·  ✓ " + root.stats.done + " Done  ·  ✗ " + root.stats.cancelled + " Cancel\n" +
                 "󰎞 " + root.stats.notes + " Notes  ·  󰌵 " + root.stats.ideas + " Ideas\n" +
                 "• Left-click: Mini Board  ·  • Right-click: Quick Capture"
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        root.toggle()
      } else if (buttonCode === Qt.RightButton) {
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", root.moduleName, "{\"mode\":\"capture\"}"])
      }
    }
  }
}
