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
  property string focusArea: "board" // "tabs", "board"
  property string filterText: ""
  property int activeColumnIndex: 0  // 0: todo, 1: working, 2: waiting, 3: done, 4: cancelled
  property int selectedCardIndex: 0

  property var allItems: []
  property var deletedUndoStack: []
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
  property int captureWidth: Math.min(Style.space(660), panel.width - Style.gapsOut * 2)
  property alias captureInputText: captureInput.text

  function open(payloadJson) {
    ensureDataDir()
    root.opened = true
    root.filterText = ""
    root.focusArea = "board"
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

    if (targetStatus === "note") {
      root.viewMode = "notes"
      var notes = root.getFilteredList("Note", "note")
      var nIdx = 0
      for (var ni = 0; ni < notes.length; ni++) {
        if (notes[ni].id === id) { nIdx = ni; break; }
      }
      root.focusArea = "board"
      root.selectedCardIndex = nIdx
      return
    }

    if (targetStatus === "idea") {
      root.viewMode = "ideas"
      var ideas = root.getFilteredList("Idea", "idea")
      var iIdx = 0
      for (var ii = 0; ii < ideas.length; ii++) {
        if (ideas[ii].id === id) { iIdx = ii; break; }
      }
      root.focusArea = "board"
      root.selectedCardIndex = iIdx
      return
    }

    root.viewMode = "kanban"
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
      root.focusArea = "board"
      root.selectedCardIndex = newIdx
    }
  }

  function getCurrentItem() {
    if (root.viewMode === "kanban") {
      return root.getSelectedTask()
    } else if (root.viewMode === "notes") {
      var nList = root.getFilteredList("Note", "note")
      return nList[root.selectedCardIndex] || nList[0] || null
    } else if (root.viewMode === "ideas") {
      var iList = root.getFilteredList("Idea", "idea")
      return iList[root.selectedCardIndex] || iList[0] || null
    }
    return null
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
    var found = null
    for (var i = 0; i < root.allItems.length; i++) {
      if (root.allItems[i].id === id) {
        found = root.allItems[i]
        break
      }
    }
    if (found) {
      root.deletedUndoStack.push({ item: found, viewMode: root.viewMode, status: found.status })
    }
    root.allItems = SpaiModel.removeItem(root.allItems, id)
    root.saveData()
  }

  function undoLastDelete() {
    if (root.deletedUndoStack.length === 0) return
    var last = root.deletedUndoStack.pop()
    if (last && last.item) {
      root.allItems = SpaiModel.addItem(root.allItems, last.item)
      root.saveData()
      if (last.item.type === "Note") {
        root.viewMode = "notes"
      } else if (last.item.type === "Idea") {
        root.viewMode = "ideas"
      } else {
        root.viewMode = "kanban"
        var statuses = ["todo", "working", "waiting", "done", "cancelled"]
        var sIdx = statuses.indexOf(last.item.status)
        if (sIdx !== -1) root.activeColumnIndex = sIdx
      }
      root.focusArea = "board"
      root.selectedCardIndex = 0
    }
  }

  function getFilteredList(typeFilter, statusFilter) {
    return SpaiModel.filterItems(root.allItems, root.filterText, typeFilter, statusFilter)
  }

  function getActiveColumnTasks() {
    var statuses = ["todo", "working", "waiting", "done", "cancelled"]
    var st = statuses[root.activeColumnIndex] || "todo"
    return root.getFilteredList("Todo", st)
  }

  function getActiveViewList() {
    if (root.viewMode === "notes") {
      return root.getFilteredList("Note", "note")
    } else if (root.viewMode === "ideas") {
      return root.getFilteredList("Idea", "idea")
    }
    return root.getActiveColumnTasks()
  }

  function getSelectedTask() {
    if (root.focusArea !== "board") return null
    var list = root.getActiveColumnTasks()
    if (list.length === 0) return null
    var idx = Math.max(0, Math.min(root.selectedCardIndex, list.length - 1))
    return list[idx] || null
  }

  function clampSelection() {
    var list = root.getActiveViewList()
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
    // 1. QUICK CAPTURE MODAL (Spotlight / Raycast Style)
    // ==========================================
    BorderSurface {
      id: captureModal
      visible: root.viewMode === "capture"
      width: root.captureWidth
      height: captureCol.implicitHeight + Style.space(36)
      radius: root.cornerRadius + Style.space(6)
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
        Item {
          width: parent.width
          height: Style.space(32)

          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

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
              color: "#f8fafc"
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Keycap Hints on Right
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(6)

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
                color: "#94a3b8"
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
          border.color: {
            if (captureModal.detected) {
              var st = captureModal.detected.status
              if (st === "todo") return "#f94dff"
              if (st === "working") return "#f1fc79"
              if (st === "waiting") return "#987afb"
              if (st === "done") return "#37f499"
              if (st === "cancelled") return "#5f6b8a"
              if (st === "idea") return "#ec4899"
              return "#04d1f9"
            }
            return captureInput.activeFocus ? Color.accent : Util.alpha(root.border, 0.3)
          }
          border.width: captureInput.activeFocus || captureModal.detected ? Style.space(2) : Style.normalBorderWidth

          Row {
            anchors.fill: parent
            anchors.leftMargin: Style.space(12)
            anchors.rightMargin: Style.space(12)
            spacing: Style.space(8)

            TextInput {
              id: captureInput
              width: parent.width
              height: parent.height
              color: "#ffffff"
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              verticalAlignment: TextInput.AlignVCenter
              clip: true

              onTextEdited: {
                var t = captureInput.text
                if (t === "." || t === "?" || t === "-" || t === "x" || t === "X" || t === "z" || t === "Z") {
                  captureInput.text = t + " "
                  captureInput.cursorPosition = 2
                } else if (t === "/." || t === "/. ") {
                  captureInput.text = "/. "
                  captureInput.cursorPosition = 3
                } else if (t.length === 2 && t.indexOf("/") === 0 && t.charAt(1) !== "." && t.charAt(1) !== " ") {
                  captureInput.text = "/ " + t.slice(1)
                  captureInput.cursorPosition = 3
                }
              }

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
                text: "Type . todo, / work, /. wait, ? idea, - note, ! urgent, @date, :tag:..."
                color: "#64748b"
                opacity: 0.8
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
              color: "#94a3b8"
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
                if (st === "todo") return Util.alpha("#f94dff", 0.2)
                if (st === "working") return Util.alpha("#f1fc79", 0.2)
                if (st === "waiting") return Util.alpha("#987afb", 0.2)
                if (st === "done") return Util.alpha("#37f499", 0.2)
                if (st === "cancelled") return Util.alpha("#5f6b8a", 0.2)
                if (st === "idea") return Util.alpha("#ec4899", 0.2)
                return Util.alpha("#04d1f9", 0.2)
              }
              border.color: {
                if (!captureModal.detected) return "transparent"
                var st = captureModal.detected.status
                if (st === "todo") return "#f94dff"
                if (st === "working") return "#f1fc79"
                if (st === "waiting") return "#987afb"
                if (st === "done") return "#37f499"
                if (st === "cancelled") return "#5f6b8a"
                if (st === "idea") return "#ec4899"
                return "#04d1f9"
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
                  if (!captureModal.detected) return "#ffffff"
                  var st = captureModal.detected.status
                  if (st === "todo") return "#f94dff"
                  if (st === "working") return "#f1fc79"
                  if (st === "waiting") return "#987afb"
                  if (st === "done") return "#37f499"
                  if (st === "cancelled") return "#5f6b8a"
                  if (st === "idea") return "#ec4899"
                  return "#04d1f9"
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
              color: Util.alpha("#f16c75", 0.2)
              border.color: "#f16c75"
              border.width: 1
              anchors.verticalCenter: parent.verticalCenter

              Text {
                anchors.centerIn: parent
                text: "! Urgent"
                color: "#f16c75"
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
              color: Util.alpha("#04d1f9", 0.15)
              border.color: Util.alpha("#04d1f9", 0.35)
              border.width: 1
              anchors.verticalCenter: parent.verticalCenter

              Row {
                anchors.centerIn: parent
                spacing: Style.space(3)
                Text { text: "󰃰"; color: "#04d1f9"; font.pixelSize: Style.font.caption }
                Text {
                  id: detDeadText
                  text: captureModal.detected ? captureModal.detected.deadline : ""
                  color: "#04d1f9"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }

            // Clean Title preview
            Text {
              text: captureModal.detected ? captureModal.detected.title : ""
              color: "#ffffff"
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              font.bold: true
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
              color: "#94a3b8"
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
              color: isCurrent ? Util.alpha("#f94dff", 0.35) : Util.alpha("#f94dff", 0.12)
              border.color: isCurrent ? "#f94dff" : Util.alpha("#f94dff", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p1Text
                anchors.centerIn: parent
                text: ". Todo"
                color: "#f94dff"
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
              color: isCurrent ? Util.alpha("#f1fc79", 0.35) : Util.alpha("#f1fc79", 0.12)
              border.color: isCurrent ? "#f1fc79" : Util.alpha("#f1fc79", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p2Text
                anchors.centerIn: parent
                text: "/ Work"
                color: "#f1fc79"
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
              color: isCurrent ? Util.alpha("#987afb", 0.35) : Util.alpha("#987afb", 0.12)
              border.color: isCurrent ? "#987afb" : Util.alpha("#987afb", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p3Text
                anchors.centerIn: parent
                text: "/. Wait"
                color: "#987afb"
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
              color: isCurrent ? Util.alpha("#37f499", 0.35) : Util.alpha("#37f499", 0.12)
              border.color: isCurrent ? "#37f499" : Util.alpha("#37f499", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: pxText
                anchors.centerIn: parent
                text: "x Done"
                color: "#37f499"
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
              color: isCurrent ? Util.alpha("#5f6b8a", 0.35) : Util.alpha("#5f6b8a", 0.12)
              border.color: isCurrent ? "#5f6b8a" : Util.alpha("#5f6b8a", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p6Text
                anchors.centerIn: parent
                text: "z Cancel"
                color: "#5f6b8a"
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
              color: isCurrent ? Util.alpha("#04d1f9", 0.3) : Util.alpha("#04d1f9", 0.1)
              border.color: isCurrent ? "#04d1f9" : Util.alpha("#04d1f9", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: p5Text
                anchors.centerIn: parent
                text: "- Note"
                color: "#04d1f9"
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
              color: "#94a3b8"
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
              color: isCurrent ? Util.alpha("#f16c75", 0.35) : Util.alpha("#f16c75", 0.12)
              border.color: isCurrent ? "#f16c75" : Util.alpha("#f16c75", 0.3)
              border.width: isCurrent ? 2 : 1

              Text {
                id: m1Text
                anchors.centerIn: parent
                text: "! Urgent"
                color: "#f16c75"
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
                color: parent.isCurrent ? Color.accent : "#cbd5e1"
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
        Item {
          width: parent.width
          height: Style.space(34)

          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(10)

            // Cancel Button
            Rectangle {
              height: Style.space(32)
              width: Style.space(90)
              radius: root.cornerRadius
              color: Util.alpha(root.foreground, 0.08)

              Text {
                anchors.centerIn: parent
                text: "Cancel"
                color: "#e2e8f0"
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
    }

    // ==========================================
    // 2. KANBAN / NOTES / IDEAS MAIN MODAL
    // ==========================================
    BorderSurface {
      id: mainModal
      visible: root.viewMode !== "capture"
      width: root.modalWidth
      height: root.modalHeight
      radius: root.cornerRadius + Style.space(6)
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
          }
          // ==========================================
          // ARROW NAVIGATION: TABS LEVEL (when focusArea === "tabs")
          // ==========================================
          else if (root.focusArea === "tabs") {
            if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
              var tabModes = ["kanban", "notes", "ideas"]
              var curIdx = tabModes.indexOf(root.viewMode)
              if (curIdx === -1) curIdx = 0
              var nextIdx = (curIdx - 1 + tabModes.length) % tabModes.length
              root.viewMode = tabModes[nextIdx]
              event.accepted = true
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
              var tabModesR = ["kanban", "notes", "ideas"]
              var curIdxR = tabModesR.indexOf(root.viewMode)
              if (curIdxR === -1) curIdxR = 0
              var nextIdxR = (curIdxR + 1) % tabModesR.length
              root.viewMode = tabModesR[nextIdxR]
              event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
              root.focusArea = "board"
              root.selectedCardIndex = 0
              root.clampSelection()
              event.accepted = true
            }
          }
          // ==========================================
          // ARROW NAVIGATION: BOARD LEVEL (when focusArea === "board")
          // ==========================================
          else if (root.focusArea === "board") {
            if (event.key === Qt.Key_Up || event.key === Qt.Key_K) {
              if (root.viewMode === "kanban") {
                if (root.selectedCardIndex > 0) {
                  root.selectedCardIndex--
                } else {
                  // At the top card or empty column -> switch to Tabs navigation!
                  root.focusArea = "tabs"
                  root.selectedCardIndex = -1
                }
              } else if (root.viewMode === "notes" || root.viewMode === "ideas") {
                if (root.selectedCardIndex > 0) {
                  root.selectedCardIndex--
                } else {
                  root.focusArea = "tabs"
                  root.selectedCardIndex = -1
                }
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Down || event.key === Qt.Key_J) {
              if (root.viewMode === "kanban") {
                var tasks = root.getActiveColumnTasks()
                if (root.selectedCardIndex < tasks.length - 1) {
                  root.selectedCardIndex++
                }
              } else if (root.viewMode === "notes" || root.viewMode === "ideas") {
                var lTypeD = root.viewMode === "notes" ? "Note" : "Idea"
                var lStD = root.viewMode === "notes" ? "note" : "idea"
                var listD = root.getFilteredList(lTypeD, lStD)
                if (root.selectedCardIndex < listD.length - 1) {
                  root.selectedCardIndex++
                }
              }
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
              } else if (root.viewMode === "notes" || root.viewMode === "ideas") {
                var lTypeSp = root.viewMode === "notes" ? "Note" : "Idea"
                var lStSp = root.viewMode === "notes" ? "note" : "idea"
                var listSp = root.getFilteredList(lTypeSp, lStSp)
                var itSp = listSp[root.selectedCardIndex] || listSp[0]
                if (itSp) {
                  root.updateStatusAndFollow(itSp.id, "todo")
                  root.viewMode = "kanban"
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
              } else if (root.viewMode === "notes" || root.viewMode === "ideas") {
                var lTypeX = root.viewMode === "notes" ? "Note" : "Idea"
                var lStX = root.viewMode === "notes" ? "note" : "idea"
                var listX = root.getFilteredList(lTypeX, lStX)
                var itX = listX[root.selectedCardIndex] || listX[0]
                if (itX) {
                  root.updateStatusAndFollow(itX.id, "done")
                  root.viewMode = "kanban"
                }
              }
              event.accepted = true
            } else if (event.key === Qt.Key_Z || event.key === Qt.Key_C) {
              if (root.viewMode === "kanban") {
                var curTaskZ = root.getSelectedTask()
                if (curTaskZ) {
                  root.updateStatusAndFollow(curTaskZ.id, "cancelled")
                }
              } else if (root.viewMode === "notes" || root.viewMode === "ideas") {
                var lTypeZ = root.viewMode === "notes" ? "Note" : "Idea"
                var lStZ = root.viewMode === "notes" ? "note" : "idea"
                var listZ = root.getFilteredList(lTypeZ, lStZ)
                var itZ = listZ[root.selectedCardIndex] || listZ[0]
                if (itZ) {
                  root.updateStatusAndFollow(itZ.id, "cancelled")
                  root.viewMode = "kanban"
                }
              }
              event.accepted = true
            } else if (event.key === Qt.Key_U || (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier))) {
              root.undoLastDelete()
              event.accepted = true
            } else if (event.key === Qt.Key_Delete || event.key === Qt.Key_Backspace) {
              if (root.viewMode === "kanban") {
                var curTaskDel = root.getSelectedTask()
                if (curTaskDel) {
                  root.deleteItem(curTaskDel.id)
                }
              } else if (root.viewMode === "notes" || root.viewMode === "ideas") {
                var lTypeDel = root.viewMode === "notes" ? "Note" : "Idea"
                var lStDel = root.viewMode === "notes" ? "note" : "idea"
                var listDel = root.getFilteredList(lTypeDel, lStDel)
                if (root.selectedCardIndex >= 0 && root.selectedCardIndex < listDel.length) {
                  root.deleteItem(listDel[root.selectedCardIndex].id)
                }
              }
              event.accepted = true
            } else if (event.key === Qt.Key_1 || event.text === "1" || event.text === "." || event.key === Qt.Key_Plus || event.key === Qt.Key_T || event.text === "t" || event.text === "T") {
              var it1 = root.getCurrentItem()
              if (it1) {
                root.updateStatusAndFollow(it1.id, "todo")
              } else if (root.viewMode === "kanban") {
                root.activeColumnIndex = 0
              }
              event.accepted = true
            } else if (event.key === Qt.Key_2 || event.text === "2" || event.text === "/" || event.key === Qt.Key_Slash || event.key === Qt.Key_Eacute || event.key === Qt.Key_W || event.text === "w" || event.text === "W") {
              var it2 = root.getCurrentItem()
              if (it2) {
                root.updateStatusAndFollow(it2.id, "working")
              } else if (root.viewMode === "kanban") {
                root.activeColumnIndex = 1
              }
              event.accepted = true
            } else if (event.key === Qt.Key_3 || event.text === "3" || event.key === Qt.Key_Scaron || event.key === Qt.Key_P || event.text === "p" || event.text === "P") {
              var it3 = root.getCurrentItem()
              if (it3) {
                root.updateStatusAndFollow(it3.id, "waiting")
              } else if (root.viewMode === "kanban") {
                root.activeColumnIndex = 2
              }
              event.accepted = true
            } else if (event.key === Qt.Key_4 || event.text === "4" || event.text === "x" || event.text === "X" || event.key === Qt.Key_Ccaron || event.key === Qt.Key_D || event.text === "d" || event.text === "D" || event.key === Qt.Key_X) {
              var it4 = root.getCurrentItem()
              if (it4) {
                var nextSt4 = (it4.status === "done" && root.viewMode === "kanban") ? "todo" : "done"
                root.updateStatusAndFollow(it4.id, nextSt4)
              } else if (root.viewMode === "kanban") {
                root.activeColumnIndex = 3
              }
              event.accepted = true
            } else if (event.key === Qt.Key_5 || event.text === "5" || event.text === "z" || event.text === "Z" || event.key === Qt.Key_Rcaron || event.key === Qt.Key_C || event.text === "c" || event.text === "C" || event.key === Qt.Key_Z) {
              var it5 = root.getCurrentItem()
              if (it5) {
                root.updateStatusAndFollow(it5.id, "cancelled")
              } else if (root.viewMode === "kanban") {
                root.activeColumnIndex = 4
              }
              event.accepted = true
            } else if (event.key === Qt.Key_6 || event.text === "6" || event.text === "-" || event.key === Qt.Key_Minus || event.key === Qt.Key_Zcaron) {
              var it6 = root.getCurrentItem()
              if (it6 && root.viewMode !== "notes") {
                root.updateStatusAndFollow(it6.id, "note")
              } else {
                root.viewMode = "notes"
              }
              event.accepted = true
            } else if (event.key === Qt.Key_7 || event.text === "7" || event.text === "?" || event.key === Qt.Key_Question || event.key === Qt.Key_Yacute) {
              var it7 = root.getCurrentItem()
              if (it7 && root.viewMode !== "ideas") {
                root.updateStatusAndFollow(it7.id, "idea")
              } else {
                root.viewMode = "ideas"
              }
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
      }

      Column {
        anchors.fill: parent
        anchors.margins: Style.space(16)
        spacing: Style.space(12)

        // --- Header Bar ---
        Item {
          width: parent.width
          height: Style.space(38)

          // Left: Brand
          Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            Rectangle {
              width: Style.space(32)
              height: Style.space(32)
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
              color: "#ffffff"
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // Center: Segmented Navigation Tabs (with active focus border)
          Row {
            anchors.centerIn: parent
            spacing: Style.space(4)

            // Kanban Tab
            Rectangle {
              height: Style.space(32)
              width: tabKanbanText.implicitWidth + Style.space(22)
              radius: root.cornerRadius
              color: root.viewMode === "kanban" ? root.selectedBackground : Util.alpha(root.foreground, 0.05)
              border.color: root.viewMode === "kanban"
                ? (root.focusArea === "tabs" ? "#f94dff" : Color.accent)
                : (root.focusArea === "tabs" ? Util.alpha(root.foreground, 0.2) : "transparent")
              border.width: root.viewMode === "kanban" && root.focusArea === "tabs" ? 2 : 1

              Text {
                id: tabKanbanText
                anchors.centerIn: parent
                text: "[1-5] ○ Kanban (" + root.stats.pendingTotal + ")"
                color: root.viewMode === "kanban" ? (root.focusArea === "tabs" ? "#f94dff" : "#ffffff") : "#94a3b8"
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: root.viewMode === "kanban"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.viewMode = "kanban"; root.focusArea = "board"; keyCatcher.forceActiveFocus() }
              }
            }

            // Notes Tab
            Rectangle {
              height: Style.space(32)
              width: tabNotesText.implicitWidth + Style.space(22)
              radius: root.cornerRadius
              color: root.viewMode === "notes" ? root.selectedBackground : Util.alpha(root.foreground, 0.05)
              border.color: root.viewMode === "notes"
                ? (root.focusArea === "tabs" ? "#04d1f9" : Color.accent)
                : (root.focusArea === "tabs" ? Util.alpha(root.foreground, 0.2) : "transparent")
              border.width: root.viewMode === "notes" && root.focusArea === "tabs" ? 2 : 1

              Text {
                id: tabNotesText
                anchors.centerIn: parent
                text: "[6] - Notes (" + root.stats.notes + ")"
                color: root.viewMode === "notes" ? (root.focusArea === "tabs" ? "#04d1f9" : "#ffffff") : "#94a3b8"
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: root.viewMode === "notes"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.viewMode = "notes"; root.focusArea = "board"; keyCatcher.forceActiveFocus() }
              }
            }

            // Ideas Tab
            Rectangle {
              height: Style.space(32)
              width: tabIdeasText.implicitWidth + Style.space(22)
              radius: root.cornerRadius
              color: root.viewMode === "ideas" ? root.selectedBackground : Util.alpha(root.foreground, 0.05)
              border.color: root.viewMode === "ideas"
                ? (root.focusArea === "tabs" ? "#ec4899" : Color.accent)
                : (root.focusArea === "tabs" ? Util.alpha(root.foreground, 0.2) : "transparent")
              border.width: root.viewMode === "ideas" && root.focusArea === "tabs" ? 2 : 1

              Text {
                id: tabIdeasText
                anchors.centerIn: parent
                text: "[7] ? Ideas (" + root.stats.ideas + ")"
                color: root.viewMode === "ideas" ? (root.focusArea === "tabs" ? "#ec4899" : "#ffffff") : "#94a3b8"
                font.family: root.fontFamily
                font.pixelSize: Style.font.subtitle
                font.bold: root.viewMode === "ideas"
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: { root.viewMode = "ideas"; root.focusArea = "board"; keyCatcher.forceActiveFocus() }
              }
            }
          }

          // Right: Search & Actions
          Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(8)

            // Search Field
            Rectangle {
              width: Style.space(200)
              height: Style.space(32)
              radius: root.cornerRadius
              color: Util.alpha(root.foreground, 0.06)
              border.color: searchInput.activeFocus ? Color.accent : Util.alpha(root.border, 0.25)
              border.width: Style.normalBorderWidth

              Row {
                anchors.fill: parent
                anchors.leftMargin: Style.space(8)
                anchors.rightMargin: Style.space(8)
                spacing: Style.space(6)

                Text {
                  text: "󰍉"
                  color: "#94a3b8"
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.verticalCenter: parent.verticalCenter
                }

                TextInput {
                  id: searchInput
                  width: parent.width - Style.space(40)
                  color: "#ffffff"
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
                    color: "#64748b"
                    opacity: 0.8
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
                  color: "#94a3b8"
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

              Text {
                anchors.centerIn: parent
                text: "✕"
                color: "#e2e8f0"
                font.pixelSize: Style.font.body
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: root.close()
              }
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
              height: parent.height - Style.space(105)
              spacing: Style.space(12)

              // Column 1: Todo
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "Todo"
                columnGlyph: "○"
                columnStatus: "todo"
                columnType: "Todo"
                badgeColor: "#f94dff"
                columnIndex: 0
                isActive: root.focusArea === "board" && root.activeColumnIndex === 0
                rootView: root
              }

              // Column 2: In Progress
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "In Progress"
                columnGlyph: "◐"
                columnStatus: "working"
                columnType: "Todo"
                badgeColor: "#f1fc79"
                columnIndex: 1
                isActive: root.focusArea === "board" && root.activeColumnIndex === 1
                rootView: root
              }

              // Column 3: Waiting
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "Waiting"
                columnGlyph: "⏳"
                columnStatus: "waiting"
                columnType: "Todo"
                badgeColor: "#987afb"
                columnIndex: 2
                isActive: root.focusArea === "board" && root.activeColumnIndex === 2
                rootView: root
              }

              // Column 4: Done
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "Done"
                columnGlyph: "✓"
                columnStatus: "done"
                columnType: "Todo"
                badgeColor: "#37f499"
                columnIndex: 3
                isActive: root.focusArea === "board" && root.activeColumnIndex === 3
                rootView: root
              }

              // Column 5: Cancelled
              KanbanColumn {
                width: (parent.width - Style.space(48)) / 5
                height: parent.height
                title: "Cancelled"
                columnGlyph: "✗"
                columnStatus: "cancelled"
                columnType: "Todo"
                badgeColor: "#5f6b8a"
                columnIndex: 4
                isActive: root.focusArea === "board" && root.activeColumnIndex === 4
                rootView: root
              }
            }

            // Bottom: Active Task Preview & Shortcut Bar HUD
            Rectangle {
              width: parent.width
              height: Style.space(95)
              radius: root.cornerRadius
              color: Util.alpha(Color.menu.background, 0.7)
              border.color: root.focusArea === "tabs"
                ? Util.alpha(Color.accent, 0.4)
                : Util.alpha(Color.menu.border, 0.3)
              border.width: Style.normalBorderWidth

              property var activeTask: root.getSelectedTask()

              Column {
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                // Task details if in board mode and task selected
                Row {
                  width: parent.width
                  spacing: Style.space(10)
                  visible: root.focusArea === "board" && Boolean(parent.parent.activeTask)

                  // Status Badge
                  Rectangle {
                    height: Style.space(22)
                    width: taskStatusText.implicitWidth + Style.space(14)
                    radius: Style.space(4)
                    color: {
                      var st = parent.parent.parent.activeTask ? parent.parent.parent.activeTask.status : ""
                      if (st === "todo") return Util.alpha("#f94dff", 0.2)
                      if (st === "working") return Util.alpha("#f1fc79", 0.2)
                      if (st === "waiting") return Util.alpha("#987afb", 0.2)
                      if (st === "done") return Util.alpha("#37f499", 0.2)
                      if (st === "cancelled") return Util.alpha("#5f6b8a", 0.2)
                      return Util.alpha(Color.accent, 0.2)
                    }
                    border.color: {
                      var st = parent.parent.parent.activeTask ? parent.parent.parent.activeTask.status : ""
                      if (st === "todo") return "#f94dff"
                      if (st === "working") return "#f1fc79"
                      if (st === "waiting") return "#987afb"
                      if (st === "done") return "#37f499"
                      if (st === "cancelled") return "#5f6b8a"
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
                        if (st === "todo") return "#f94dff"
                        if (st === "working") return "#f1fc79"
                        if (st === "waiting") return "#987afb"
                        if (st === "done") return "#37f499"
                        if (st === "cancelled") return "#5f6b8a"
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
                    color: Util.alpha("#f16c75", 0.2)
                    border.color: "#f16c75"
                    border.width: 1

                    Text {
                      anchors.centerIn: parent
                      text: "! Urgent"
                      color: "#f16c75"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // Title preview
                  Text {
                    text: parent.parent.parent.activeTask ? parent.parent.parent.activeTask.title : ""
                    color: "#ffffff"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - Style.space(240)
                  }
                }

                // Header if in Tabs Navigation mode
                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  visible: root.focusArea === "tabs"

                  Text {
                    text: "󰄲 Tab Navigator Mode"
                    color: "#04d1f9"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.title
                    font.bold: true
                  }

                  Text {
                    text: "— Press [←/→] to change Tab, press [↓] or [Enter] to jump into tasks"
                    color: "#94a3b8"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                // Placeholder if in Board mode without active task
                Row {
                  width: parent.width
                  spacing: Style.space(8)
                  visible: root.focusArea === "board" && !parent.parent.activeTask

                  Text {
                    text: "󰄲 SPAI Kanban Navigator — Select a task with ↑/↓ (or press ↑ at top to switch Tabs)"
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
                  spacing: Style.space(6)

                  // Space: Cycle status loop
                  Rectangle {
                    height: Style.space(22)
                    width: s1Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha(Color.accent, 0.15)
                    border.color: Util.alpha(Color.accent, 0.3)
                    border.width: 1

                    Text {
                      id: s1Text
                      anchors.centerIn: parent
                      text: "Space Next"
                      color: Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // 1 Todo
                  Rectangle {
                    height: Style.space(22)
                    width: k1Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#f94dff", 0.15)
                    border.color: Util.alpha("#f94dff", 0.3)
                    border.width: 1

                    Text {
                      id: k1Text
                      anchors.centerIn: parent
                      text: "[1] Todo"
                      color: "#f94dff"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // 2 Work
                  Rectangle {
                    height: Style.space(22)
                    width: k2Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#f1fc79", 0.15)
                    border.color: Util.alpha("#f1fc79", 0.3)
                    border.width: 1

                    Text {
                      id: k2Text
                      anchors.centerIn: parent
                      text: "[2] Work"
                      color: "#f1fc79"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // 3 Wait
                  Rectangle {
                    height: Style.space(22)
                    width: k3Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#987afb", 0.15)
                    border.color: Util.alpha("#987afb", 0.3)
                    border.width: 1

                    Text {
                      id: k3Text
                      anchors.centerIn: parent
                      text: "[3] Wait"
                      color: "#987afb"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // 4 Done
                  Rectangle {
                    height: Style.space(22)
                    width: k4Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#37f499", 0.15)
                    border.color: Util.alpha("#37f499", 0.3)
                    border.width: 1

                    Text {
                      id: k4Text
                      anchors.centerIn: parent
                      text: "[4] Done"
                      color: "#37f499"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // 5 Cancel
                  Rectangle {
                    height: Style.space(22)
                    width: k5Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#5f6b8a", 0.15)
                    border.color: Util.alpha("#5f6b8a", 0.3)
                    border.width: 1

                    Text {
                      id: k5Text
                      anchors.centerIn: parent
                      text: "[5] Cancel"
                      color: "#5f6b8a"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }
                  }

                  // 6 Notes
                  Rectangle {
                    height: Style.space(22)
                    width: k6Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#04d1f9", 0.12)
                    border.color: Util.alpha("#04d1f9", 0.25)
                    border.width: 1

                    Text {
                      id: k6Text
                      anchors.centerIn: parent
                      text: "[6/-] Note"
                      color: "#04d1f9"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // 7 Ideas
                  Rectangle {
                    height: Style.space(22)
                    width: k7Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#ec4899", 0.12)
                    border.color: Util.alpha("#ec4899", 0.25)
                    border.width: 1

                    Text {
                      id: k7Text
                      anchors.centerIn: parent
                      text: "[7/?] Idea"
                      color: "#ec4899"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // Arrows
                  Rectangle {
                    height: Style.space(22)
                    width: s2Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha(root.foreground, 0.08)

                    Text {
                      id: s2Text
                      anchors.centerIn: parent
                      text: "←/→ Col   ↑/↓ Card   (↑ Top=Tabs)"
                      color: "#f1f5f9"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // U Undo
                  Rectangle {
                    visible: root.deletedUndoStack.length > 0
                    height: Style.space(22)
                    width: sUText.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#f1fc79", 0.15)
                    border.color: Util.alpha("#f1fc79", 0.3)
                    border.width: 1

                    Text {
                      id: sUText
                      anchors.centerIn: parent
                      text: "[U] Undo"
                      color: "#f1fc79"
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.undoLastDelete()
                    }
                  }

                  // Del Delete
                  Rectangle {
                    height: Style.space(22)
                    width: s5Text.implicitWidth + Style.space(10)
                    radius: Style.space(4)
                    color: Util.alpha("#f16c75", 0.12)
                    border.color: Util.alpha("#f16c75", 0.25)
                    border.width: 1

                    Text {
                      id: s5Text
                      anchors.centerIn: parent
                      text: "Del Remove"
                      color: "#f16c75"
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
              readonly property bool isCurNote: root.focusArea === "board" && index === root.selectedCardIndex

              width: ListView.view.width
              height: noteCol.implicitHeight + Style.space(24)
              radius: root.cornerRadius
              color: isCurNote ? Util.alpha("#04d1f9", 0.12) : Util.alpha(root.foreground, 0.04)
              border.color: isCurNote ? "#04d1f9" : Util.alpha(root.border, 0.2)
              border.width: isCurNote ? 2 : Style.normalBorderWidth

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  root.focusArea = "board"
                  root.selectedCardIndex = index
                }
              }

              Column {
                id: noteCol
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(8)

                Item {
                  width: parent.width
                  height: Style.space(28)

                  Text {
                    anchors.left: parent.left
                    anchors.right: noteActions.left
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "- " + modelData.title
                    color: isCurNote ? "#ffffff" : "#f1f5f9"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    wrapMode: Text.Wrap
                  }

                  Row {
                    id: noteActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    // Convert to Todo (1 / Space)
                    Rectangle {
                      height: Style.space(22)
                      width: nTodoText.implicitWidth + Style.space(10)
                      radius: Style.space(4)
                      color: Util.alpha("#f94dff", 0.16)
                      border.color: Util.alpha("#f94dff", 0.35)
                      border.width: 1

                      Text {
                        id: nTodoText
                        anchors.centerIn: parent
                        text: "[1] → Todo"
                        color: "#f94dff"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.updateStatusAndFollow(modelData.id, "todo")
                        }
                      }
                    }

                    // Convert to Working (2)
                    Rectangle {
                      height: Style.space(22)
                      width: nWorkText.implicitWidth + Style.space(10)
                      radius: Style.space(4)
                      color: Util.alpha("#f1fc79", 0.16)
                      border.color: Util.alpha("#f1fc79", 0.35)
                      border.width: 1

                      Text {
                        id: nWorkText
                        anchors.centerIn: parent
                        text: "[2] → Work"
                        color: "#f1fc79"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.updateStatusAndFollow(modelData.id, "working")
                        }
                      }
                    }

                    // Convert to Idea (7 / ?)
                    Rectangle {
                      height: Style.space(22)
                      width: nIdeaText.implicitWidth + Style.space(10)
                      radius: Style.space(4)
                      color: Util.alpha("#ec4899", 0.16)
                      border.color: Util.alpha("#ec4899", 0.35)
                      border.width: 1

                      Text {
                        id: nIdeaText
                        anchors.centerIn: parent
                        text: "[7] → Idea"
                        color: "#ec4899"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.updateStatusAndFollow(modelData.id, "idea")
                        }
                      }
                    }

                    // Delete Note
                    Rectangle {
                      height: Style.space(22)
                      width: Style.space(22)
                      radius: Style.space(4)
                      color: Util.alpha("#f16c75", 0.15)
                      border.color: Util.alpha("#f16c75", 0.3)
                      border.width: 1

                      Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#f16c75"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteItem(modelData.id)
                      }
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
                      color: Util.alpha("#04d1f9", 0.15)

                      Text {
                        id: tagNoteText
                        anchors.centerIn: parent
                        text: ":" + modelData + ":"
                        color: "#04d1f9"
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
                  color: "#64748b"
                  font.pixelSize: Style.font.displayLarge
                  opacity: 0.6
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "No notes yet · Press N and type '- Your note'"
                  color: "#94a3b8"
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
              readonly property bool isCurIdea: root.focusArea === "board" && index === root.selectedCardIndex

              width: ListView.view.width
              height: ideaCol.implicitHeight + Style.space(24)
              radius: root.cornerRadius
              color: isCurIdea ? Util.alpha("#ec4899", 0.12) : Util.alpha(root.foreground, 0.04)
              border.color: isCurIdea ? "#ec4899" : Util.alpha(root.border, 0.2)
              border.width: isCurIdea ? 2 : Style.normalBorderWidth

              MouseArea {
                anchors.fill: parent
                onClicked: {
                  root.focusArea = "board"
                  root.selectedCardIndex = index
                }
              }

              Column {
                id: ideaCol
                anchors.fill: parent
                anchors.margins: Style.space(12)
                spacing: Style.space(8)

                Item {
                  width: parent.width
                  height: Style.space(28)

                  Text {
                    anchors.left: parent.left
                    anchors.right: ideaActions.left
                    anchors.rightMargin: Style.space(10)
                    anchors.verticalCenter: parent.verticalCenter
                    text: "? " + modelData.title
                    color: isCurIdea ? "#ffffff" : "#f1f5f9"
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    wrapMode: Text.Wrap
                  }

                  Row {
                    id: ideaActions
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(6)

                    // Convert to Todo (1 / Space)
                    Rectangle {
                      height: Style.space(22)
                      width: iTodoText.implicitWidth + Style.space(10)
                      radius: Style.space(4)
                      color: Util.alpha("#f94dff", 0.16)
                      border.color: Util.alpha("#f94dff", 0.35)
                      border.width: 1

                      Text {
                        id: iTodoText
                        anchors.centerIn: parent
                        text: "[1] → Todo"
                        color: "#f94dff"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.updateStatusAndFollow(modelData.id, "todo")
                        }
                      }
                    }

                    // Convert to Working (2)
                    Rectangle {
                      height: Style.space(22)
                      width: iWorkText.implicitWidth + Style.space(10)
                      radius: Style.space(4)
                      color: Util.alpha("#f1fc79", 0.16)
                      border.color: Util.alpha("#f1fc79", 0.35)
                      border.width: 1

                      Text {
                        id: iWorkText
                        anchors.centerIn: parent
                        text: "[2] → Work"
                        color: "#f1fc79"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.updateStatusAndFollow(modelData.id, "working")
                        }
                      }
                    }

                    // Convert to Note (6 / -)
                    Rectangle {
                      height: Style.space(22)
                      width: iNoteText.implicitWidth + Style.space(10)
                      radius: Style.space(4)
                      color: Util.alpha("#04d1f9", 0.16)
                      border.color: Util.alpha("#04d1f9", 0.35)
                      border.width: 1

                      Text {
                        id: iNoteText
                        anchors.centerIn: parent
                        text: "[6] → Note"
                        color: "#04d1f9"
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          root.updateStatusAndFollow(modelData.id, "note")
                        }
                      }
                    }

                    // Delete Idea
                    Rectangle {
                      height: Style.space(22)
                      width: Style.space(22)
                      radius: Style.space(4)
                      color: Util.alpha("#f16c75", 0.15)
                      border.color: Util.alpha("#f16c75", 0.3)
                      border.width: 1

                      Text {
                        anchors.centerIn: parent
                        text: "✕"
                        color: "#f16c75"
                        font.pixelSize: Style.font.caption
                        font.bold: true
                      }

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.deleteItem(modelData.id)
                      }
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
                  color: "#64748b"
                  font.pixelSize: Style.font.displayLarge
                  opacity: 0.6
                }

                Text {
                  anchors.horizontalCenter: parent.horizontalCenter
                  text: "No ideas recorded · Press N and type '? Your idea'"
                  color: "#94a3b8"
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
