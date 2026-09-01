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

  radius: Style.cornerRadius
  color: Util.alpha(Color.menu.background, 0.5)
  border.color: root.isActive ? Color.accent : Util.alpha(Color.menu.border, 0.25)
  border.width: root.isActive ? Style.space(2) : Style.normalBorderWidth

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(10)
    spacing: Style.space(10)

    // Column Header (immune to overlap via anchors)
    Item {
      width: parent.width
      height: Style.space(28)

      // Left Header content: Dot + Title + Count badge
      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: Style.space(8)

        // Accent color dot
        Rectangle {
          width: Style.space(10)
          height: Style.space(10)
          radius: Style.space(5)
          color: root.badgeColor
          anchors.verticalCenter: parent.verticalCenter
        }

        Text {
          text: root.title
          color: root.isActive ? Color.accent : Color.menu.text
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
          color: Util.alpha(root.badgeColor, 0.18)
          border.color: Util.alpha(root.badgeColor, 0.3)
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

      // Right Header content: + Button
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        height: Style.space(24)
        width: Style.space(24)
        radius: Style.space(4)
        color: Util.alpha(Color.menu.text, 0.08)

        Text {
          anchors.centerIn: parent
          text: "+"
          color: Color.menu.text
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
      color: Util.alpha(Color.menu.border, 0.15)
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
        isSelected: root.isActive && index === root.rootView.selectedCardIndex
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
            color: Color.muted
            font.family: Style.font.menuFamily
            font.pixelSize: Style.font.caption
            opacity: 0.5
          }
        }
      }
    }
  }
}
