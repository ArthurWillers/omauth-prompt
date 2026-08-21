import QtQuick
import qs.Commons
import qs.Ui

// The visual part of omauth-prompt. It deliberately knows nothing about the
// caller: adapters own the request lifecycle and receive only the accepted or
// cancelled signals.
Item {
  id: root

  property string message: ""
  property string inputPlaceholder: "Enter password"
  property string errorMessage: "Authentication failed"
  property string checkingMessage: "Checking..."
  property bool submitted: false
  property bool error: false
  property bool inputEnabled: true
  property bool allowInputWhenError: true
  property bool responseVisible: false
  property int availableWidth: 9999
  property int availableHeight: 9999
  property real horizontalOffset: 0

  property alias passwordText: passwordInput.text

  signal accepted(string text)
  signal cancelled()

  readonly property int fieldHeight: Math.max(Style.space(42), Style.spacing.controlHeight)
  readonly property int contentMargin: Style.spacing.panelPadding
  readonly property int cardHeight: availableHeight > 0
    ? Math.min(fieldHeight + contentMargin * 2, availableHeight - Style.gapsOut * 2)
    : fieldHeight + contentMargin * 2
  readonly property int cardWidth: Math.min(
    Style.space(312),
    Math.max(Style.space(260), availableWidth - Style.gapsOut * 2)
  )
  readonly property int labelHeight: message.length > 0 ? Style.space(28) : 0
  readonly property int labelMargin: message.length > 0 ? Style.space(10) : 0

  implicitWidth: cardWidth
  implicitHeight: cardHeight + labelHeight + labelMargin

  function focusInput() {
    if (root.inputEnabled) passwordInput.forceActiveFocus()
  }

  function clear() { passwordInput.text = "" }

  BorderSurface {
    id: card
    width: root.cardWidth
    height: root.cardHeight
    anchors.bottom: parent.bottom
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.horizontalCenterOffset: root.horizontalOffset
    color: Color.polkit.background
    borderSpec: Border.surfaceSpec(
      "polkit",
      root.error ? "border-error" : "border",
      root.error ? Color.polkit.borderError : Color.polkit.border,
      Math.max(1, Style.space(2)),
      "border-alpha"
    )
    padding: root.contentMargin
    radius: Style.cornerRadius

    MouseArea {
      anchors.fill: parent
      onClicked: root.focusInput()
    }

    Row {
      anchors.fill: parent
      anchors.topMargin: card.contentTopInset
      anchors.rightMargin: card.contentRightInset
      anchors.bottomMargin: card.contentBottomInset
      anchors.leftMargin: card.contentLeftInset
      spacing: Style.space(14)

      Text {
        text: "\uf023"
        color: root.error ? Color.polkit.textError : Color.polkit.accent
        font.family: Style.font.menuFamily
        font.pixelSize: Style.font.iconLarge
        width: Style.space(26)
        height: root.fieldHeight
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
      }

      Item {
        width: parent.width - Style.space(40)
        height: root.fieldHeight

        TextInput {
          id: passwordInput
          anchors.fill: parent
          verticalAlignment: TextInput.AlignVCenter
          activeFocusOnPress: true
          clip: true
          selectionColor: Util.alpha(Color.polkit.accent, 0.45)
          selectedTextColor: Color.polkit.text
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.iconLarge
          echoMode: root.responseVisible ? TextInput.Normal : TextInput.Password
          passwordCharacter: "\u2022"
          color: root.error ? Color.polkit.textError : Color.polkit.text
          cursorVisible: activeFocus && !root.submitted && (!root.error || root.allowInputWhenError)
          readOnly: root.submitted || (root.error && !root.allowInputWhenError)
          enabled: root.inputEnabled
          onAccepted: {
            if (!root.submitted && (!root.error || root.allowInputWhenError)) root.accepted(text)
          }
          Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Escape) {
              root.cancelled()
              event.accepted = true
            }
          }
        }

        Text {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          text: root.error
            ? root.errorMessage
            : (root.submitted ? root.checkingMessage : root.inputPlaceholder)
          color: root.error ? Color.polkit.textError : Color.polkit.text
          opacity: root.error ? 1 : 0.36
          font.family: Style.font.menuFamily
          font.pixelSize: Style.font.iconLarge
          elide: Text.ElideRight
          visible: passwordInput.text.length === 0
        }

        Rectangle {
          width: Math.max(1, Style.space(2))
          height: Style.space(24)
          anchors.left: parent.left
          anchors.verticalCenter: parent.verticalCenter
          color: root.error ? Color.polkit.textError : Color.polkit.text
          visible: passwordInput.visible
            && passwordInput.activeFocus
            && passwordInput.text.length === 0
            && !root.submitted
            && (!root.error || root.allowInputWhenError)
        }

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.LeftButton
          enabled: passwordInput.visible
          onClicked: passwordInput.forceActiveFocus()
        }
      }
    }
  }

  Rectangle {
    visible: root.message.length > 0
    width: Math.min(messageText.implicitWidth + Style.space(24), root.availableWidth - Style.gapsOut * 2)
    height: root.labelHeight
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.bottom: card.top
    anchors.bottomMargin: root.labelMargin
    radius: Style.cornerRadius
    color: Color.polkit.background

    Text {
      id: messageText
      anchors.fill: parent
      anchors.leftMargin: Style.space(12)
      anchors.rightMargin: Style.space(12)
      text: root.message
      color: root.error ? Color.polkit.textError : Color.polkit.text
      font.family: Style.font.menuFamily
      font.pixelSize: Style.font.bodySmall
      horizontalAlignment: Text.AlignHCenter
      verticalAlignment: Text.AlignVCenter
      elide: Text.ElideMiddle
    }
  }

  Item {
    anchors.fill: card
    focus: true
    Keys.priority: Keys.BeforeItem
    Keys.onPressed: function(event) {
      if (event.key === Qt.Key_Escape) {
        root.cancelled()
        event.accepted = true
      }
    }
  }
}
