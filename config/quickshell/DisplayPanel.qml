pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Standalone display panel. Reuses SettingsPages/DisplayPage.
// IPC: qs ipc call display toggle|show|hide
Scope {
    id: root
    property bool showing: false
    property bool mounted: false
    property var targetScreen: Quickshell.screens[0]

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            unmountTimer.restart()
        }
    }
    Timer { id: unmountTimer; interval: 200; onTriggered: root.mounted = false }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.targetScreen = scr
        }
        root.showing = true
    }
    function closeMenu() { root.showing = false }
    function toggleMenu() { root.showing ? root.closeMenu() : root.openMenu() }

    IpcHandler {
        target: "display"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
    }

    LazyLoader {
        active: root.mounted
        PanelWindow {
            id: win
            screen: root.targetScreen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "display"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region { item: root.showing ? card : null }

            Component.onCompleted: card.forceActiveFocus()

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeMenu()
            }

            Rectangle {
                id: card
                width: Math.min(640, parent.width - 80)
                height: Math.min(560, parent.height - 80)
                anchors.centerIn: parent
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: Theme.accent
                focus: true
                Keys.onEscapePressed: root.closeMenu()
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Q) { root.closeMenu(); event.accepted = true }
                    else if (event.key === Qt.Key_J || event.key === Qt.Key_Down) { pageFlick.flick(0, -240); event.accepted = true }
                    else if (event.key === Qt.Key_K || event.key === Qt.Key_Up) { pageFlick.flick(0, 240); event.accepted = true }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12
                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - 40
                            text: "DISPLAY"
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            font.bold: true
                            font.letterSpacing: 3
                        }
                        Text {
                            text: "×"
                            color: Theme.textDim
                            font.pixelSize: 18
                            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.closeMenu() }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.border }
                    Item {
                        width: parent.width
                        height: parent.height - 80
                        clip: true
                        Flickable {
                            id: pageFlick
                            anchors.fill: parent
                            contentWidth: width
                            contentHeight: pageLoader.implicitHeight > 0 ? pageLoader.implicitHeight : pageLoader.height
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            Loader {
                                id: pageLoader
                                width: pageFlick.width
                                height: pageFlick.height
                                source: "SettingsPages/DisplayPage.qml"
                            }
                        }
                    }
                    Text {
                        text: "esc/q close · j/k scroll"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
