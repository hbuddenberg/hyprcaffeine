import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "hyprcaffeine"

  readonly property string homeDir: Quickshell.env("HOME") || ""
  readonly property string stateFilePath: homeDir + "/.cache/hyprcaffeine/state.json"

  property string statusStr: "inactive"
  property int durationSec: 0
  property int activatedAt: 0
  property bool isMonitorOn: false
  property bool isLidOn: false

  property string timerText: ""
  property string tooltipStr: "☕ Caffeine: Inactivo"
  readonly property bool isIdleActive: statusStr === "active"
  readonly property bool isAnyActive: isIdleActive || isMonitorOn || isLidOn

  function applyStateJson(txt) {
    try {
      if (!txt || txt.trim() === "") return;
      var s = JSON.parse(txt.trim());
      root.statusStr = s.status || "inactive";
      root.durationSec = s.duration || 0;
      root.activatedAt = parseInt(s.activated_at || "0") || Math.floor(Date.now() / 1000);
      root.isMonitorOn = !!s.monitor;
      root.isLidOn = !!s.lid;
      root.updateTimer();
    } catch (e) {}
  }

  function updateTimer() {
    if (root.isIdleActive && root.durationSec > 0) {
      var elapsed = Math.floor(Date.now() / 1000) - root.activatedAt;
      var remaining = Math.max(0, root.durationSec - elapsed);
      var mins = Math.floor(remaining / 60);
      var secs = remaining % 60;
      root.timerText = mins + ":" + (secs < 10 ? "0" : "") + secs;
    } else {
      root.timerText = "";
    }

    var tip = [];
    if (root.isIdleActive) {
      if (root.durationSec === 0) {
        tip.push("☕ Modo Infinito");
      } else {
        tip.push("󰔛 Temporizador: " + root.timerText);
      }
    } else {
      tip.push("☕ Inactivo");
    }
    if (root.isMonitorOn) tip.push("󰍹 Pantalla: ON");
    if (root.isLidOn) tip.push("󰌢 Tapa: Bloqueada");
    root.tooltipStr = tip.join(" | ");
  }

  Process {
    id: statePoller
    command: ["cat", root.stateFilePath]
    stdout: SplitParser {
      onRead: function(line) {
        root.applyStateJson(line);
      }
    }
  }

  function pollState() {
    if (!statePoller.running) {
      statePoller.running = true;
    }
  }

  // 1-second interval for real-time countdown & state sync from disk
  Timer {
    id: countdownTimer
    interval: 1000
    running: true
    repeat: true
    onTriggered: {
      root.pollState();
      root.updateTimer();
    }
  }

  // Fast poll timer for immediate response to clicks
  Timer {
    id: fastPollTimer
    interval: 150
    repeat: false
    onTriggered: root.pollState()
  }

  Component.onCompleted: root.pollState()

  implicitWidth: container.implicitWidth + 14
  implicitHeight: root.bar ? root.bar.barSize : 26

  Rectangle {
    id: container
    anchors.centerIn: parent
    implicitHeight: parent.height
    implicitWidth: row.implicitWidth + 12
    color: mouseArea.containsMouse ? (root.bar ? "#18ffffff" : "#202a28") : "transparent"
    radius: 4

    RowLayout {
      id: row
      anchors.centerIn: parent
      spacing: 6

      // Coffee Cup Icon (Always rendered!)
      Text {
        text: root.isIdleActive ? "󰅶" : "󰛊"
        font.pixelSize: 14
        font.family: root.bar ? root.bar.fontFamily : "monospace"
        color: root.isIdleActive
               ? (root.durationSec === 0 ? "#f9e2af" : "#fab387")
               : (root.isAnyActive ? "#a6e3a1" : (root.bar ? "#7a8280" : "#6c7086"))
      }

      // Infinite Symbol (Nerd Font nf-md-infinity)
      Text {
        visible: root.isIdleActive && root.durationSec === 0
        text: "󰛤"
        font.pixelSize: 14
        font.family: root.bar ? root.bar.fontFamily : "monospace"
        color: "#f9e2af"
      }

      // Timer Countdown Text (MM:SS)
      Text {
        visible: root.isIdleActive && root.durationSec > 0 && root.timerText !== ""
        text: root.timerText
        font.pixelSize: 11
        font.bold: true
        font.family: root.bar ? root.bar.fontFamily : "monospace"
        color: "#fab387"
      }

      // Monitor Icon (if ON)
      Text {
        visible: root.isMonitorOn
        text: "󰍹"
        font.pixelSize: 13
        color: "#94e2d5"
      }

      // Lid Icon (if ON)
      Text {
        visible: root.isLidOn
        text: "󰌢"
        font.pixelSize: 13
        color: "#cba6f7"
      }
    }

    MouseArea {
      id: mouseArea
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor

      onEntered: {
        if (root.bar) root.bar.showTooltip(root, root.tooltipStr)
      }
      onExited: {
        if (root.bar) root.bar.hideTooltip(root)
      }
      onClicked: function(mouse) {
        if (!root.bar) return
        if (mouse.button === Qt.RightButton) {
          root.bar.run("hyprcaffeine toggle")
        } else if (mouse.button === Qt.MiddleButton) {
          root.bar.run("hyprcaffeine monitor toggle")
        } else {
          root.bar.run("hyprcaffeine menu")
        }
        fastPollTimer.start()
      }
    }
  }
}
