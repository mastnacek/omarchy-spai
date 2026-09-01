import QtQuick
import qs.Commons
import qs.Ui

Rectangle {
  id: root

  property string title: ""
  property string columnStatus: "todo"
  property string columnType: "Todo"
  property color badgeColor: Color.accent
  property bool isActive: false
  property int columnIndex: 0
  property var rootView: null

  readonly property var cardList: rootView ? rootView.getFilteredList(root.columnType, root.columnStatus) : []

  radius: Style.cornerRadius + 2
  color: Util.alpha(Color.menu.background, 0.55)
  border.color: root.isActive ? root.badgeColor : Util.alpha(root.badgeColor, 0.22)
  border.width: root.isActive ? Style.space(2) : Style.normalBorderWidth

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(10)

    // Column Header
    Item {
      width: parent.width
      height: Style.space(28)

      // Left Header: Dot + Uppercase Title + Count Badge
      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        // Accent indicator circle
        Rectangle {
          width: Style.space(9)
          height: Style.space(9)
          radius: Style.space(4.5)
          color: root.badgeColor
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.title.toUpperCase()
          color: root.isActive ? root.badgeColor : "#f8fafc"
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.subtitle
          font.bold: true
          anchors.verticalCenter: parent.verticalCenter
        }

        // Count badge
        Rectangle {
          height: Style.space(20)
          width: countText.implicitWidth + Style.space(12)
          radius: Style.space(10)
          color: Util.alpha(root.badgeColor, 0.16)
          border.color: Util.alpha(root.badgeColor, 0.35)
          border.width: 1
          anchors.verticalCenter: parent.verticalCenter

          Text {
            id: countText
            anchors.centerIn: parent
            text: root.cardList.length.toString()
            color: root.badgeColor
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            font.bold: true
          }
        }
      }

      // Right Header: + Add Button
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Style.space(24)
        width: Style.space(24)
        radius: Style.space(4)
        color: Util.alpha(root.badgeColor, 0.12)
        border.color: Util.alpha(root.badgeColor, 0.25)
        border.width: 1

        Text {
          anchors.centerIn: parent
          text: "+"
          color: root.badgeColor
          font.pixelSize: Style.font.subtitle
          font.bold: true
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.rootView) {
              root.rootView.viewMode = "capture"
              var prefix = ". "
              if (root.columnStatus === "working") prefix = "/ "
              else if (root.columnStatus === "waiting") prefix = "/. "
              else if (root.columnStatus === "done") prefix = "x "
              else if (root.columnStatus === "cancelled") prefix = "z "
              Qt.callLater(function() {
                root.rootView.captureInputText = prefix
              })
            }
          }
        }
      }
    }

    // Divider
    Rectangle {
      width: parent.width
      height: 1
      color: Util.alpha(root.badgeColor, 0.2)
    }

    // Card List
    ListView {
      id: cardListView
      width: parent.width
      height: parent.height - Style.space(42)
      clip: true
      spacing: Style.space(8)
      boundsBehavior: Flickable.StopAtBounds
      model: root.cardList

      delegate: KanbanCard {
        width: ListView.view.width
        cardData: modelData
        rootView: root.rootView
        columnIndex: root.columnIndex
        cardIndex: index
        statusColor: root.badgeColor
        isSelected: root.rootView.focusArea === "board" && root.isActive && index === root.rootView.selectedCardIndex
      }

      // Empty State
      Item {
        anchors.fill: parent
        visible: root.cardList.length === 0

        Column {
          anchors.centerIn: parent
          spacing: Style.space(6)

          Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: "No tasks"
            color: "#94a3b8"
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            opacity: 0.6
          }
        }
      }
    }
  }
}
