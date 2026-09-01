import QtQuick
import QtQuick.Controls as QQC
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
    tooltipText: "" // Replaced by rich Mini Kanban ToolTip
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.LeftButton) {
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", root.moduleName, "{\"mode\":\"kanban\"}"])
      } else if (buttonCode === Qt.RightButton) {
        Quickshell.execDetached(["omarchy-shell", "shell", "summon", root.moduleName, "{\"mode\":\"capture\"}"])
      }
    }

    MouseArea {
      id: mouseTracker
      anchors.fill: parent
      hoverEnabled: true
      acceptedButtons: Qt.NoButton
    }

    QQC.ToolTip {
      id: richToolTip
      visible: mouseTracker.containsMouse
      delay: 350
      timeout: 12000
      padding: 0

      background: BorderSurface {
        color: Util.alpha(Color.menu.background, 0.97)
        borderSpec: Border.localOrSurfaceSpec("tooltip", "border", Color.accent, Color.tooltip.border, Style.normalBorderWidth)
        radius: Style.cornerRadius + 2
      }

      contentItem: Item {
        width: Style.space(320)
        height: tooltipCol.implicitHeight + Style.space(20)

        Column {
          id: tooltipCol
          anchors.fill: parent
          anchors.margins: Style.space(10)
          spacing: Style.space(8)

          // Header: Brand + Active counter chip
          Item {
            width: parent.width
            height: Style.space(24)

            Row {
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(6)

              Text {
                text: "󰄲"
                color: Color.accent
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }

              Text {
                text: "SPAI Mini Board"
                color: "#ffffff"
                font.family: Style.font.family
                font.pixelSize: Style.font.subtitle
                font.bold: true
              }
            }

            // Active counter badge
            Rectangle {
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
              height: Style.space(20)
              width: countBadgeText.implicitWidth + Style.space(10)
              radius: Style.space(10)
              color: Util.alpha(Color.accent, 0.18)
              border.color: Util.alpha(Color.accent, 0.4)
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

          // Mini Divider
          Rectangle {
            width: parent.width
            height: 1
            color: Util.alpha(Color.menu.border, 0.25)
          }

          // 5 Mini Kanban Status Chips
          Row {
            width: parent.width
            spacing: Style.space(4)

            // Todo
            Rectangle {
              width: (parent.width - Style.space(16)) / 5
              height: Style.space(36)
              radius: Style.space(4)
              color: Util.alpha("#f94dff", 0.14)
              border.color: Util.alpha("#f94dff", 0.4)
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
              width: (parent.width - Style.space(16)) / 5
              height: Style.space(36)
              radius: Style.space(4)
              color: Util.alpha("#f1fc79", 0.14)
              border.color: Util.alpha("#f1fc79", 0.4)
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
              width: (parent.width - Style.space(16)) / 5
              height: Style.space(36)
              radius: Style.space(4)
              color: Util.alpha("#987afb", 0.14)
              border.color: Util.alpha("#987afb", 0.4)
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
              width: (parent.width - Style.space(16)) / 5
              height: Style.space(36)
              radius: Style.space(4)
              color: Util.alpha("#37f499", 0.14)
              border.color: Util.alpha("#37f499", 0.4)
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
              width: (parent.width - Style.space(16)) / 5
              height: Style.space(36)
              radius: Style.space(4)
              color: Util.alpha("#5f6b8a", 0.14)
              border.color: Util.alpha("#5f6b8a", 0.4)
              border.width: 1

              Column {
                anchors.centerIn: parent
                spacing: 1
                Text { text: "✗ CANCEL"; color: "#5f6b8a"; font.pixelSize: Style.font.caption; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
                Text { text: root.stats.cancelled.toString(); color: "#ffffff"; font.pixelSize: Style.font.bodySmall; font.bold: true; anchors.horizontalCenter: parent.horizontalCenter }
              }
            }
          }

          // Active / Top Tasks Preview
          Column {
            width: parent.width
            spacing: Style.space(4)
            visible: root.stats.pendingTotal > 0

            Repeater {
              model: root.rawItems.filter(function(it) {
                return it.type === "Todo" && (it.status === "working" || it.status === "todo" || it.status === "waiting");
              }).slice(0, 3)

              Rectangle {
                width: parent.width
                height: Style.space(22)
                radius: Style.space(3)
                color: Util.alpha(Color.menu.text, 0.05)

                Row {
                  anchors.fill: parent
                  anchors.leftMargin: Style.space(6)
                  anchors.rightMargin: Style.space(6)
                  spacing: Style.space(6)

                  Text {
                    text: modelData.status === "working" ? "◐" : (modelData.status === "waiting" ? "⏳" : "○")
                    color: modelData.status === "working" ? "#f1fc79" : (modelData.status === "waiting" ? "#987afb" : "#f94dff")
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    text: modelData.title
                    color: "#f1f5f9"
                    font.family: Style.font.family
                    font.pixelSize: Style.font.caption
                    elide: Text.ElideRight
                    width: parent.width - Style.space(28)
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }
              }
            }
          }

          // Notes & Ideas summary pill
          Row {
            spacing: Style.space(8)
            Text { text: "󰎞 " + root.stats.notes + " Notes"; color: "#04d1f9"; font.pixelSize: Style.font.caption; font.bold: true }
            Text { text: "·"; color: Color.muted; font.pixelSize: Style.font.caption }
            Text { text: "󰌵 " + root.stats.ideas + " Ideas"; color: "#ec4899"; font.pixelSize: Style.font.caption; font.bold: true }
          }

          // Footer Action Hints
          Rectangle {
            width: parent.width
            height: Style.space(20)
            radius: Style.space(3)
            color: Util.alpha(Color.accent, 0.1)

            Row {
              anchors.centerIn: parent
              spacing: Style.space(8)
              Text { text: "L-Click: Board"; color: Color.accent; font.pixelSize: Style.font.caption }
              Text { text: "·"; color: Color.muted; font.pixelSize: Style.font.caption }
              Text { text: "R-Click: Quick Capture"; color: Color.accent; font.pixelSize: Style.font.caption }
            }
          }
        }
      }
    }
  }
}
