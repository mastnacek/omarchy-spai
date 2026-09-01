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
  property int activeColumnIndex: 0  // 0: todo, 1: working, 2: waiting, 3: done
  property int selectedCardIndex: 0

  property var allItems: []
  property var stats: ({ total: 0, todo: 0, working: 0, waiting: 0, done: 0, notes: 0, ideas: 0, pendingTotal: 0 })

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

  property int modalWidth: Math.min(Style.space(1100), panel.width - Style.gapsOut * 2)
  property int modalHeight: Math.min(Style.space(700), panel.height - Style.gapsOut * 2)
  property int captureWidth: Math.min(Style.space(650), panel.width - Style.gapsOut * 2)
  property int captureHeight: Style.space(240)
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
  }

  function saveData() {
    dataFile.setText(SpaiModel.formatItems(root.allItems))
    root.stats = SpaiModel.getStats(root.allItems)
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

  function cycleItemStatus(id, direction) {
    root.allItems = SpaiModel.cycleStatus(root.allItems, id, direction)
    root.saveData()
  }

  function deleteItem(id) {
    root.allItems = SpaiModel.removeItem(root.allItems, id)
    root.saveData()
  }

  function getFilteredList(typeFilter, statusFilter) {
    return SpaiModel.filterItems(root.allItems, root.filterText, typeFilter, statusFilter)
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
      height: root.captureHeight
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

      MouseArea { anchors.fill: parent; onClicked: {} }

      Column {
        anchors.fill: parent
        spacing: Style.space(12)

        Row {
          width: parent.width
          spacing: Style.space(8)

          Text {
            text: "󰄲"
            color: Color.accent
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            verticalAlignment: Text.AlignVCenter
          }

          Text {
            text: "SPAI Quick Capture"
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.heading
            font.bold: true
            verticalAlignment: Text.AlignVCenter
          }

          Item {
            width: Math.max(0, parent.width - Style.space(350))
            height: 1
          }

          Text {
            text: "Esc to close · Enter to save"
            color: Color.muted
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            anchors.verticalCenter: parent.verticalCenter
          }
        }

        Rectangle {
          width: parent.width
          height: Style.space(46)
          radius: root.cornerRadius
          color: Util.alpha(root.foreground, 0.08)
          border.color: captureInput.activeFocus ? Color.accent : Util.alpha(root.border, 0.4)
          border.width: Style.normalBorderWidth

          TextInput {
            id: captureInput
            anchors.fill: parent
            anchors.margins: Style.space(10)
            color: root.foreground
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
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
              text: "e.g. . Buy groceries ! @tomorrow :home: or ? New project idea"
              color: Color.muted
              font.family: root.fontFamily
              font.pixelSize: Style.font.body
              anchors.fill: parent
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        // SPAI Syntax Hints bar
        Row {
          width: parent.width
          spacing: Style.space(10)

          Rectangle {
            radius: Style.space(4)
            color: Util.alpha(Color.accent, 0.15)
            height: Style.space(24)
            width: prefixHintText.implicitWidth + Style.space(12)

            Text {
              id: prefixHintText
              anchors.centerIn: parent
              text: ". Todo   / Work   /. Wait   ? Idea   - Note"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            radius: Style.space(4)
            color: Util.alpha(Color.urgent, 0.15)
            height: Style.space(24)
            width: prioHintText.implicitWidth + Style.space(12)

            Text {
              id: prioHintText
              anchors.centerIn: parent
              text: "! Priority"
              color: Color.urgent
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
            }
          }

          Rectangle {
            radius: Style.space(4)
            color: Util.alpha(root.foreground, 0.12)
            height: Style.space(24)
            width: metaHintText.implicitWidth + Style.space(12)

            Text {
              id: metaHintText
              anchors.centerIn: parent
              text: "@date   :tags:"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.caption
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
      radius: root.cornerRadius
      anchors.centerIn: parent
      color: root.background
      borderSpec: root.borderSpec
      padding: root.contentMargin

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
          } else if (event.key === Qt.Key_1) {
            root.viewMode = "kanban"
            root.activeColumnIndex = 0
            event.accepted = true
          } else if (event.key === Qt.Key_2) {
            root.viewMode = "kanban"
            root.activeColumnIndex = 1
            event.accepted = true
          } else if (event.key === Qt.Key_3) {
            root.viewMode = "kanban"
            root.activeColumnIndex = 2
            event.accepted = true
          } else if (event.key === Qt.Key_4) {
            root.viewMode = "kanban"
            root.activeColumnIndex = 3
            event.accepted = true
          } else if (event.key === Qt.Key_5) {
            root.viewMode = "notes"
            event.accepted = true
          } else if (event.key === Qt.Key_6) {
            root.viewMode = "ideas"
            event.accepted = true
          } else if (event.key === Qt.Key_Tab) {
            if (root.viewMode === "kanban") {
              if (event.modifiers & Qt.ShiftModifier) {
                root.activeColumnIndex = (root.activeColumnIndex + 3) % 4
              } else {
                root.activeColumnIndex = (root.activeColumnIndex + 1) % 4
              }
            }
            event.accepted = true
          }
        }
      }

      Column {
        anchors.fill: parent
        spacing: root.contentSpacing

        // --- Header Bar ---
        Row {
          width: parent.width
          height: Style.space(38)
          spacing: Style.space(12)

          // Logo / Brand
          Row {
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter

            Text {
              text: "󰄲"
              color: Color.accent
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }

            Text {
              text: "SPAI"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.heading
              font.bold: true
            }
          }

          // Tabs: Kanban, Notes, Ideas
          Row {
            spacing: Style.space(6)
            anchors.verticalCenter: parent.verticalCenter

            Rectangle {
              height: Style.space(32)
              width: tabKanbanText.implicitWidth + Style.space(20)
              radius: root.cornerRadius
              color: root.viewMode === "kanban" ? root.selectedBackground : Util.alpha(root.foreground, 0.08)

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

            Rectangle {
              height: Style.space(32)
              width: tabNotesText.implicitWidth + Style.space(20)
              radius: root.cornerRadius
              color: root.viewMode === "notes" ? root.selectedBackground : Util.alpha(root.foreground, 0.08)

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

            Rectangle {
              height: Style.space(32)
              width: tabIdeasText.implicitWidth + Style.space(20)
              radius: root.cornerRadius
              color: root.viewMode === "ideas" ? root.selectedBackground : Util.alpha(root.foreground, 0.08)

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
            width: Math.max(0, parent.width - Style.space(750))
            height: 1
          }

          // Search Field
          Rectangle {
            width: Style.space(220)
            height: Style.space(32)
            radius: root.cornerRadius
            color: Util.alpha(root.foreground, 0.08)
            border.color: searchInput.activeFocus ? Color.accent : Util.alpha(root.border, 0.3)
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
                width: parent.width - Style.space(28)
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
                  text: "Search (/)"
                  color: Color.muted
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.body
                  anchors.fill: parent
                  verticalAlignment: Text.AlignVCenter
                }
              }
            }
          }

          // + New Item Button
          Rectangle {
            height: Style.space(32)
            width: newItemBtnText.implicitWidth + Style.space(24)
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
                text: "New Item (N)"
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
        }

        // --- Body: KANBAN BOARD ---
        Item {
          visible: root.viewMode === "kanban"
          width: parent.width
          height: parent.height - Style.space(50)

          Row {
            anchors.fill: parent
            spacing: Style.space(12)

            // Column 1: Todo
            KanbanColumn {
              width: (parent.width - Style.space(36)) / 4
              height: parent.height
              title: "Todo"
              columnStatus: "todo"
              columnType: "Todo"
              badgeColor: "#3b82f6"
              isActive: root.activeColumnIndex === 0
              rootView: root
            }

            // Column 2: In Progress
            KanbanColumn {
              width: (parent.width - Style.space(36)) / 4
              height: parent.height
              title: "In Progress"
              columnStatus: "working"
              columnType: "Todo"
              badgeColor: "#f59e0b"
              isActive: root.activeColumnIndex === 1
              rootView: root
            }

            // Column 3: Waiting
            KanbanColumn {
              width: (parent.width - Style.space(36)) / 4
              height: parent.height
              title: "Waiting"
              columnStatus: "waiting"
              columnType: "Todo"
              badgeColor: "#a855f7"
              isActive: root.activeColumnIndex === 2
              rootView: root
            }

            // Column 4: Done
            KanbanColumn {
              width: (parent.width - Style.space(36)) / 4
              height: parent.height
              title: "Done"
              columnStatus: "done"
              columnType: "Todo"
              badgeColor: "#10b981"
              isActive: root.activeColumnIndex === 3
              rootView: root
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
            spacing: Style.space(8)
            model: root.getFilteredList("Note", "note")

            delegate: Rectangle {
              width: ListView.view.width
              height: noteCol.implicitHeight + Style.space(20)
              radius: root.cornerRadius
              color: Util.alpha(root.foreground, 0.05)
              border.color: Util.alpha(root.border, 0.2)
              border.width: Style.normalBorderWidth

              Column {
                id: noteCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: "- " + modelData.title
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    width: parent.width - Style.space(60)
                    wrapMode: Text.Wrap
                  }

                  Text {
                    text: "🗑"
                    font.pixelSize: Style.font.subtitle
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
                      height: Style.space(18)
                      width: tagNoteText.implicitWidth + Style.space(8)
                      radius: Style.space(3)
                      color: Util.alpha(Color.accent, 0.15)

                      Text {
                        id: tagNoteText
                        anchors.centerIn: parent
                        text: "#" + modelData
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
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
            spacing: Style.space(8)
            model: root.getFilteredList("Idea", "idea")

            delegate: Rectangle {
              width: ListView.view.width
              height: ideaCol.implicitHeight + Style.space(20)
              radius: root.cornerRadius
              color: Util.alpha(root.foreground, 0.05)
              border.color: Util.alpha(root.border, 0.2)
              border.width: Style.normalBorderWidth

              Column {
                id: ideaCol
                anchors.fill: parent
                anchors.margins: Style.space(10)
                spacing: Style.space(6)

                Row {
                  width: parent.width
                  spacing: Style.space(8)

                  Text {
                    text: "? " + modelData.title
                    color: root.foreground
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.body
                    font.bold: true
                    width: parent.width - Style.space(140)
                    wrapMode: Text.Wrap
                  }

                  // Convert to task button
                  Rectangle {
                    height: Style.space(24)
                    width: convText.implicitWidth + Style.space(12)
                    radius: Style.space(4)
                    color: Util.alpha(Color.accent, 0.2)

                    Text {
                      id: convText
                      anchors.centerIn: parent
                      text: "→ Task"
                      color: Color.accent
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                    }

                    MouseArea {
                      anchors.fill: parent
                      cursorShape: Qt.PointingHandCursor
                      onClicked: root.updateStatus(modelData.id, "todo")
                    }
                  }

                  Text {
                    text: "🗑"
                    font.pixelSize: Style.font.subtitle
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
                      height: Style.space(18)
                      width: tagIdeaText.implicitWidth + Style.space(8)
                      radius: Style.space(3)
                      color: Util.alpha(Color.accent, 0.15)

                      Text {
                        id: tagIdeaText
                        anchors.centerIn: parent
                        text: "#" + modelData
                        color: Color.accent
                        font.family: root.fontFamily
                        font.pixelSize: Style.font.caption
                      }
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
