pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Settings center: one window hosting the panel pages (audio, bluetooth,
// display, network) plus the power profile page. Each page section is also
// reachable as its own quick-slice panel; this is the "control center"
// entry (Wheel → Settings, `qs ipc call settings …`).
// IPC: qs ipc call settings toggle|show|hide
//      qs ipc call settings page audio|bluetooth|display|network|power
Scope {
    id: root
    property bool showing: false
    property bool mounted: false
    property var targetScreen: Quickshell.screens[0]
    property int pageIndex: 2 // DISPLAY
    readonly property var pages: [
        { id: "audio",     label: "AUDIO",     src: "SettingsPages/AudioPage.qml" },
        { id: "bluetooth", label: "BLUETOOTH", src: "SettingsPages/BluetoothPage.qml" },
        { id: "display",   label: "DISPLAY",   src: "SettingsPages/DisplayPage.qml" },
        { id: "network",   label: "NETWORK",   src: "SettingsPages/NetworkPage.qml" },
        { id: "power",     label: "POWER",     src: "SettingsPages/PowerPage.qml" }
    ]
    readonly property var current: pages[Math.max(0, Math.min(pages.length - 1, pageIndex))]

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
            // Loader item appears a frame after mount — refresh once ready
            refreshPage()
        } else {
            unmountTimer.restart()
        }
    }
    Timer { id: unmountTimer; interval: 200; onTriggered: root.mounted = false }
    signal refreshPage()

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
    function showPage(id) {
        var idx = root.pages.findIndex(function (p) { return p.id === id })
        if (idx < 0) idx = 2
        root.pageIndex = idx
        root.openMenu()
        root.refreshPage()
    }

    IpcHandler {
        target: "settings"
        function toggle(): void { root.toggleMenu() }
        function open(): void { root.openMenu() }
        function show(): void { root.openMenu() } // NOTE: unreachable via the qs CLI (subcommand clash); use `open`
        function hide(): void { root.closeMenu() }
        function page(target: string): void { root.showPage(target) }
        function audio(): void { root.showPage("audio") }
        function bluetooth(): void { root.showPage("bluetooth") }
        function display(): void { root.showPage("display") }
        function network(): void { root.showPage("network") }
        function power(): void { root.showPage("power") }
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
            WlrLayershell.namespace: "settings"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region { item: root.showing ? card : null }

            Component.onCompleted: card.forceActiveFocus()

            MouseArea {
                anchors.fill: parent
                onClicked: root.closeMenu()
            }

            Rectangle {
                id: card
                width: Math.min(700, parent.width - 80)
                height: Math.min(580, parent.height - 80)
                anchors.centerIn: parent
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: Theme.accent
                focus: true
                Keys.onEscapePressed: root.closeMenu()
                Keys.onPressed: function (event) {
                    if (event.key === Qt.Key_Q) { root.closeMenu(); event.accepted = true }
                    else if (event.key === Qt.Key_Tab) {
                        if (event.modifiers & Qt.ShiftModifier) root.pageIndex = (root.pageIndex - 1 + root.pages.length) % root.pages.length
                        else root.pageIndex = (root.pageIndex + 1) % root.pages.length
                        root.refreshPage()
                        event.accepted = true
                    }
                }

                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12

                    Row {
                        width: parent.width
                        Text {
                            width: parent.width - 40
                            text: "SETTINGS"
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

                    // ── Tab bar ─────────────────────────────────────────
                    Row {
                        width: parent.width
                        spacing: 4

                        Repeater {
                            model: root.pages

                            delegate: Item {
                                id: tab
                                required property var modelData
                                required property int index
                                readonly property bool active: root.pageIndex === index
                                width: tabText.width + 18
                                height: 30

                                Text {
                                    id: tabText
                                    anchors.centerIn: parent
                                    text: tab.modelData.label
                                    color: tab.active ? Theme.accent : Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    font.bold: tab.active
                                }
                                Rectangle {
                                    width: tabText.width
                                    height: 2
                                    radius: 1
                                    anchors.horizontalCenter: tabText.horizontalCenter
                                    anchors.bottom: parent.bottom
                                    color: tab.active ? Theme.accent : "transparent"
                                    Behavior on color { ColorAnimation { duration: Theme.animFast } }
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (root.pageIndex === tab.index) return
                                        root.pageIndex = tab.index
                                        root.refreshPage()
                                    }
                                }
                            }
                        }
                    }

                    Rectangle { width: parent.width; height: 1; color: Theme.border }

                    // ── Page body ───────────────────────────────────────
                    Item {
                        width: parent.width
                        height: parent.height - 30 - 30 - 24 - 1
                        clip: true

                        Timer {
                            id: pageRefreshTimer
                            interval: 350
                            repeat: false
                            onTriggered: if (pageLoader.item && pageLoader.item.refresh) pageLoader.item.refresh()
                        }
                        Connections {
                            target: root
                            function onRefreshPage(): void { pageRefreshTimer.restart() }
                        }

                        Loader {
                            id: pageLoader
                            anchors.fill: parent
                            source: root.current.src
                        }
                    }

                    Text {
                        text: "esc/q close · Tab switch page"
                        color: Theme.textFaint
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                    }
                }
            }
        }
    }
}
