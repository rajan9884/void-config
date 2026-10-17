import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import QtQuick

// Generic bottom OSD for brightness / keyboard-backlight / mic.
// Trigger: qs ipc call sysosd notify "Title|0.75|75%"
// Colors come straight from Theme (bg carries bgAlpha), so SUPER+O
// opacity applies here with no extra syncing.
Scope {
    id: root

    property string title: ""
    property real progress: 0
    property string text: ""
    property bool showing: false

    readonly property int bottomGap: 110

    Timer {
        id: hideTimer
        interval: 1300
        onTriggered: root.showing = false
    }

    function displayOsd(title, progress, text) {
        root.title = String(title)
        var f = parseFloat(progress)
        root.progress = isNaN(f) ? 0 : Math.max(0, Math.min(1, f))
        root.text = (text === undefined || text === null) ? "" : String(text)
        root.showing = true
        hideTimer.restart()
    }

    // NOTE: `qs ipc call` in this quickshell version only forwards a
    // single argument, so callers pack everything into one payload:
    //   qs ipc call sysosd notify "Title|0.75|75%"
    function showPayload(payload) {
        var parts = String(payload).split("|")
        root.displayOsd(parts[0] ?? "", parts[1] ?? "0", parts.slice(2).join("|"))
    }

    IpcHandler {
        target: "sysosd"
        function notify(payload: string): void {
            root.showPayload(payload)
        }
    }

    PanelWindow {
        id: win

        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore

        WlrLayershell.layer: WlrLayer.Top
        WlrLayershell.namespace: "sysosd"
        WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

        mask: Region { item: root.showing ? card : null }

        Rectangle {
            id: card
            width: 320
            height: 56
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: root.bottomGap
            radius: 20
            color: Theme.bg
            border.width: 1
            border.color: Theme.alpha(Theme.text, 0.12)
            opacity: root.showing ? 1 : 0
            visible: opacity > 0
            scale: root.showing ? 1 : 0.94
            transformOrigin: Item.Bottom

            Behavior on opacity { NumberAnimation { duration: 150 } }
            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }

            Row {
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: 20
                anchors.rightMargin: 20
                spacing: 12

                Text {
                    width: 118
                    elide: Text.ElideRight
                    verticalAlignment: Text.AlignVCenter
                    text: root.title
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.text
                }

                Column {
                    width: parent.width - 118 - 52 - parent.spacing * 2
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 0

                    Rectangle {
                        width: parent.width
                        height: 5
                        radius: 4
                        color: Theme.alpha(Theme.text, 0.25)

                        Rectangle {
                            width: parent.width * root.progress
                            height: parent.height
                            radius: 4
                            color: Theme.text
                            Behavior on width { NumberAnimation { duration: 100 } }
                        }
                    }
                }

                Text {
                    width: 52
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    text: root.text
                    font.pixelSize: 12
                    font.bold: true
                    color: Theme.text
                }
            }
        }
    }
}
