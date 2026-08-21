import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

// Generic authentication surface. The caller supplies a JSON request and a
// private runtime-file path; the response is written to that path so secrets
// never travel through shell IPC arguments or command-line arguments.
Item {
  id: root

  property string omarchyPath: Quickshell.env("OMARCHY_PATH")
  property var shell: null
  property var manifest: null

  property bool opened: false
  property bool submitted: false
  property string responsePath: ""
  property string message: ""
  property string prompt: "Enter password"
  property string errorMessage: ""
  property int timeoutMs: 120000

  readonly property string runtimeDir: Quickshell.env("XDG_RUNTIME_DIR")
  readonly property string pluginDir: root.manifest && root.manifest.__sourceDir
    ? String(root.manifest.__sourceDir)
    : ""

  function launchHelper(action) {
    if (!root.pluginDir) return "plugin path unavailable"
    var command = Util.shellQuote(root.pluginDir + "/bin/omauth-prompt")
      + " " + Util.shellQuote(action)
    Util.execDetached(
      "omarchy-launch-floating-terminal-with-presentation " + Util.shellQuote(command)
    )
    return "started"
  }

  function validResponsePath(path) {
    var value = String(path || "")
    var prefix = root.runtimeDir ? root.runtimeDir.replace(/\/$/, "") + "/" : ""
    return prefix !== ""
      && value.indexOf(prefix) === 0
      && value.length > prefix.length
      && value.indexOf("\n") === -1
      && value.indexOf("\r") === -1
      && value.indexOf("\u0000") === -1
  }

  function open(payloadJson) {
    var payload
    try {
      payload = JSON.parse(payloadJson || "{}") || {}
    } catch (e) {
      return "invalid payload"
    }

    if (!validResponsePath(payload.responsePath)) return "invalid response path"
    if (root.opened) finish("cancel", "")

    root.responsePath = String(payload.responsePath)
    root.message = String(payload.description || payload.title || "Authentication required")
    root.prompt = String(payload.prompt || "Enter password")
    root.errorMessage = String(payload.error || "")
    root.timeoutMs = Number(payload.timeoutMs || 120000)
    if (!isFinite(root.timeoutMs) || root.timeoutMs <= 0) root.timeoutMs = 120000
    root.submitted = false
    root.opened = true
    requestTimer.restart()
    Qt.callLater(passwordPrompt.focusInput)
    return "ok"
  }

  function close() {
    if (root.opened) finish("cancel", "")
    return "ok"
  }

  function finish(status, secret) {
    if (!root.responsePath) {
      root.opened = false
      root.submitted = false
      passwordPrompt.clear()
      requestTimer.stop()
      return
    }

    resultFile.path = root.responsePath
    resultFile.setText(JSON.stringify({
      status: String(status),
      secret: status === "ok" ? String(secret || "") : ""
    }) + "\n")

    root.responsePath = ""
    root.opened = false
    root.submitted = false
    passwordPrompt.clear()
    requestTimer.stop()
  }

  function submit(secret) {
    if (!root.opened || root.submitted) return
    root.submitted = true
    finish("ok", secret)
  }

  IpcHandler {
    target: "omauth"

    function prompt(payloadJson: string): string { return root.open(payloadJson) }
    function cancel(): string { return root.close() }
    function setup(): string { return root.launchHelper("setup-gpg") }
    function remove(): string { return root.launchHelper("remove-gpg") }
    function status(): string { return root.launchHelper("status") }
  }

  Timer {
    id: requestTimer
    interval: root.timeoutMs
    repeat: false
    onTriggered: root.close()
  }

  FileView {
    id: resultFile
    atomicWrites: true
    printErrors: false
  }

  PanelWindow {
    id: panel
    visible: root.opened
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    WlrLayershell.namespace: "omauth-prompt"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore

    Rectangle {
      anchors.fill: parent
      color: Util.alpha(Color.polkit.scrim, 0.78)
    }

    MouseArea {
      anchors.fill: parent
      onClicked: passwordPrompt.focusInput()
    }

    PasswordPrompt {
      id: passwordPrompt
      anchors.centerIn: parent
      availableWidth: panel.width
      availableHeight: panel.height
      message: root.message
      inputPlaceholder: root.prompt
      errorMessage: root.errorMessage
      error: root.errorMessage.length > 0
      submitted: root.submitted
      inputEnabled: root.opened && !root.submitted
      onAccepted: root.submit(text)
      onCancelled: root.close()
    }
  }
}
