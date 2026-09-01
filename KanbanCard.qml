import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property var cardData: null
  property var rootView: null
  property bool isSelected: false
  property int cardIndex: 0
  property int columnIndex: 0
  property color statusColor: Color.accent

  readonly property bool isDone: cardData && cardData.status === "done"
  readonly property bool isCancelled: cardData && cardData.status === "cancelled"
  readonly property bool isUrgent: cardData && cardData.priority === "high"

  height: cardContent.implicitHeight + Style.space(18)
  radius: Style.cornerRadius
  color: root.isSelected
    ? Util.alpha(root.statusColor, 0.15)
    : (cardHover.containsMouse ? Util.alpha(Color.menu.background, 0.98) : Util.alpha(Color.menu.background, 0.78))
  border.color: root.isSelected
    ? root.statusColor
    : (isUrgent ? Util.alpha("#f16c75", 0.7) : (cardHover.containsMouse ? Util.alpha(root.statusColor, 0.5) : Util.alpha(Color.menu.border, 0.2)))
  border.width: root.isSelected ? 2 : (cardHover.containsMouse ? 1.5 : 1)

  MouseArea {
    id: cardHover
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.PointingHandCursor
    onClicked: {
      if (root.rootView) {
        root.rootView.activeColumnIndex = root.columnIndex
        root.rootView.selectedCardIndex = root.cardIndex
      }
    }
  }

  Column {
    id: cardContent
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(8)

    // Top: Status Dot + Title + Priority Mark
    Row {
      width: parent.width
      spacing: Style.space(8)

      // Status indicator dot
      Rectangle {
        width: Style.space(7)
        height: Style.space(7)
        radius: Style.space(3.5)
        color: root.statusColor
        anchors.verticalCenter: parent.verticalCenter
      }

      // Urgent icon if priority: high
      Rectangle {
        visible: root.isUrgent
        height: Style.space(18)
        width: Style.space(18)
        radius: Style.space(4)
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

      Text {
        text: root.cardData ? root.cardData.title : ""
        color: (root.isDone || root.isCancelled)
          ? Color.muted
          : (root.isSelected ? root.statusColor : Color.menu.text)
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.body
        font.strikeout: root.isDone || root.isCancelled
        font.bold: !root.isDone && !root.isCancelled || root.isSelected
        width: parent.width - (root.isUrgent ? Style.space(34) : Style.space(15))
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
        color: Util.alpha(Color.accent, 0.12)
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
          color: Util.alpha(Color.menu.text, 0.06)
          border.color: Util.alpha(Color.menu.text, 0.12)
          border.width: 1

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

    // Bottom Action Bar (Anchored safely inside card)
    Item {
      width: parent.width
      height: Style.space(24)
      visible: cardHover.containsMouse || root.isSelected

      // Left Actions: Move Left, Move Right, Toggle Done
      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(6)

        // Move Left Button
        Rectangle {
          height: Style.space(22)
          width: Style.space(22)
          radius: Style.space(4)
          color: Util.alpha(Color.menu.text, 0.08)
          border.color: Util.alpha(Color.menu.text, 0.15)
          border.width: 1

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
                root.rootView.cycleItemStatusAndFollow(root.cardData.id, -1)
              }
            }
          }
        }

        // Move Right / Space Button
        Rectangle {
          height: Style.space(22)
          width: Style.space(22)
          radius: Style.space(4)
          color: Util.alpha(Color.menu.text, 0.08)
          border.color: Util.alpha(Color.menu.text, 0.15)
          border.width: 1

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
                root.rootView.cycleItemStatusAndFollow(root.cardData.id, 1)
              }
            }
          }
        }

        // Toggle Done Button
        Rectangle {
          height: Style.space(22)
          width: Style.space(22)
          radius: Style.space(4)
          color: root.isDone ? Util.alpha("#37f499", 0.25) : Util.alpha(Color.menu.text, 0.08)
          border.color: root.isDone ? "#37f499" : Util.alpha(Color.menu.text, 0.15)
          border.width: 1

          Text {
            anchors.centerIn: parent
            text: "✓"
            color: root.isDone ? "#37f499" : Color.menu.text
            font.pixelSize: Style.font.caption
            font.bold: true
          }

          MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: {
              if (root.rootView && root.cardData) {
                var next = root.isDone ? "todo" : "done"
                root.rootView.updateStatusAndFollow(root.cardData.id, next)
              }
            }
          }
        }
      }

      // Right Action: Delete Button
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Style.space(22)
        width: Style.space(22)
        radius: Style.space(4)
        color: Util.alpha("#f16c75", 0.15)
        border.color: Util.alpha("#f16c75", 0.35)
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
