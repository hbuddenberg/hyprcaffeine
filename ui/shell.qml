import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Io

PanelWindow {
    id: root

    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors {
        top: true
        bottom: true
        left: true
        right: true
    }

    color: "#90000504"

    readonly property string homeDir: Quickshell.env("HOME") || ""
    readonly property string stateFilePath: homeDir + "/.cache/hyprcaffeine/state.json"
    readonly property string themeColorsPath: homeDir + "/.local/state/omarchy/current/theme/colors.toml"

    // Theme properties
    property color colBg: "#0b1110"
    property color colCard: "#141c1a"
    property color colCardSelected: "#1f2c29"
    property color colBorder: "#2a3632"
    property color colAccent: "#96b192"
    property color colFg: "#F8FDE6"
    property color colMuted: "#7a8280"
    property color colDanger: "#4a1e1e"
    property color colDangerFg: "#f38ba8"

    // State properties
    property string statusStr: "inactive"
    property int durationSec: 0
    property bool isMonitorOn: false
    property bool isLidOn: false
    property bool showCustomInput: false
    property string customInputVal: ""

    // Live theme reader
    FileView {
        id: themeReader
        path: root.themeColorsPath
        watchChanges: true
        onLoaded: {
            try {
                var txt = text();
                var mAccent = txt.match(/^accent\s*=\s*"([^"]+)"/m);
                if (mAccent && mAccent[1]) root.colAccent = mAccent[1];
                var mBg = txt.match(/^bg\s*=\s*"([^"]+)"/m);
                if (mBg && mBg[1]) root.colBg = mBg[1];
                var mFg = txt.match(/^fg\s*=\s*"([^"]+)"/m);
                if (mFg && mFg[1]) root.colFg = mFg[1];
                var mCard = txt.match(/^lighter_bg\s*=\s*"([^"]+)"/m);
                if (mCard && mCard[1]) root.colCard = mCard[1];
                var mBorder = txt.match(/^muted\s*=\s*"([^"]+)"/m);
                if (mBorder && mBorder[1]) root.colBorder = mBorder[1];
            } catch (e) {}
        }
    }

    // Live state reader
    function applyStateJson(txt) {
        try {
            if (!txt || txt.trim() === "") return;
            var s = JSON.parse(txt.trim());
            root.statusStr = s.status || "inactive";
            root.durationSec = s.duration || 0;
            root.isMonitorOn = !!s.monitor;
            root.isLidOn = !!s.lid;
        } catch (e) {}
    }

    Process {
        id: stateReaderProc
        command: ["cat", root.stateFilePath]
        stdout: SplitParser {
            onRead: function(line) {
                root.applyStateJson(line);
            }
        }
    }

    function reloadState() {
        if (!stateReaderProc.running) {
            stateReaderProc.running = true;
        }
    }

    Timer {
        id: modalStateTimer
        interval: 300
        running: true
        repeat: true
        onTriggered: root.reloadState()
    }

    Component.onCompleted: root.reloadState()

    Timer {
        id: closeTimer
        interval: 200
        repeat: false
        onTriggered: root.doClose()
    }

    function runAction(args, shouldClose) {
        Quickshell.execDetached(args);
        if (shouldClose) {
            closeTimer.start();
        }
    }

    function doClose() {
        Qt.quit();
    }

    function setPreset(val) {
        if (val === "custom") {
            root.showCustomInput = true;
            return;
        }
        runAction(["hyprcaffeine", "on", val], true);
    }

    function applyCustom() {
        if (root.customInputVal.trim() !== "") {
            runAction(["hyprcaffeine", "on", root.customInputVal.trim()], true);
        } else {
            root.doClose();
        }
    }

    function turnOff() {
        runAction(["hyprcaffeine", "off"], true);
    }

    function toggleMonitor() {
        runAction(["hyprcaffeine", "monitor", "toggle"], false);
    }

    function toggleLid() {
        runAction(["hyprcaffeine", "lid", "toggle"], false);
    }

    // Keyboard handlers
    FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onEscapePressed: root.doClose()
    }

    // Backdrop Click
    MouseArea {
        anchors.fill: parent
        onClicked: root.doClose()
    }

    // Main Card
    Rectangle {
        id: mainCard
        anchors.centerIn: parent
        width: 500
        height: root.showCustomInput ? 320 : 470
        radius: 4
        color: root.colBg
        border.color: root.colAccent
        border.width: 2

        MouseArea {
            anchors.fill: parent
            onClicked: {}
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 22
            spacing: 16

            // Header
            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                Rectangle {
                    width: 36
                    height: 36
                    radius: 4
                    color: root.colCard
                    border.color: root.colAccent
                    border.width: 1
                    Text {
                        anchors.centerIn: parent
                        text: "☕"
                        font.pixelSize: 18
                    }
                }

                ColumnLayout {
                    spacing: 2
                    Text {
                        text: "HyprCaffeine"
                        font.pixelSize: 17
                        font.bold: true
                        color: root.colFg
                    }
                    Text {
                        text: root.statusStr === "active" ? (root.durationSec === 0 ? "● Activo (Infinito)" : "● Activo (Temporizador)") : "○ Inactivo"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.statusStr === "active" ? root.colAccent : root.colMuted
                    }
                }

                Item { Layout.fillWidth: true }

                Rectangle {
                    width: 28
                    height: 28
                    radius: 4
                    color: closeHover.hovered ? "#30ffffff" : "transparent"
                    Text {
                        anchors.centerIn: parent
                        text: "✕"
                        font.pixelSize: 13
                        color: root.colMuted
                    }
                    HoverHandler { id: closeHover }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.doClose()
                    }
                }
            }

            // Separator
            Rectangle {
                Layout.fillWidth: true
                height: 1
                color: root.colBorder
            }

            // Custom Input View
            ColumnLayout {
                visible: root.showCustomInput
                Layout.fillWidth: true
                spacing: 12

                Text {
                    text: "DURACIÓN PERSONALIZADA"
                    font.pixelSize: 11
                    font.bold: true
                    color: root.colMuted
                }

                TextField {
                    id: customField
                    Layout.fillWidth: true
                    placeholderText: "Ejemplo: 45m, 1:30, 2h"
                    color: root.colFg
                    focus: root.showCustomInput
                    onTextChanged: root.customInputVal = text
                    onAccepted: root.applyCustom()
                    background: Rectangle {
                        color: root.colCard
                        border.color: customField.activeFocus ? root.colAccent : root.colBorder
                        border.width: 1
                        radius: 4
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Item { Layout.fillWidth: true }
                    Button {
                        text: "Volver"
                        onClicked: root.showCustomInput = false
                    }
                    Button {
                        text: "Activar"
                        highlighted: true
                        onClicked: root.applyCustom()
                    }
                }
            }

            // Standard View
            ColumnLayout {
                visible: !root.showCustomInput
                Layout.fillWidth: true
                spacing: 16

                // Presets
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "TEMPORIZADORES RÁPIDOS"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.colMuted
                    }

                    GridLayout {
                        Layout.fillWidth: true
                        columns: 3
                        rowSpacing: 8
                        columnSpacing: 8

                        Repeater {
                            model: [
                                { label: "15 min", val: "15m", icon: "󰔛" },
                                { label: "30 min", val: "30m", icon: "󰔛" },
                                { label: "1 hora", val: "1h", icon: "󰔛" },
                                { label: "2 horas", val: "2h", icon: "󰔛" },
                                { label: "Infinito", val: "infinite", icon: "" },
                                { label: "Custom...", val: "custom", icon: "󰔛" }
                            ]

                            delegate: Rectangle {
                                Layout.fillWidth: true
                                height: 38
                                radius: 4
                                color: btnPresetHover.hovered ? root.colCardSelected : root.colCard
                                border.color: btnPresetHover.hovered ? root.colAccent : root.colBorder
                                border.width: 1

                                RowLayout {
                                    anchors.centerIn: parent
                                    spacing: 6
                                    Text { text: modelData.icon; font.pixelSize: 13; color: root.colAccent }
                                    Text { text: modelData.label; font.pixelSize: 12; font.bold: true; color: root.colFg }
                                }

                                HoverHandler { id: btnPresetHover }
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: root.setPreset(modelData.val)
                                }
                            }
                        }
                    }
                }

                // Hardware Toggles
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: "OPCIONES DE HARDWARE"
                        font.pixelSize: 11
                        font.bold: true
                        color: root.colMuted
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10

                        // Monitor Toggle Box
                        Rectangle {
                            Layout.fillWidth: true
                            height: 46
                            radius: 4
                            color: root.colCard
                            border.color: root.isMonitorOn ? root.colAccent : root.colBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Text {
                                    text: "󰍹"
                                    font.pixelSize: 16
                                    color: root.isMonitorOn ? root.colAccent : root.colMuted
                                }

                                Text {
                                    text: "Pantalla ON"
                                    color: root.colFg
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }

                                Switch { checked: root.isMonitorOn; onToggled: root.toggleMonitor() }
                            }
                        }

                        // Lid Toggle Box
                        Rectangle {
                            Layout.fillWidth: true
                            height: 46
                            radius: 4
                            color: root.colCard
                            border.color: root.isLidOn ? root.colAccent : root.colBorder
                            border.width: 1

                            RowLayout {
                                anchors.fill: parent
                                anchors.leftMargin: 14
                                anchors.rightMargin: 14
                                spacing: 10

                                Text {
                                    text: "󰌢"
                                    font.pixelSize: 16
                                    color: root.isLidOn ? root.colAccent : root.colMuted
                                }

                                Text {
                                    text: "Bloqueo Tapa"
                                    color: root.colFg
                                    font.pixelSize: 12
                                    Layout.fillWidth: true
                                }

                                Switch { checked: root.isLidOn; onToggled: root.toggleLid() }
                            }
                        }
                    }
                }
            }

            Item { Layout.fillHeight: true }

            // Footer
            RowLayout {
                visible: !root.showCustomInput
                Layout.fillWidth: true
                spacing: 10

                // Turn Off button if active
                Rectangle {
                    visible: root.statusStr === "active"
                    Layout.fillWidth: true
                    height: 38
                    radius: 4
                    color: btnOffHover.hovered ? "#602424" : root.colDanger
                    border.color: root.colDangerFg
                    border.width: 1

                    RowLayout {
                        anchors.centerIn: parent
                        spacing: 6
                        Text { text: "󰤆"; font.pixelSize: 13; color: root.colDangerFg }
                        Text { text: "Desactivar Inactividad"; font.pixelSize: 12; font.bold: true; color: root.colDangerFg }
                    }

                    HoverHandler { id: btnOffHover }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.turnOff()
                    }
                }

                Item { visible: root.statusStr !== "active"; Layout.fillWidth: true }

                // Close Button
                Rectangle {
                    width: root.statusStr === "active" ? 100 : 120
                    height: 38
                    radius: 4
                    color: btnCloseHover.hovered ? "#222a28" : root.colCard
                    border.color: root.colBorder
                    border.width: 1

                    Text {
                        anchors.centerIn: parent
                        text: "Cerrar"
                        font.pixelSize: 12
                        color: root.colFg
                    }

                    HoverHandler { id: btnCloseHover }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: root.doClose()
                    }
                }
            }
        }
    }
}
