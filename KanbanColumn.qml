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
  property var rootView: null

  readonly property var cardList: rootView ? rootView.getFilteredList(root.columnType, root.columnStatus) : []

  radius: Style.cornerRadius
  color: Util.alpha(Color.menu.background, 0.6)
  border.color: root.isActive ? Color.accent : Util.alpha(Color.menu.border, 0.25)
  border.width: root.isActive ? Style.space(2) : Style.normalBorderWidth

  Column {
    anchors.fill: parent
    anchors.margins: Style.space(8)
    spacing: Style.space(8)

    // Column Header
    Row {
      width: parent.width
      height: Style.space(28)
      spacing: Style.space(8)

      Rectangle {
        width: Style.space(8)
        height: Style.space(8)
        radius: Style.space(4)
        color: root.badgeColor
        anchors.verticalCenter: parent.verticalCenter
      }

      Text {
        text: root.title
        color: Color.menu.text
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.subtitle
        font.bold: true
        anchors.verticalCenter: parent.verticalCenter
      }

      Rectangle {
        height: Style.space(18)
        width: countText.implicitWidth + Style.space(10)
        radius: Style.space(9)
        color: Util.alpha(root.badgeColor, 0.2)
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

      Item { width: 1; height: 1; Layout.fillWidth: true }

      // + Button for this specific column
      Rectangle {
        height: Style.space(22)
        width: Style.space(22)
        radius: Style.space(4)
        color: Util.alpha(Color.menu.text, 0.08)
        anchors.verticalCenter: parent.verticalCenter

        Text {
          anchors.centerIn: parent
          text: "+"
          color: Color.menu.text
          font.pixelSize: Style.font.subtitle
        }

        MouseArea {
          anchors.fill: parent
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            if (root.rootView) {
              root.rootView.viewMode = "capture"
              // Pre-fill prefix for this column
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
      width: parent.width
      height: parent.height - Style.space(38)
      clip: true
      spacing: Style.space(8)
      boundsBehavior: Flickable.StopAtBounds
      model: root.cardList

      delegate: KanbanCard {
        width: ListView.view.width
        cardData: modelData
        rootView: root.rootView
      }

      // Empty State
      Item {
        anchors.fill: parent
        visible: root.cardList.length === 0

        Text {
          anchors.centerIn: parent
          text: "No cards"
          color: Color.muted
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.caption
          opacity: 0.6
        }
      }
    }
  }
}
