pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Keybind cheatsheet via `hyprctl binds -j`.
// Format: SUPER + K --> description  (big readable rows)
// IPC: qs ipc call cheatsheet toggle|show|hide
Scope {
    id: root
    property bool showing: false
    property bool mounted: false
    property var targetScreen: Quickshell.screens[0]
    property string query: ""
    property var binds: []
    property int selected: 0

    // Fresh start on every open: query + selection reset, list back to top.
    onShowingChanged: { if (showing) { unmountTimer.stop(); mounted = true; root.query = ""; root.selected = 0; pBinds.running = true } else unmountTimer.restart() }
    Timer { id: unmountTimer; interval: 200; onTriggered: root.mounted = false }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) { var scr = Quickshell.screens.find(function(s) { return s.name === mon.name }); if (scr) root.targetScreen = scr }
        root.showing = true
    }
    function closeMenu() { root.showing = false }
    function toggleMenu() { root.showing ? root.closeMenu() : root.openMenu() }

    IpcHandler {
        target: "cheatsheet"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
    }

    function modStr(mask) {
        mask = Number(mask) || 0
        var parts = []
        if (mask & 64) parts.push("SUPER")
        if (mask & 4) parts.push("CTRL")
        if (mask & 8) parts.push("ALT")
        if (mask & 1) parts.push("SHIFT")
        return parts.join(" + ")
    }

    function prettyKey(k) {
        if (!k) return ""
        if (k === "Return") return "Enter"
        if (k === "Space") return "Space"
        if (k.indexOf("mouse:272") >= 0) return "LeftClick"
        if (k.indexOf("mouse:273") >= 0) return "RightClick"
        if (k.indexOf("mouse_down") >= 0) return "WheelDown"
        if (k.indexOf("mouse_up") >= 0) return "WheelUp"
        if (k.indexOf("XF86") === 0) return k.replace("XF86", "")
        return k
    }

    Process {
        id: pBinds
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    var arr = JSON.parse(text)
                    var out = []
                    for (var i = 0; i < arr.length; i++) {
                        var b = arr[i]
                        if (!b.description || b.description === "") continue
                        var mods = root.modStr(b.modmask)
                        var key = root.prettyKey(b.key || "")
                        var combo = (mods ? mods + " + " : "") + key
                        out.push({ key: combo, desc: b.description })
                    }
                    // sort: SUPER binds first, then alphabetical
                    out.sort(function(a, b) {
                        var as = a.key.indexOf("SUPER") === 0 ? 0 : 1
                        var bs = b.key.indexOf("SUPER") === 0 ? 0 : 1
                        if (as !== bs) return as - bs
                        return a.key < b.key ? -1 : (a.key > b.key ? 1 : 0)
                    })
                    root.binds = out
                    if (root.selected >= out.length) root.selected = 0
                } catch (e) { root.binds = [] }
            }
        }
    }

    property var filtered: root.binds.filter(function(b) {
        if (root.query === "") return true
        var q = root.query.toLowerCase()
        return b.key.toLowerCase().indexOf(q) >= 0 || b.desc.toLowerCase().indexOf(q) >= 0
    }).slice(0, 240)

    LazyLoader {
        active: root.mounted
        PanelWindow {
            screen: root.targetScreen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "cheatsheet"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region { item: root.showing ? card : null }
            // Re-focus search on EVERY open (Component.onCompleted runs once only).
            // Field always starts empty — the list shows every current bind from
            // top (fresh read of `hyprctl binds -j` on each open; nothing cached).
            Timer {
                id: focusTimer
                interval: 80
                repeat: false
                onTriggered: { searchField.text = ""; searchField.forceActiveFocus(); bindList.positionViewAtIndex(root.selected, ListView.Visible) }
            }
            // Binds reload async after open — re-anchor once they land.
            Timer {
                id: restoreTimer
                interval: 350
                repeat: false
                onTriggered: { if (root.showing) bindList.positionViewAtIndex(root.selected, ListView.Visible) }
            }
            Connections {
                target: root
                function onShowingChanged() { if (root.showing) { focusTimer.restart(); restoreTimer.restart() } }
            }
            Component.onCompleted: { if (root.showing) focusTimer.restart() }
            MouseArea { anchors.fill: parent; onClicked: root.closeMenu() }
            Rectangle {
                id: card
                width: Math.min(960, parent.width - 80)
                height: Math.min(640, parent.height - 80)
                anchors.centerIn: parent
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: Theme.accent
                focus: true
                Keys.onEscapePressed: root.closeMenu()
                Keys.onPressed: function(event) {
                    var n = root.filtered.length
                    if (n <= 0) return
                    if (event.key === Qt.Key_Down || event.key === Qt.Key_J) { root.selected = (root.selected + 1) % n; bindList.positionViewAtIndex(root.selected, ListView.Visible); event.accepted = true }
                    else if (event.key === Qt.Key_Up || event.key === Qt.Key_K) { root.selected = (root.selected - 1 + n) % n; bindList.positionViewAtIndex(root.selected, ListView.Visible); event.accepted = true }
                }
                Column {
                    anchors.fill: parent
                    anchors.margins: 20
                    spacing: 12
                    Text { text: "KEYBINDS  (" + root.filtered.length + ")"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 18; font.bold: true; font.letterSpacing: 2 }
                    Rectangle { width: parent.width; height: 1; color: Theme.border }
                    Item {
                        width: parent.width
                        height: 28
                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 16
                            focus: true
                            onTextChanged: { if (text !== root.query) { root.query = text; root.selected = 0 } }
                            Keys.onPressed: function(event) {
                                var n = root.filtered.length
                                if (event.key === Qt.Key_Escape) { root.closeMenu(); event.accepted = true }
                                else if (event.key === Qt.Key_Down) { if (n > 0) { root.selected = (root.selected + 1) % n; bindList.positionViewAtIndex(root.selected, ListView.Visible); } event.accepted = true }
                                else if (event.key === Qt.Key_Up) { if (n > 0) { root.selected = (root.selected - 1 + n) % n; bindList.positionViewAtIndex(root.selected, ListView.Visible); } event.accepted = true }
                                else if (event.key === Qt.Key_PageDown) { if (n > 0) { root.selected = (root.selected + 10) % n; bindList.positionViewAtIndex(root.selected, ListView.Visible); } event.accepted = true }
                                else if (event.key === Qt.Key_PageUp) { if (n > 0) { root.selected = (root.selected - 10 + n) % n; bindList.positionViewAtIndex(root.selected, ListView.Visible); } event.accepted = true }
                            }
                        }
                        Text {
                            anchors.fill: parent
                            visible: searchField.text === ""
                            text: "Filter: browser, volume, workspace..."
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                        }
                    }
                    ListView {
                        id: bindList
                        width: parent.width
                        height: parent.height - 150
                        clip: true
                        model: root.filtered
                        currentIndex: root.selected
                        highlightFollowsCurrentItem: true
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: ListView.view.width
                            height: 38
                            radius: 6
                            color: index === root.selected ? Theme.alpha(Theme.accent, 0.08) : "transparent"
                            Row {
                                anchors.fill: parent
                                anchors.leftMargin: 4
                                anchors.rightMargin: 4
                                spacing: 8
                                Text {
                                    width: 340
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.key
                                    color: Theme.accent
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                    elide: Text.ElideRight
                                }
                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "-->"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    font.bold: true
                                }
                                Text {
                                    width: parent.width - 340 - 40 - 16
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: modelData.desc
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 14
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                    Text { text: "type to filter · ↑↓/PgUpPgDn navigate · esc close"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 11 }
                }
            }
        }
    }
}
