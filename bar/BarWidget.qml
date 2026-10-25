import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Current posture and the minutes left in it. Everything comes from the
// state file bin/screen-alarm keeps in $XDG_RUNTIME_DIR; the daemon removes it
// on exit, so the widget hides itself whenever the reminder is not running.
//
// Clicking opens a popup to start sitting or standing now; nothing changes
// until a posture is picked there, so a stray click on the bar is harmless.
// `omarchy-shell ai.bkblab.screen-alarm toggle` opens the same popup, e.g.
// from a keybinding.
Panel {
  id: root
  moduleName: "ai.bkblab.screen-alarm"
  ipcTarget: "ai.bkblab.screen-alarm"

  readonly property var icons: ({ sit: "󰽈", stand: "󰋦" })
  readonly property var verbs: ({ sit: "坐", stand: "站" })

  // Not `state`: Item already has one.
  property var alarm: null
  property real now: Date.now()
  // Popup keyboard cursor: "sit" or "stand".
  property string cursor: "stand"

  readonly property bool counting: alarm !== null && alarm.state === "counting"
  readonly property bool alerting: alarm !== null && alarm.state === "alert"
  // While counting, the posture being held; while alerting, the one that
  // just ended.
  readonly property string posture: alarm !== null && alarm.posture === "stand" ? "stand" : "sit"
  readonly property string otherPosture: posture === "sit" ? "stand" : "sit"
  // Rounded up and never below 1: the label means "under N minutes left".
  readonly property int minutesLeft: counting
    ? Math.max(1, Math.ceil((alarm.deadline * 1000 - now) / 60000)) : 0
  readonly property string deadlineClock: counting
    ? Qt.formatDateTime(new Date(alarm.deadline * 1000), "HH:mm") : ""

  readonly property color fg: root.bar ? root.bar.foreground : Color.foreground
  readonly property color dim: Qt.darker(fg, 1.4)
  readonly property color urgent: root.bar ? root.bar.urgent : Color.urgent
  readonly property string fontFamily: root.bar ? root.bar.fontFamily : Style.font.family

  function minutesFor(p) {
    var intervals = alarm !== null && alarm.intervals ? alarm.intervals : null
    return intervals && intervals[p] ? Math.round(intervals[p] / 60) : (p === "stand" ? 15 : 40)
  }

  visible: counting || alerting
  implicitWidth: visible ? button.implicitWidth : 0
  implicitHeight: button.implicitHeight

  onVisibleChanged: if (!visible) close()
  // Every open starts on the switch, which is the usual reason to click.
  onOpenedChanged: if (opened) cursor = otherPosture

  FileView {
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/screen-alarm.json"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.parse(text())
    onLoadFailed: root.alarm = null
  }

  function parse(content) {
    try {
      var parsed = JSON.parse(String(content || ""))
      root.alarm = parsed && typeof parsed === "object" ? parsed : null
    } catch (e) {
      root.alarm = null
    }
    root.now = Date.now()
  }

  // The daemon owns the countdown; it answers by rewriting the state file,
  // which is what updates the label.
  function start(p) {
    Quickshell.execDetached([
      "gdbus", "call", "--session",
      "--dest", "ai.bkblab.ScreenAlarm",
      "--object-path", "/ai/bkblab/ScreenAlarm",
      "--method", "org.gtk.Actions.Activate",
      "start", "[<'" + p + "'>]", "{}"
    ])
    close()
  }

  // Cheap enough to just tick every second while counting; the label then
  // follows the deadline without tracking minute boundaries.
  Timer {
    interval: 1000
    repeat: true
    running: root.counting
    onTriggered: root.now = Date.now()
  }

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: root.alerting
      ? root.icons[root.otherPosture] + "  该" + root.verbs[root.otherPosture] + "了"
      : root.icons[root.posture] + "  " + root.minutesLeft + "m"
    active: root.alerting
    tooltipText: root.opened ? ""
      : root.alerting ? "该" + root.verbs[root.otherPosture] + "了，在遮罩上选下一个姿势"
      : root.verbs[root.posture] + "着 · 还有 " + root.minutesLeft + " 分钟（"
        + root.deadlineClock + " 该" + root.verbs[root.otherPosture] + "了）"
    onPressed: function(b) { root.toggle() }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(column.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onMoveRequested: function(dx, dy) {
        if (dx < 0) root.cursor = "sit"
        else if (dx > 0) root.cursor = "stand"
      }
      onActivateRequested: root.start(root.cursor)
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        Row {
          width: parent.width
          spacing: Style.space(14)

          Text {
            id: heroIcon
            textFormat: Text.PlainText
            text: root.icons[root.alerting ? root.otherPosture : root.posture]
            color: root.alerting ? root.urgent : root.fg
            font.family: root.fontFamily
            font.pixelSize: Style.font.display
            anchors.verticalCenter: parent.verticalCenter
          }

          Column {
            width: parent.width - heroIcon.width - parent.spacing
            anchors.verticalCenter: parent.verticalCenter
            spacing: Style.space(2)

            Text {
              textFormat: Text.PlainText
              text: root.alerting
                ? "该" + root.verbs[root.otherPosture] + "了"
                : root.verbs[root.posture] + "着"
              color: root.fg
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
            }

            Text {
              textFormat: Text.PlainText
              text: root.alerting
                ? "已经" + root.verbs[root.posture] + "了 " + root.minutesFor(root.posture) + " 分钟"
                : "还有 " + root.minutesLeft + " 分钟 · " + root.deadlineClock + " 提醒"
              color: root.dim
              font.family: root.fontFamily
              font.pixelSize: Style.font.bodySmall
            }
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          wrapMode: Text.Wrap
          text: root.alerting
            ? "现在开始坐还是开始站？选了就关掉遮罩，从头计时。"
            : "现在开始坐还是开始站？选了就从头计时。"
          color: root.fg
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
        }

        Row {
          id: actions
          width: parent.width
          spacing: Style.space(8)

          readonly property real cellWidth: (width - spacing) / 2

          Repeater {
            model: ["sit", "stand"]

            Button {
              required property string modelData
              width: actions.cellWidth
              iconText: root.icons[modelData]
              text: "开始" + root.verbs[modelData] + " · " + root.minutesFor(modelData) + " 分钟"
              fontSize: Style.font.bodySmall
              foreground: root.fg
              fontFamily: root.fontFamily
              bordered: true
              hasCursor: root.cursor === modelData
              onHovered: function(h) { if (h) root.cursor = modelData }
              onClicked: root.start(modelData)
            }
          }
        }

        Text {
          width: parent.width
          textFormat: Text.PlainText
          horizontalAlignment: Text.AlignHCenter
          text: "← → 选择 · Enter 确认 · Esc 取消"
          color: root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
        }
      }
    }
  }
}
