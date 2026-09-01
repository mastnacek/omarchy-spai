import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import QtQuick
import QtQuick.Controls as QQC
import qs.Commons
import qs.Ui
import "SpaiModel.js" as SpaiModel

Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property string spaiDataDir: Quickshell.env("HOME") + "/.local/share/spai"
  property string spaiDataPath: spaiDataDir + "/tasks.json"

  property bool opened: false
  property string viewMode: "kanban" // "kanban", "capture", "notes", "ideas"
  property string filterText: ""
  property int activeColumnIndex: 0  // 0: todo, 1: working, 2: waiting, 3: done, 4: cancelled
  property int selectedCardIndex: 0

  property var allItems: []
  property var stats: ({ total: 0, todo: 0, working: 0, waiting: 0, done: 0, cancelled: 0, notes: 0, ideas: 0, pendingTotal: 0 })

  // Surface tokens
  property color background: Color.menu.background
  property color foreground: Color.menu.text
  property color border: Color.menu.border
  property var borderSpec: Border.surfaceSpec("menu", "border", border, Math.max(1, Style.space(2)))
  property color scrim: Color.menu.scrim
  property color selectedBackground: Color.menu.selectedBackground
  property color selectedText: Color.menu.selectedText
  readonly property int cornerRadius: Style.cornerRadius
  property string fontFamily: Style.font.menuFamily
  property int contentMargin: Style.spacing.panelPadding
  property int contentSpacing: Style.spacing.md

  property int modalWidth: Math.min(Style.space(1280), panel.width - Style.gapsOut * 2)
  property int modalHeight: Math.min(Style.space(740), panel.height - Style.gapsOut * 2)
  property int captureWidth: Math.min(Style.space(680), panel.width - Style.gapsOut * 2)
  property alias captureInputText: captureInput.text

  function open(payloadJson) {
    ensureDataDir()
    root.opened = true
    root.filterText = ""
    root.selectedCardIndex = 0

    var payload = {}
    if (payloadJson) {
      try {
        payload = JSON.parse(payloadJson)
      } catch (_e) {}
    }

    if (payload && payload.mode) {
      root.viewMode = payload.mode
    } else {
      root.viewMode = "kanban"
    }

    root.refreshData()

    Qt.callLater(function() {
      if (root.viewMode === "capture") {
        captureInput.text = ""
        captureInput.forceActiveFocus()
      } else {
        keyCatcher.forceActiveFocus()
      }
    })
  }

  function close() {
    root.opened = false
  }

  function toggle(payloadJson) {
    if (root.opened) root.close()
    else root.open(payloadJson)
  }

  function ensureDataDir() {
    initProc.running = true
  }

  function loadData(rawText) {
    root.allItems = SpaiModel.parseItems(rawText)
    root.stats = SpaiModel.getStats(root.allItems)
    root.clampSelection()
  }

  function saveData() {
    dataFile.setText(SpaiModel.formatItems(root.allItems))
    root.stats = SpaiModel.getStats(root.allItems)
    root.clampSelection()
  }

  function refreshData() {
    dataFile.reload()
  }

  function addNewItem(rawText) {
    if (!rawText || !rawText.trim()) return
    root.allItems = SpaiModel.addItem(root.allItems, rawText.trim())
    root.saveData()
  }

  function updateStatus(id, targetStatus) {
    root.allItems = SpaiModel.moveStatus(root.allItems, id, targetStatus)
    root.saveData()
  }

  function updateStatusAndFollow(id, targetStatus) {
    root.allItems = SpaiModel.moveStatus(root.allItems, id, targetStatus)
    root.saveData()

    var statuses = ["todo", "working", "waiting", "done", "cancelled"]
    var targetColIdx = statuses.indexOf(targetStatus)
    if (targetColIdx !== -1) {
      root.activeColumnIndex = targetColIdx
      var targetTasks = root.getFilteredList("Todo", targetStatus)
      var newIdx = 0
      for (var i = 0; i < targetTasks.length; i++) {
        if (targetTasks[i].id === id) {
          newIdx = i
          break
        }
      }
      root.selectedCardIndex = newIdx
    }
  }

  function cycleItemStatus(id, direction) {
    root.allItems = SpaiModel.cycleStatus(root.allItems, id, direction)
    root.saveData()
  }

  function cycleItemStatusAndFollow(id, direction) {
    var cur = null
    for (var i = 0; i < root.allItems.length; i++) {
      if (root.allItems[i].id === id) {
        cur = root.allItems[i]
        break
      }
    }
    if (!cur) return

    var statuses = ["todo", "working", "waiting", "done", "cancelled"]
    var idx = statuses.indexOf(cur.status)
    if (idx === -1) idx = 0
    var nextIdx = (idx + direction + statuses.length) % statuses.length
    var nextStatus = statuses[nextIdx]

    root.updateStatusAndFollow(id, nextStatus)
  }

  function deleteItem(id) {
    root.allItems = SpaiModel.removeItem(root.allItems, id)
    root.saveData()
  }

  function getFilteredList(typeFilter, statusFilter) {
    return SpaiModel.filterItems(root.allItems, root.filterText, typeFilter, statusFilter)
  }

  function getActiveColumnTasks() {
    var statuses = ["todo", "working", "waiting", "done", "cancelled"]
    var st = statuses[root.activeColumnIndex] || "todo"
    return root.getFilteredList("Todo", st)
  }

  function getSelectedTask() {
    var list = root.getActiveColumnTasks()
    if (list.length === 0) return null
    var idx = Math.max(0, Math.min(root.selectedCardIndex, list.length - 1))
    return list[idx] || null
  }

  function clampSelection() {
    var list = root.getActiveColumnTasks()
    if (list.length === 0) {
      root.selectedCardIndex = 0
    } else if (root.selectedCardIndex >= list.length) {
      root.selectedCardIndex = list.length - 1
    } else if (root.selectedCardIndex < 0) {
      root.selectedCardIndex = 0
    }
  }

  function insertTokenIntoCapture(token, isPrefix) {
    var cur = captureInput.text
    if (isPrefix) {
      var prefixes = SpaiModel.getSpaiPrefixes()
      for (var i = 0; i < prefixes.length; i++) {
        if (cur.indexOf(prefixes[i].prefix) === 0) {
          cur = cur.slice(prefixes[i].prefix.length)
          break
        }
      }
      captureInput.text = token + cur
    } else {
      captureInput.text = cur + (cur && !cur.endsWith(" ") ? " " : "") + token + " "
    }
    captureInput.forceActiveFocus()
  }

  Process {
    id: initProc
    command: ["mkdir", "-p", root.spaiDataDir]
  }

  FileView {
    id: dataFile
    path: root.spaiDataPath
    watchChanges: true
    atomicWrites: true
    printErrors: false
    onLoaded: root.loadData(text())
    onLoadFailed: root.loadData("[]")
    onFileChanged: reload()
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omarchy-spai"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: root.scrim
    }

    MouseArea {
      anchors.fill: parent
      onClicked: root.close()
    }

    // ==========================================
    // 1. QUICK CAPTURE MODAL
    // ==========================================
    BorderSurface {
      id: captureModal
      visible: root.viewMode === "capture"
      width: root.captureWidth
      height: captureCol.implicitHeight + Style.space(36)
      radius: root.cornerRadius + Style.space(4)
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec

      readonly property var detected: SpaiModel.parseRawItem(captureInput.text)

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        id: captureCol
        anchors.fill: parent
        anchors.margins: Style.space(18)
        spacing: Style.space(12)

        // Header
        Row {
          width: parent.width
          height: Style.space(32)

          Row {
            spacing: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              width: Style.space(28)
              height: Style.space(28)
              radius: Style.space(6)
              color: Util.alpha(Color.accent, 0.18)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                text: "󰄲"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
            }

            Text {
              text: "SPAI Quick Capture"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          Item {
            width: Math.max(0, parent.width - Style.space(400))
            height: 1
          }

          // Keycap Hints
          Row {
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              height: Style.space(22)
              width: escKeyText.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: Util.alpha(root.foreground, 0.08)
              border.color: Util.alpha(root.border, 0.2)
              border.width: 1

              Text {
                id: escKeyText
                anchors.centerIn: parent
                text: "Esc Cancel"
                color: Color.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }
            }

            Rectangle {
              height: Style.space(22)
              width: enterKeyText.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: Util.alpha(Color.accent, 0.2)
              border.color: Util.alpha(Color.accent, 0.4)
              border.width: 1

              Text {
                id: enterKeyText
                anchors.centerIn: parent
                text: "↵ Enter Save"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }
        }

        // Input Box
        Rectangle {
          width: parent.width
          height: Style.space(48)
          radius: root.cornerRadius
          color: Util.alpha(root.foreground, 0.05)
          border.color: captureInput.activeFocus ? Color.accent : Util.alpha(root.border, 0.3)
          border.width: captureInput.activeFocus ? Style.space(2) : Style.normalBorderWidth

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(8)

            TextInput {
              id: captureInput
              width: parent.width
              height: parent.height
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              verticalAlignment: TextInput.AlignVCenter
              clip: true

              Keys.onEscapePressed: function(event) {
                root.close()
                event.accepted = true
              }

              Keys.onReturnPressed: function(event) {
                if (captureInput.text.trim()) {
                  root.addNewItem(captureInput.text)
                  captureInput.text = ""
                  root.close()
                }
                event.accepted = true
              }

              Text {
                visible: !captureInput.text
                text: "e.g. . Review design ! @tomorrow :ui: or ? Fresh idea"
                color: Color.muted
                opacity: 0.6
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
              }
            }
          }
        }

        // Live Syntax Detection Preview Bar
        Rectangle {
          width: parent.width
          height: Style.space(32)
          radius: Style.space(6)
          color: Util.alpha(Color.menu.background, 0.9)
          border.color: Util.alpha(Color.menu.border, 0.2)
          border.width: 1
          visible: Boolean(captureModal.detected)

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(8)
            anchors.rightMargin: Style.space(8)
            spacing: Style.space(8)

            Text {
              text: "Detected:"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
            }

            // Type Badge
            Rectangle {
              height: Style.space(20)
              width: detTypeText.implicitWidth + Style.space(12)
              radius: Style.space(4)
              anchors.verticalCenter: parent.verticalCenter
              color: {
                if (!captureModal.detected) return "transparent"
                var st = captureModal.detected.status
                if (st === "todo") return Util.alpha("#38bdf8", 0.2)
                if (st === "working") return Util.alpha("#f59e0b", 0.2)
                if (st === "waiting") return Util.alpha("#a855f7", 0.2)
                if (st === "done") return Util.alpha("#10b981", 0.2)
                if (st === "cancelled") return Util.alpha("#94a3b8", 0.2)
                if (st === "idea") return Util.alpha("#ec4899", 0.2)
                return Util.alpha(root.foreground, 0.15)
              }
              border.color: {
                if (!captureModal.detected) return "transparent"
                var st = captureModal.detected.status
                if (st === "todo") return "#38bdf8"
                if (st === "working") return "#f59e0b"
                if (st === "waiting") return "#a855f7"
                if (st === "done") return "#10b981"
                if (st === "cancelled") return "#94a3b8"
                if (st === "idea") return "#ec4899"
                return root.foreground
              }
              border.width: 1

              Text {
                id: detTypeText
                anchors.centerIn: parent
                text: {
                  if (!captureModal.detected) return ""
                  var st = captureModal.detected.status
                  if (st === "todo") return "○ TODO"
                  if (st === "working") return "◐ WORKING"
                  if (st === "waiting") return "⏳ WAITING"
                  if (st === "done") return "✓ DONE"
                  if (st === "cancelled") return "✗ CANCELLED"
                  if (st === "idea") return "󰌵 IDEA"
                  if (st === "note") return "󰎞 NOTE"
                  return st.toUpperCase()
                }
                color: {
                  if (!captureModal.detected) return root.foreground
                  var st = captureModal.detected.status
                  if (st === "todo") return "#38bdf8"
                  if (st === "working") return "#f59e0b"
                  if (st === "waiting") return "#a855f7"
                  if (st === "done") return "#10b981"
                  if (st === "cancelled") return "#94a3b8"
                  if (st === "idea") return "#ec4899"
                  return root.foreground
                }
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            // Priority Badge
            Rectangle {
              visible: captureModal.detected && captureModal.detected.priority === "high"
              height: Style.space(20)
              width: Style.space(68)
              radius: Style.space(4)
              color: Util.alpha(Color.urgent, 0.2)
              border.color: Color.urgent
              border.width: 1
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                text: "! Urgent"
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }

            // Deadline Badge
            Rectangle {
              visible: captureModal.detected && Boolean(captureModal.detected.deadline)
              height: Style.space(20)
              width: detDeadText.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: Util.alpha(Color.accent, 0.15)
              border.color: Util.alpha(Color.accent, 0.35)
              border.width: 1
              anchors.verticalCenter: parent.verticalCenter

              Row {
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "󰃰"; color: Color.accent; font.pixelSize: Style.font.caption }
                Text {
                  id: detDeadText
                  text: captureModal.detected ? captureModal.detected.deadline : ""
                  color: Color.accent
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }
            }

            // Clean Title preview
            Text {
              text: captureModal.detected ? captureModal.detected.title : ""
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              elide: Text.ElideRight
              width: parent.width - Style.space(320)
              anchors.verticalCenter: parent.verticalCenter
            }
          }
        }

        // Interactive Syntax Quick Buttons
        Column {
          width: parent.width
          spacing: Style.space(8)

          // Prefix Buttons
          Row {
            spacing: Style.space(6)

            Text {
              text: "Type:"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(40)
            }

            // . Todo
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.status === "todo"
              height: Style.space(24)
              width: p1Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha("#38bdf8", 0.35) : Util.alpha("#38bdf8", 0.12)
              border.color: isCurrent ? "#38bdf8" : Util.alpha("#38bdf8", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p1Text
                anchors.centerIn: parent
                text: ". Todo"
                color: "#38bdf8"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture(". ", true)
              }
            }

            // / Working
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.status === "working"
              height: Style.space(24)
              width: p2Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha("#f59e0b", 0.35) : Util.alpha("#f59e0b", 0.12)
              border.color: isCurrent ? "#f59e0b" : Util.alpha("#f59e0b", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p2Text
                anchors.centerIn: parent
                text: "/ Work"
                color: "#f59e0b"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture("/ ", true)
              }
            }

            // /. Waiting
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.status === "waiting"
              height: Style.space(24)
              width: p3Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha("#a855f7", 0.35) : Util.alpha("#a855f7", 0.12)
              border.color: isCurrent ? "#a855f7" : Util.alpha("#a855f7", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p3Text
                anchors.centerIn: parent
                text: "/. Wait"
                color: "#a855f7"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture("/. ", true)
              }
            }

            // x Done
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.status === "done"
              height: Style.space(24)
              width: pxText.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha("#10b981", 0.35) : Util.alpha("#10b981", 0.12)
              border.color: isCurrent ? "#10b981" : Util.alpha("#10b981", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: pxText
                anchors.centerIn: parent
                text: "x Done"
                color: "#10b981"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture("x ", true)
              }
            }

            // z Cancelled
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.status === "cancelled"
              height: Style.space(24)
              width: p6Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha("#94a3b8", 0.35) : Util.alpha("#94a3b8", 0.12)
              border.color: isCurrent ? "#94a3b8" : Util.alpha("#94a3b8", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p6Text
                anchors.centerIn: parent
                text: "z Cancel"
                color: "#94a3b8"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture("z ", true)
              }
            }

            // ? Idea
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.status === "idea"
              height: Style.space(24)
              width: p4Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha("#ec4899", 0.35) : Util.alpha("#ec4899", 0.12)
              border.color: isCurrent ? "#ec4899" : Util.alpha("#ec4899", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p4Text
                anchors.centerIn: parent
                text: "? Idea"
                color: "#ec4899"
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture("? ", true)
              }
            }

            // - Note
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.status === "note"
              height: Style.space(24)
              width: p5Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha(root.foreground, 0.25) : Util.alpha(root.foreground, 0.08)
              border.color: isCurrent ? root.foreground : Util.alpha(root.border, 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p5Text
                anchors.centerIn: parent
                text: "- Note"
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture("- ", true)
              }
            }
          }

          // Modifier Buttons (!, @, :)
          Row {
            spacing: Style.space(6)

            Text {
              text: "Meta:"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
              anchors.verticalCenter: parent.verticalCenter
              width: Style.space(40)
            }

            // ! Priority
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.priority === "high"
              height: Style.space(24)
              width: m1Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha(Color.urgent, 0.35) : Util.alpha(Color.urgent, 0.12)
              border.color: isCurrent ? Color.urgent : Util.alpha(Color.urgent, 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: m1Text
                anchors.centerIn: parent
                text: "! Urgent"
                color: Color.urgent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture("!", false)
              }
            }

            // @ Deadline
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && Boolean(captureModal.detected.deadline)
              height: Style.space(24)
              width: m2Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha(Color.accent, 0.3) : Util.alpha(Color.accent, 0.1)
              border.color: isCurrent ? Color.accent : Util.alpha(Color.accent, 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: m2Text
                anchors.centerIn: parent
                text: "@date"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture("@today", false)
              }
            }

            // :tag:
            Rectangle {
              readonly property bool isCurrent: captureModal.detected && captureModal.detected.tags && captureModal.detected.tags.length > 0
              height: Style.space(24)
              width: m3Text.implicitWidth + Style.space(12)
              radius: Style.space(4)
              color: isCurrent ? Util.alpha(root.foreground, 0.2) : Util.alpha(root.foreground, 0.08)
              border.color: isCurrent ? Color.accent : Util.alpha(root.border, 0.2)
              border.width: isCurrent ? 2 : 1

              Text {
                id: m3Text
                anchors.centerIn: parent
                text: ":tag:"
                color: isCurrent ? Color.accent : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.insertTokenIntoCapture(":tag:", false)
              }
            }
          }
        }

        // Action Buttons Row
        Row {
          width: parent.width
          height: Style.space(34)
          spacing: Style.space(10)

          Item {
            width: Math.max(0, parent.width - Style.space(240))
            height: 1
          }

          // Cancel Button
          Rectangle {
            height: Style.space(32)
            width: Style.space(100)
            radius: root.cornerRadius
            color: Util.alpha(root.foreground, 0.08)

            Text {
              anchors.centerIn: parent
              text: "Cancel"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }

          // Save Button
          Rectangle {
            height: Style.space(32)
            width: Style.space(120)
            radius: root.cornerRadius
            color: Color.accent

            Text {
              anchors.centerIn: parent
              text: "Save Task"
              color: Color.background
              font.family: root.fontFamily
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                if (captureInput.text.trim()) {
                  root.addNewItem(captureInput.text)
                  captureInput.text = ""
                  root.close()
                }
              }
            }
          }
        }
      }
    }

    // ==========================================
    // 2. KANBAN / NOTES / IDEAS MAIN MODAL
    // ==========================================
    BorderSurface {
      id: mainModal
      visible: root.viewMode !== "capture"
      width: root.modalWidth
      height: root.modalHeight
      radius: root.cornerRadius + Style.space(4)
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec

      MouseArea { anchors.fill: parent; onClicked: {} }

      Item {
        id: keyCatcher
        anchors.fill: parent
        focus: true

        Keys.priority: Keys.BeforeItem
        Keys.onPressed: function(event) {
          if (event.key === Qt.Key_Escape) {
            if (root.filterText) {
              root.filterText = ""
            } else {
              root.close()
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Slash) {
            searchInput.forceActiveFocus()
            event.accepted = true
          } else if (event.key === Qt.Key_N || event.key === Qt.Key_A) {
            root.viewMode = "capture"
            Qt.callLater(function() {
              captureInput.text = ""
              captureInput.forceActiveFocus()
            })
            event.accepted = true
          } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
            if (root.viewMode === "kanban") {
              root.activeColumnIndex = (root.activeColumnIndex - 1 + 5) % 5
              root.clampSelection()
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
            if (root.viewMode === "kanban") {
              root.activeColumnIndex = (root.activeColumnIndex + 1) % 5
              root.clampSelection()
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
            if (root.viewMode === "kanban") {
              if (root.selectedCardIndex > 0) root.selectedCardIndex--
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
            if (root.viewMode === "kanban") {
              var tasks = root.getActiveColumnTasks()
              if (root.selectedCardIndex < tasks.length - 1) root.selectedCardIndex++
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Space) {
            // Cycle status loop in Kanban mode while following focus!
            if (root.viewMode === "kanban") {
              var curTask = root.getSelectedTask()
              if (curTask) {
                if (event.modifiers & Qt.ShiftModifier) {
                  root.cycleItemStatusAndFollow(curTask.id, -1)
                } else {
                  root.cycleItemStatusAndFollow(curTask.id, 1)
                }
              }
            }
            event.accepted = true
          } else if (event.key === Qt.Key_X || event.key === Qt.Key_D) {
            if (root.viewMode === "kanban") {
              var curTaskD = root.getSelectedTask()
              if (curTaskD) {
                var nextSt = curTaskD.status === "done" ? "todo" : "done"
                root.updateStatusAndFollow(curTaskD.id, nextSt)
              }
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Z || event.key === Qt.Key_C) {
            if (root.viewMode === "kanban") {
              var curTaskZ = root.getSelectedTask()
              if (curTaskZ) {
                root.updateStatusAndFollow(curTaskZ.id, "cancelled")
              }
            }
            event.accepted = true
          } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
            if (root.viewMode === "kanban") {
              var curTaskDel = root.getSelectedTask()
              if (curTaskDel) {
                root.deleteItem(curTaskDel.id)
              }
            }
            event.accepted = true
          } else if (event.key === Qt.Key_1) {
            if (root.viewMode === "kanban") {
              var t1 = root.getSelectedTask()
              if (t1) root.updateStatusAndFollow(t1.id, "todo")
              else root.activeColumnIndex = 0
            }
            event.accepted = true
          } else if (event.key === Qt.Key_2) {
            if (root.viewMode === "kanban") {
              var t2 = root.getSelectedTask()
              if (t2) root.updateStatusAndFollow(t2.id, "working")
              else root.activeColumnIndex = 1
            }
            event.accepted = true
          } else if (event.key === Qt.Key_3) {
            if (root.viewMode === "kanban") {
              var t3 = root.getSelectedTask()
              if (t3) root.updateStatusAndFollow(t3.id, "waiting")
              else root.activeColumnIndex = 2
            }
            event.accepted = true
          } else if (event.key === Qt.Key_4) {
            if (root.viewMode === "kanban") {
              var t4 = root.getSelectedTask()
              if (t4) root.updateStatusAndFollow(t4.id, "done")
              else root.activeColumnIndex = 3
            }
            event.accepted = true
          } else if (event.key === Qt.Key_5) {
            if (root.viewMode === "kanban") {
              var t5 = root.getSelectedTask()
              if (t5) root.updateStatusAndFollow(t5.id, "cancelled")
              else root.activeColumnIndex = 4
            }
            event.accepted = true
          } else if (event.key === Qt.Key_6) {
            root.viewMode = "notes"
            event.accepted = true
          } else if (event.key === Qt.Key_7) {
            root.viewMode = "ideas"
            event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            if (root.viewMode === "kanban") {
              if (event.modifiers & Qt.ShiftModifier) {
                root.activeColumnIndex = (root.activeColumnIndex + 4) % 5
              } else {
                root.activeColumnIndex = (root.activeColumnIndex + 1) % 5
              }
              root.clampSelection()
            }
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(16)
        spacing: Style.space(12)

        // --- Header Bar ---
        Row {
          width: parent.width
          height: Style.space(38)
          spacing: Style.space(12)

          // Brand
          Row {
            spacing: Style.space(8)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              width: Style.space(30)
              height: Style.space(30)
              radius: Style.space(6)
              color: Util.alpha(Color.accent, 0.18)
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                text: "󰄲"
                color: Color.accent
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
            }

            Text {
              text: "SPAI"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Tabs Switcher
          Row {
            spacing: Style.space(4)
            anchors.verticalCenter: parent.verticalCenter

            // Kanban Tab
            Rectangle {
              height: Style.space(32)
              width: tabKanbanText.implicitWidth + Style.space(22)
              radius: root.cornerRadius
              color: root.viewMode === "kanban" ? root.selectedBackground : Util.alpha(root.foreground, 0.05)

              Text {
                id: tabKanbanText
                anchors.centerIn: parent
                text: "Kanban (" + root.stats.pendingTotal + ")"
                color: root.viewMode === "kanban" ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: root.viewMode === "kanban"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.viewMode = "kanban"; keyCatcher.forceActiveFocus() }
              }
            }

            // Notes Tab
            Rectangle {
              height: Style.space(32)
              width: tabNotesText.implicitWidth + Style.space(22)
              radius: root.cornerRadius
              color: root.viewMode === "notes" ? root.selectedBackground : Util.alpha(root.foreground, 0.05)

              Text {
                id: tabNotesText
                anchors.centerIn: parent
                text: "Notes (" + root.stats.notes + ")"
                color: root.viewMode === "notes" ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: root.viewMode === "notes"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.viewMode = "notes"; keyCatcher.forceActiveFocus() }
              }
            }

            // Ideas Tab
            Rectangle {
              height: Style.space(32)
              width: tabIdeasText.implicitWidth + Style.space(22)
              radius: root.cornerRadius
              color: root.viewMode === "ideas" ? root.selectedBackground : Util.alpha(root.foreground, 0.05)

              Text {
                id: tabIdeasText
                anchors.centerIn: parent
                text: "Ideas (" + root.stats.ideas + ")"
                color: root.viewMode === "ideas" ? root.selectedText : root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: root.viewMode === "ideas"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.viewMode = "ideas"; keyCatcher.forceActiveFocus() }
              }
            }
          }

          Item {
            width: Math.max(0, parent.width - Style.space(760))
            height: 1
          }

          // Search Field
          Rectangle {
            width: Style.space(220)
            height: Style.space(32)
            radius: root.cornerRadius
            color: Util.alpha(root.foreground, 0.06)
            border.color: searchInput.activeFocus ? Color.accent : Util.alpha(root.border, 0.25)
            border.width: Style.normalBorderWidth
            anchors.verticalCenter: parent.verticalCenter

            Row {
              anchors.fill: parent
              anchors.leftMargin: Style.space(8)
              anchors.rightMargin: Style.space(8)
              spacing: Style.space(6)

              Text {
                text: "󰍉"
                color: Color.muted
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
              }

              TextInput {
                id: searchInput
                width: parent.width - Style.space(40)
                color: root.foreground
                font.family: root.fontFamily
                font.pixelSize: Style.font.body
                anchors.verticalCenter: parent.verticalCenter
                clip: true
                text: root.filterText
                onTextChanged: root.filterText = text

                Keys.onEscapePressed: function(event) {
                  if (text) {
                    text = ""
                  } else {
                    keyCatcher.forceActiveFocus()
                  }
                  event.accepted = true
                }

                Text {
                  visible: !searchInput.text
                  text: "Filter (/)..."
                  color: Color.muted
                  opacity: 0.6
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                }
              }

              // Clear button
              Text {
                visible: searchInput.text.length > 0
                text: "✕"
                color: Color.muted
                font.pixelSize: Style.font.caption
                anchors.verticalCenter: parent.verticalCenter
                MouseArea {
                  anchors.fill: parent
                  cursorShape: Qt.PointingHandCursor
                  onClicked: searchInput.text = ""
                }
              }
            }
          }

          // + New Item Button
          Rectangle {
            height: Style.space(32)
            width: newItemBtnText.implicitWidth + Style.space(20)
            radius: root.cornerRadius
            color: Color.accent
            anchors.verticalCenter: parent.verticalCenter

            Row {
              id: newItemBtnText
              anchors.centerIn: parent
              spacing: Style.space(4)

              Text {
                text: "+"
                color: Color.background
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Text {
                text: "New (N)"
                color: Color.background
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: {
                root.viewMode = "capture"
                Qt.callLater(function() {
                  captureInput.text = ""
                  captureInput.forceActiveFocus()
                })
              }
            }
          }

          // Close button
          Rectangle {
            height: Style.space(32)
            width: Style.space(32)
            radius: root.cornerRadius
            color: Util.alpha(root.foreground, 0.08)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              anchors.centerIn: parent
              text: "✕"
              color: root.foreground
              font.pixelSize: Style.font.body
            }

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.close()
            }
          }
        }

        // --- Body: KANBAN BOARD & BOTTOM PREVIEW ---
        Item {
          visible: root.viewMode === "kanban"
          width: parent.width
          height: parent.height - Style.space(50)

          Column {
            anchors.fill: parent
            spacing: Style.space(10)

            // Top: 5 Kanban Columns
            Row {
              width: parent.width
              height: parent.height - Style.space(120)
              spacing: Style.space(12)

              // Column 1: Todo
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "Todo"
                columnStatus: "todo"
                columnType: "Todo"
                badgeColor: "#38bdf8"
                columnIndex: 0
                isActive: root.activeColumnIndex === 0
                rootView: root
              }

              // Column 2: In Progress
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "In Progress"
                columnStatus: "working"
                columnType: "Todo"
                badgeColor: "#f59e0b"
                columnIndex: 1
                isActive: root.activeColumnIndex === 1
                rootView: root
              }

              // Column 3: Waiting
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "Waiting"
                columnStatus: "waiting"
                columnType: "Todo"
                badgeColor: "#a855f7"
                columnIndex: 2
                isActive: root.activeColumnIndex === 2
                rootView: root
              }

              // Column 4: Done
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "Done"
                columnStatus: "done"
                columnType: "Todo"
                badgeColor: "#10b981"
                columnIndex: 3
                isActive: root.activeColumnIndex === 3
                rootView: root
              }

              // Column 5: Cancelled
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "Cancelled"
                columnStatus: "cancelled"
                columnType: "Todo"
                badgeColor: "#94a3b8"
                columnIndex: 4
                isActive: root.activeColumnIndex === 4
                rootView: root
              }
            }

            // Bottom: Active Task Preview & Shortcut Bar
            Rectangle {
              width: parent.width
              height: Style.space(110)
              radius: root.cornerRadius
              color: Util.alpha(Color.menu.background, 0.7)
              border.color: Util.alpha(Color.menu.border, 0.3)
              border.width: Style.normalBorderWidth

              property var activeTask: root.getSelectedTask()

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                // Task details if selected
                Row {
                  width: parent.width
                  spacing: Style.space(10)
                  visible: Boolean(parent.parent.activeTask)

                  // Status Badge
                  Rectangle {
                    height: Style.space(22)
                    width: taskStatusText.implicitWidth + Style.space(14)
                    radius: Style.space(4)
                    color: {
                      var st = parent.parent.parent.activeTask ? parent.parent.parent.activeTask.status : ""
                      if (st === "todo") return Util.alpha("#38bdf8", 0.2)
                      if (st === "working") return Util.alpha("#f59e0b", 0.2)
                      if (st === "waiting") return Util.alpha("#a855f7", 0.2)
                      if (st === "done") return Util.alpha("#10b981", 0.2)
                      if (st === "cancelled") return Util.alpha("#94a3b8", 0.2)
                      return Util.alpha(Color.accent, 0.2)
                    }
                    border.color: {
                      var st = parent.parent.parent.activeTask ? parent.parent.parent.activeTask.status : ""
                      if (st === "todo") return "#38bdf8"
                      if (st === "working") return "#f59e0b"
                      if (st === "waiting") return "#a855f7"
                      if (st === "done") return "#10b981"
                      if (st === "cancelled") return "#94a3b8"
                      return Color.accent
                    }
                    border.width: 1

                    Text {
                      id: taskStatusText
                      anchors.centerIn: parent
                      text: {
                        var st = parent.parent.parent.parent.activeTask ? parent.parent.parent.parent.activeTask.status : ""
                        if (st === "todo") return "○ TODO"
                        if (st === "working") return "◐ WORKING"
                        if (st === "waiting") return "⏳ WAITING"
                        if (st === "done") return "✓ DONE"
                        if (st === "cancelled") return "✗ CANCELLED"
                        return st.toUpperCase()
                      }
                      color: {
                        var st = parent.parent.parent.parent.activeTask ? parent.parent.parent.parent.activeTask.status : ""
                        if (st === "todo") return "#38bdf8"
                        if (st === "working") return "#f59e0b"
                        if (st === "waiting") return "#a855f7"
                        if (st === "done") return "#10b981"
                        if (st === "cancelled") return "#94a3b8"
                        return Color.accent
                      }
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // Priority
                  Rectangle {
                    visible: parent.parent.parent.activeTask && parent.parent.parent.activeTask.priority === "high"
                    height: Style.space(22)
                    width: Style.space(68)
                    radius: Style.space(4)
                    color: Util.alpha(Color.urgent, 0.2)
                    border.color: Color.urgent
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "! Urgent"
                      color: Color.urgent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // Title preview
                  Text {
                    text: parent.parent.parent.activeTask ? parent.parent.parent.activeTask.title : ""
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - Style.space(240)
                  }
                }

                // Empty / Placeholder text if no task selected
                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  visible: !parent.parent.activeTask

                  Text {
                    text: "󰄲 SPAI Kanban Navigator"
                    color: Color.accent
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                  }
                }

                // Divider line
                Rectangle {
                  width: parent.width
                  height: 1
                  color: Util.alpha(Color.menu.border, 0.18)
                }

                // Keyboard Shortcuts Bar
                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  // Space: Cycle status loop
                  Rectangle {
                    height: Style.space(22)
                    width: s1Text.implicitWidth + Style.space(12)
                    radius: Style.space(4)
                    color: Util.alpha(Color.accent, 0.15)
                    border.color: Util.alpha(Color.accent, 0.3)
                    border.width: 1

                    Text {
                      id: s1Text
                      anchors.centerIn: parent
                      text: "Space Cycle Status"
                      color: Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // Arrow keys
                  Rectangle {
                    height: Style.space(22)
                    width: s2Text.implicitWidth + Style.space(12)
                    radius: Style.space(4)
                    color: Util.alpha(root.foreground, 0.08)

                    Text {
                      id: s2Text
                      anchors.centerIn: parent
                      text: "←/→ Column   ↑/↓ Select"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // 1-5 Instant Column
                  Rectangle {
                    height: Style.space(22)
                    width: s3Text.implicitWidth + Style.space(12)
                    radius: Style.space(4)
                    color: Util.alpha(root.foreground, 0.08)

                    Text {
                      id: s3Text
                      anchors.centerIn: parent
                      text: "1..5 Set Status"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // X Toggle Done
                  Rectangle {
                    height: Style.space(22)
                    width: s4Text.implicitWidth + Style.space(12)
                    radius: Style.space(4)
                    color: Util.alpha(root.foreground, 0.08)

                    Text {
                      id: s4Text
                      anchors.centerIn: parent
                      text: "X Toggle Done"
                      color: root.foreground
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // Del Delete
                  Rectangle {
                    height: Style.space(22)
                    width: s5Text.implicitWidth + Style.space(12)
                    radius: Style.space(4)
                    color: Util.alpha(Color.urgent, 0.1)

                    Text {
                      id: s5Text
                      anchors.centerIn: parent
                      text: "Del Remove"
                      color: Color.urgent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }
                }
              }
            }
          }
        }

        // --- Body: NOTES TAB ---
        Item {
          visible: root.viewMode === "notes"
          width: parent.width
          height: parent.height - Style.space(50)

          ListView {
            anchors.fill: parent
            clip: true
            spacing: Style.space(10)
            boundsBehavior: Flickable.StopAtBounds
            model: root.getFilteredList("Note", "note")

            delegate: Rectangle {
              width: ListView.view.width
              height: noteCol.implicitHeight + Style.space(24)
              radius: root.cornerRadius
              color: Util.alpha(root.foreground, 0.04)
              border.color: Util.alpha(root.border, 0.2)
              border.width: Style.normalBorderWidth

              Column {
                id: noteCol
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(8)

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: "- " + modelData.title
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    width: parent.width - Style.space(50)
                    wrapMode: Text.Wrap
                  }

                  Text {
                    text: "✕"
                    color: Color.muted
                    font.pixelSize: Style.font.body
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.deleteItem(modelData.id)
                    }
                  }
                }

                Row {
                  spacing: Style.space(6)
                  visible: modelData.tags && modelData.tags.length > 0

                  Repeater {
                    model: modelData.tags
                    Rectangle {
                      height: Style.space(20)
                      width: tagNoteText.implicitWidth + Style.space(10)
                      radius: Style.space(4)
                      color: Util.alpha(Color.accent, 0.15)

                      Text {
                        id: tagNoteText
                        anchors.centerIn: parent
                        text: ":" + modelData + ":"
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }
              }
            }

            // Empty state for Notes
            Item {
              anchors.fill: parent
              visible: root.getFilteredList("Note", "note").length === 0

              Column {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "󰎞"
                  color: Color.muted
                  font.pixelSize: Style.font.displayLarge
                  opacity: 0.5
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "No notes yet · Press N and type '- Your note'"
                  color: Color.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                }
              }
            }
          }
        }

        // --- Body: IDEAS TAB ---
        Item {
          visible: root.viewMode === "ideas"
          width: parent.width
          height: parent.height - Style.space(50)

          ListView {
            anchors.fill: parent
            clip: true
            spacing: Style.space(10)
            boundsBehavior: Flickable.StopAtBounds
            model: root.getFilteredList("Idea", "idea")

            delegate: Rectangle {
              width: ListView.view.width
              height: ideaCol.implicitHeight + Style.space(24)
              radius: root.cornerRadius
              color: Util.alpha(root.foreground, 0.04)
              border.color: Util.alpha(root.border, 0.2)
              border.width: Style.normalBorderWidth

              Column {
                id: ideaCol
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(8)

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: "? " + modelData.title
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    width: parent.width - Style.space(150)
                    wrapMode: Text.Wrap
                  }

                  // Convert to task button
                  Rectangle {
                    height: Style.space(26)
                    width: convText.implicitWidth + Style.space(14)
                    radius: Style.space(4)
                    color: Util.alpha(Color.accent, 0.2)
                    border.color: Util.alpha(Color.accent, 0.4)
                    border.width: 1

                    Text {
                      id: convText
                      anchors.centerIn: parent
                      text: "→ Convert to Task"
                      color: Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.updateStatus(modelData.id, "todo")
                    }
                  }

                  Text {
                    text: "✕"
                    color: Color.muted
                    font.pixelSize: Style.font.body
                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.deleteItem(modelData.id)
                    }
                  }
                }

                Row {
                  spacing: Style.space(6)
                  visible: modelData.tags && modelData.tags.length > 0

                  Repeater {
                    model: modelData.tags
                    Rectangle {
                      height: Style.space(20)
                      width: tagIdeaText.implicitWidth + Style.space(10)
                      radius: Style.space(4)
                      color: Util.alpha("#ec4899", 0.15)

                      Text {
                        id: tagIdeaText
                        anchors.centerIn: parent
                        text: ":" + modelData + ":"
                        color: "#ec4899"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }
              }
            }

            // Empty state for Ideas
            Item {
              anchors.fill: parent
              visible: root.getFilteredList("Idea", "idea").length === 0

              Column {
                anchors.centerIn: parent
                spacing: Style.space(8)

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "󰌵"
                  color: Color.muted
                  font.pixelSize: Style.font.displayLarge
                  opacity: 0.5
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "No ideas recorded · Press N and type '? Your idea'"
                  color: Color.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.subtitle
                }
              }
            }
          }
        }
      }
    }
  }
}
