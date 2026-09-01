import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "SpaiModel.js" as SpaiModel

Panel {
  id: root
  moduleName: "jara.spai"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property string spaiDataDir: Quickshell.env("HOME") + "/Documents/spai"
  property string spaiDataPath: spaiDataDir + "/.index.json"
  property var rawItems: []
  property var stats: ({ total: 0, todo: 0, working: 0, waiting: 0, done: 0, cancelled: 0, notes: 0, ideas: 0, pendingTotal: 0 })

  function open() {
    dataFile.reload()
    root.controller.show()
  }

  function close() {
    root.controller.hide()
  }

  function loadData(rawText) {
    root.rawItems = SpaiModel.parseItems(rawText)
    root.stats = SpaiModel.getStats(root.rawItems)
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

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.hostWidget || root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(contentCol.implicitHeight + Style.space(24))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()

      BorderSurface {
        anchors.fill: parent
        color: Color.menu.background
        borderSpec: Border.surfaceSpec("menu", "border", Color.menu.border, Style.normalBorderWidth)
        radius: Style.cornerRadius + 2

        Column {
          id: contentCol
          anchors.fill: parent
          anchors.margins: Style.space(12)
          spacing: Style.space(10)

          // 1. Header Bar: Brand + Active Count
          Item {
            width: parent.width
            height: Style.space(28)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Rectangle {
                width: Style.space(26)
                height: Style.space(26)
                radius: Style.space(5)
                color: Util.alpha(Color.accent, 0.18)
                anchors.verticalCenter: parent.verticalCenter

                Text {
                  anchors.centerIn: parent
                  text: "󰄲"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
              }

              Text {
                text: "SPAI Tasks"
                color: "#ffffff"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            // Active counter badge
            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(22)
              width: countBadgeText.implicitWidth + Style.space(12)
              radius: Style.space(11)
              color: Util.alpha(Color.accent, 0.18)
              border.color: Util.alpha(Color.accent, 0.35)
              border.width: 1

              Text {
                id: countBadgeText
                anchors.centerIn: parent
                text: root.stats.pendingTotal + " active"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.caption
                font.bold: true
              }
            }
          }

          // Divider
          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(Color.menu.border, 0.25)
          }

          // 2. 5 Linkarzu Status Chips Grid
          Row {
            width: parent.width
            spacing: Style.space(5)

            // Todo
            Rectangle {
              width: (parent.width - Style.space(20)) / 5
              height: Style.space(38)
              radius: Style.space(5)
              color: Util.alpha("#f94dff", 0.14)
              border.color: Util.alpha("#f94dff", 0.35)
              border.width: 1

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { text: "○ TODO"; color: "#f94dff"; font.pixelSize: Style.font.caption; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: root.stats.todo.toString(); color: "#ffffff"; font.pixelSize: Style.font.bodySmall; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }

            // Working
            Rectangle {
              width: (parent.width - Style.space(20)) / 5
              height: Style.space(38)
              radius: Style.space(5)
              color: Util.alpha("#f1fc79", 0.14)
              border.color: Util.alpha("#f1fc79", 0.35)
              border.width: 1

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { text: "◐ WORK"; color: "#f1fc79"; font.pixelSize: Style.font.caption; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: root.stats.working.toString(); color: "#ffffff"; font.pixelSize: Style.font.bodySmall; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }

            // Waiting
            Rectangle {
              width: (parent.width - Style.space(20)) / 5
              height: Style.space(38)
              radius: Style.space(5)
              color: Util.alpha("#987afb", 0.14)
              border.color: Util.alpha("#987afb", 0.35)
              border.width: 1

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { text: "⏳ WAIT"; color: "#987afb"; font.pixelSize: Style.font.caption; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: root.stats.waiting.toString(); color: "#ffffff"; font.pixelSize: Style.font.bodySmall; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }

            // Done
            Rectangle {
              width: (parent.width - Style.space(20)) / 5
              height: Style.space(38)
              radius: Style.space(5)
              color: Util.alpha("#37f499", 0.14)
              border.color: Util.alpha("#37f499", 0.35)
              border.width: 1

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { text: "✓ DONE"; color: "#37f499"; font.pixelSize: Style.font.caption; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: root.stats.done.toString(); color: "#ffffff"; font.pixelSize: Style.font.bodySmall; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }

            // Cancelled
            Rectangle {
              width: (parent.width - Style.space(20)) / 5
              height: Style.space(38)
              radius: Style.space(5)
              color: Util.alpha("#5f6b8a", 0.14)
              border.color: Util.alpha("#5f6b8a", 0.35)
              border.width: 1

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { text: "✗ CANCEL"; color: "#5f6b8a"; font.pixelSize: Style.font.caption; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: root.stats.cancelled.toString(); color: "#ffffff"; font.pixelSize: Style.font.bodySmall; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }
          }

          // 3. Top Tasks Live Preview Cards
          Column {
            width: parent.width
            spacing: Style.space(5)
            visible: root.stats.pendingTotal > 0

            Repeater {
              model: root.rawItems.filter(function(it) {
                return it.type === "Todo" && (it.status === "working" || it.status === "todo" || it.status === "waiting");
              }).slice(0, 4)

              Rectangle {
                width: parent.width
                height: Style.space(26)
                radius: Style.space(4)
                color: Util.alpha(Color.menu.text, 0.05)
                border.color: Util.alpha(Color.menu.border, 0.15)
                border.width: 1

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(8)
                  anchors.rightMargin: Style.space(8)
                  spacing: Style.space(8)

                  // Status Icon
                  Text {
                    text: modelData.status === "working" ? "◐" : (modelData.status === "waiting" ? "⏳" : "○")
                    color: modelData.status === "working" ? "#f1fc79" : (modelData.status === "waiting" ? "#987afb" : "#f94dff")
                    font.pixelSize: Style.font.bodySmall
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  // Urgent badge
                  Rectangle {
                    visible: modelData.priority === "high"
                    height: Style.space(16)
                    width: Style.space(16)
                    radius: Style.space(3)
                    color: Util.alpha("#f16c75", 0.2)
                    border.color: "#f16c75"
                    border.width: 1
                    anchors.verticalCenter: parent.verticalCenter

                    Text {
                      anchors.centerIn: parent
                      text: "!"
                      color: "#f16c75"
                      font.bold: true
                      font.pixelSize: Style.font.caption
                    }
                  }

                  // Title
                  Text {
                    text: modelData.title
                    color: "#f1f5f9"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    elide: Text.ElideRight
                    width: parent.width - (modelData.priority === "high" ? Style.space(50) : Style.space(30))
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }
          }

          // 4. Notes & Ideas Summary
          Item {
            width: parent.width
            height: Style.space(22)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(8)

              Rectangle {
                height: Style.space(20)
                width: notesCountText.implicitWidth + Style.space(10)
                radius: Style.space(4)
                color: Util.alpha("#04d1f9", 0.12)
                border.color: Util.alpha("#04d1f9", 0.3)
                border.width: 1

                Text {
                  id: notesCountText
                  anchors.centerIn: parent
                  text: "󰎞 " + root.stats.notes + " Notes"
                  color: "#04d1f9"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              Rectangle {
                height: Style.space(20)
                width: ideasCountText.implicitWidth + Style.space(10)
                radius: Style.space(4)
                color: Util.alpha("#ec4899", 0.12)
                border.color: Util.alpha("#ec4899", 0.3)
                border.width: 1

                Text {
                  id: ideasCountText
                  anchors.centerIn: parent
                  text: "󰌵 " + root.stats.ideas + " Ideas"
                  color: "#ec4899"
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }
            }
          }

          // 5. Action Buttons (Full Board & Quick Capture)
          Row {
            width: parent.width
            height: Style.space(32)
            spacing: Style.space(8)

            // Full Board Button
            Rectangle {
              width: (parent.width - Style.space(8)) / 2
              height: parent.height
              radius: Style.space(5)
              color: Util.alpha(Color.accent, 0.18)
              border.color: Util.alpha(Color.accent, 0.4)
              border.width: 1

              Row {
                anchors.centerIn: parent
                spacing: Style.space(5)

                Text {
                  text: "⊞"
                  color: Color.accent
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Text {
                  text: "Kanban Board"
                  color: Color.accent
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.close()
                  Quickshell.execDetached(["omarchy-shell", "shell", "summon", "jara.spai", "{\"mode\":\"kanban\"}"])
                }
              }
            }

            // Quick Capture Button
            Rectangle {
              width: (parent.width - Style.space(8)) / 2
              height: parent.height
              radius: Style.space(5)
              color: Color.accent

              Row {
                anchors.centerIn: parent
                spacing: Style.space(5)

                Text {
                  text: "+"
                  color: Color.background
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                }

                Text {
                  text: "Quick Capture"
                  color: Color.background
                  font.family: Style.font.family
                  font.pixelSize: Style.font.caption
                  font.bold: true
                }
              }

              MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                onClicked: {
                  root.close()
                  Quickshell.execDetached(["omarchy-shell", "shell", "summon", "jara.spai", "{\"mode\":\"capture\"}"])
                }
              }
            }
          }
        }
      }
    }
  }
}
