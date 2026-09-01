import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property var cardData: null
  property var rootView: null

  readonly property bool isDone: cardData && cardData.status === "done"
  readonly property bool isUrgent: cardData && cardData.priority === "high"

  height: cardContent.implicitHeight + Style.space(18)
  radius: Style.cornerRadius
  color: cardHover.containsMouse ? Util.alpha(Color.menu.background, 1.0) : Util.alpha(Color.menu.background, 0.9)
  border.color: isUrgent ? Util.alpha(Color.urgent, 0.7) : (cardHover.containsMouse ? Color.accent : Util.alpha(Color.menu.border, 0.25))
  border.width: isUrgent || cardHover.containsMouse ? Style.space(1.5) : Style.normalBorderWidth

  MouseArea {
    id: cardHover
    anchors.fill: parent
    hoverEnabled: true
  }

  Column {
    id: cardContent
    anchors.fill: parent
    anchors.margins: Style.space(9)
    spacing: Style.space(7)

    // Top: Title + Priority Mark
    Row {
      width: parent.width
      spacing: Style.space(6)

      // Urgent icon if priority: high
      Rectangle {
        visible: root.isUrgent
        height: Style.space(18)
        width: Style.space(18)
        radius: Style.space(9)
        color: Color.urgent
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: "!"
          color: Color.background
          font.bold: true
          font.pixelSize: Style.font.caption
        }
      }

      Text {
        text: root.cardData ? root.cardData.title : ""
        color: root.isDone ? Color.muted : Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        font.strikeout: root.isDone
        font.bold: !root.isDone
        width: parent.width - (root.isUrgent ? Style.space(24) : 0)
        wrapMode: Text.Wrap
      }
    }

    // Middle: Meta Badges (Deadline + Tags)
    Row {
      width: parent.width
      spacing: Style.space(6)
      visible: (root.cardData && root.cardData.deadline) || (root.cardData && root.cardData.tags && root.cardData.tags.length > 0)

      // Deadline Pill
      Rectangle {
        visible: root.cardData && Boolean(root.cardData.deadline)
        height: Style.space(20)
        width: deadlineText.implicitWidth + Style.space(12)
        radius: Style.space(4)
        color: Util.alpha(Color.accent, 0.15)
        border.color: Util.alpha(Color.accent, 0.3)
        border.width: 1

        Row {
          anchors.centerIn: parent
          spacing: Style.space(4)

          Text {
            text: "󰃰"
            color: Color.accent
            font.pixelSize: Style.font.caption
          }

          Text {
            id: deadlineText
            text: root.cardData && root.cardData.deadline ? root.cardData.deadline : ""
            color: Color.accent
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
        }
      }

      // Tags
      Repeater {
        model: root.cardData && root.cardData.tags ? root.cardData.tags : []
        Rectangle {
          height: Style.space(20)
          width: tagText.implicitWidth + Style.space(10)
          radius: Style.space(4)
          color: Util.alpha(Color.menu.text, 0.08)

          Text {
            id: tagText
            anchors.centerIn: parent
            text: ":" + modelData + ":"
            color: Color.muted
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
          }
        }
      }
    }

    // Bottom Action Bar (Visible on Hover or Touch)
    Row {
      width: parent.width
      height: Style.space(24)
      spacing: Style.space(6)
      visible: cardHover.containsMouse

      // Move Left
      Rectangle {
        height: Style.space(22)
        width: Style.space(22)
        radius: Style.space(4)
        color: Util.alpha(Color.menu.text, 0.1)

        Text {
          anchors.centerIn: parent
          text: "←"
          color: Color.menu.text
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.rootView && root.cardData) {
              root.rootView.cycleItemStatus(root.cardData.id, -1)
            }
          }
        }
      }

      // Move Right
      Rectangle {
        height: Style.space(22)
        width: Style.space(22)
        radius: Style.space(4)
        color: Util.alpha(Color.menu.text, 0.1)

        Text {
          anchors.centerIn: parent
          text: "→"
          color: Color.menu.text
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.rootView && root.cardData) {
              root.rootView.cycleItemStatus(root.cardData.id, 1)
            }
          }
        }
      }

      // Toggle Done
      Rectangle {
        height: Style.space(22)
        width: Style.space(22)
        radius: Style.space(4)
        color: root.isDone ? Util.alpha("#10b981", 0.3) : Util.alpha(Color.menu.text, 0.1)

        Text {
          anchors.centerIn: parent
          text: "✓"
          color: root.isDone ? "#10b981" : Color.menu.text
          font.pixelSize: Style.font.caption
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.rootView && root.cardData) {
              var next = root.isDone ? "todo" : "done"
              root.rootView.updateStatus(root.cardData.id, next)
            }
          }
        }
      }

      Item {
        width: Math.max(0, parent.width - Style.space(90))
        height: 1
      }

      // Delete
      Rectangle {
        height: Style.space(22)
        width: Style.space(22)
        radius: Style.space(4)
        color: Util.alpha(Color.urgent, 0.15)

        Text {
          anchors.centerIn: parent
          text: "✕"
          color: Color.urgent
          font.pixelSize: Style.font.caption
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.rootView && root.cardData) {
              root.rootView.deleteItem(root.cardData.id)
            }
          }
        }
      }
    }
  }
}
