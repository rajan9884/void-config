pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

// Emoji picker with keyword search + arrow navigation.
// IPC: qs ipc call emoji toggle|show|hide
Scope {
    id: root
    property bool showing: false
    property bool mounted: false
    property var targetScreen: Quickshell.screens[0]
    property string query: ""
    property int selected: 0
    readonly property var allEmoji: [
        { e: "😀", n: "grinning smile happy face" },
        { e: "😁", n: "grin smile happy teeth" },
        { e: "😂", n: "laugh tears joy lol funny" },
        { e: "🤣", n: "laugh rofl rolling funny" },
        { e: "😊", n: "smile blush happy" },
        { e: "😍", n: "love heart eyes crush" },
        { e: "😎", n: "cool sunglasses" },
        { e: "🤔", n: "thinking hmm" },
        { e: "😐", n: "neutral meh" },
        { e: "🙄", n: "eyeroll annoyed" },
        { e: "😴", n: "sleep tired snore" },
        { e: "🤯", n: "mindblown shock explode" },
        { e: "🥳", n: "party celebrate birthday" },
        { e: "😭", n: "cry sob tears sad" },
        { e: "😡", n: "angry rage red mad" },
        { e: "👍", n: "thumbsup yes like approve" },
        { e: "👎", n: "thumbsdown no dislike" },
        { e: "👏", n: "clap applause" },
        { e: "🙏", n: "pray thanks please" },
        { e: "💪", n: "muscle strong flex" },
        { e: "👀", n: "eyes look watch" },
        { e: "🔥", n: "fire hot lit" },
        { e: "✨", n: "sparkles shiny new" },
        { e: "🎉", n: "party tada celebrate" },
        { e: "❤️", n: "red heart love" },
        { e: "💔", n: "broken heart breakup" },
        { e: "✅", n: "check yes done ok" },
        { e: "❌", n: "cross no wrong x" },
        { e: "⚠️", n: "warning caution" },
        { e: "💡", n: "idea bulb light" },
        { e: "🚀", n: "rocket launch ship" },
        { e: "🐧", n: "penguin linux tux" },
        { e: "🍕", n: "pizza food" },
        { e: "☕", n: "coffee tea drink" },
        { e: "🌙", n: "moon night" },
        { e: "☀️", n: "sun day sunny" },
        { e: "🌧️", n: "rain weather" },
        { e: "❄️", n: "snow winter cold" },
        { e: "🎵", n: "music note song" },
        { e: "🎮", n: "game controller gaming" },
        { e: "📁", n: "folder file" },
        { e: "📝", n: "memo write note pencil" },
        { e: "🔒", n: "lock secure private" },
        { e: "🔓", n: "unlock open" },
        { e: "⚙️", n: "gear settings config" },
        { e: "💻", n: "laptop computer code" },
        { e: "🖥️", n: "desktop monitor pc" },
        { e: "⌨️", n: "keyboard type" },
        { e: "🖱️", n: "mouse click" },
        { e: "📱", n: "phone mobile" },
        { e: "➡️", n: "arrow right next" },
        { e: "⬅️", n: "arrow left back" },
        { e: "⬆️", n: "arrow up" },
        { e: "⬇️", n: "arrow down" },
        { e: "©️", n: "copyright" },
        { e: "®️", n: "registered" },
        { e: "™️", n: "trademark tm" },
        { e: "‼️", n: "exclamation bang" },
        { e: "⁉️", n: "question exclamation" },
        { e: "💯", n: "hundred 100 perfect" },
        { e: "🥺", n: "pleading puppy cute" },
        { e: "😅", n: "sweat laugh nervous" },
        { e: "🙃", n: "upside down silly" },
        { e: "😇", n: "angel halo innocent" },
        { e: "🤖", n: "robot bot" },
        { e: "👻", n: "ghost spooky" },
        { e: "💀", n: "skull dead" },
        { e: "🐱", n: "cat kitty meow" },
        { e: "🐶", n: "dog puppy woof" },
        { e: "🦀", n: "crab ferris rust" }
    ]
    property var filtered: {
        var q = root.query.toLowerCase().trim()
        if (q === "") return root.allEmoji.slice(0, 45)
        var out = []
        for (var i = 0; i < root.allEmoji.length; i++) {
            var item = root.allEmoji[i]
            if (item.n.indexOf(q) >= 0 || item.e.indexOf(root.query) >= 0) out.push(item)
        }
        return out.slice(0, 45)
    }

    onShowingChanged: { if (showing) { unmountTimer.stop(); mounted = true; root.query = ""; root.selected = 0 } else unmountTimer.restart() }
    Timer { id: unmountTimer; interval: 200; onTriggered: root.mounted = false }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) { var scr = Quickshell.screens.find(function(s) { return s.name === mon.name }); if (scr) root.targetScreen = scr }
        root.showing = true
    }
    function closeMenu() { root.showing = false }
    function toggleMenu() { root.showing ? root.closeMenu() : root.openMenu() }

    IpcHandler {
        target: "emoji"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
    }

    Process { id: pCopy }
    function copyEmoji(e) {
        pCopy.command = ["sh", "-c", "printf '%s' '" + e + "' | wl-copy"]
        pCopy.running = true
        root.closeMenu()
    }

    LazyLoader {
        active: root.mounted
        PanelWindow {
            screen: root.targetScreen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "emoji"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region { item: root.showing ? card : null }
            // Re-focus search on EVERY open (Component.onCompleted runs once only).
            // Without this the user must click the text area first.
            Timer {
                id: focusTimer
                interval: 80
                repeat: false
                onTriggered: { searchField.text = ""; searchField.forceActiveFocus() }
            }
            Connections {
                target: root
                function onShowingChanged() { if (root.showing) focusTimer.restart() }
            }
            Component.onCompleted: { if (root.showing) focusTimer.restart() }
            MouseArea { anchors.fill: parent; onClicked: root.closeMenu() }
            Rectangle {
                id: card
                width: Math.min(520, parent.width - 80)
                height: Math.min(460, parent.height - 80)
                anchors.centerIn: parent
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: Theme.accent
                focus: true
                Keys.onEscapePressed: root.closeMenu()
                // Fallback: if focus lands on card instead of search, arrows still work
                // and typing jumps into search.
                Keys.onPressed: function(event) {
                    var cols = 9
                    var n = root.filtered.length
                    if (n <= 0) return
                    if (event.key === Qt.Key_Right) { root.selected = (root.selected + 1) % n; grid.positionViewAtIndex(root.selected, GridView.Visible); searchField.forceActiveFocus(); event.accepted = true }
                    else if (event.key === Qt.Key_Left) { root.selected = (root.selected - 1 + n) % n; grid.positionViewAtIndex(root.selected, GridView.Visible); searchField.forceActiveFocus(); event.accepted = true }
                    else if (event.key === Qt.Key_Down) { root.selected = (root.selected + cols) % n; grid.positionViewAtIndex(root.selected, GridView.Visible); searchField.forceActiveFocus(); event.accepted = true }
                    else if (event.key === Qt.Key_Up) { root.selected = (root.selected - cols + n) % n; grid.positionViewAtIndex(root.selected, GridView.Visible); searchField.forceActiveFocus(); event.accepted = true }
                    else if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) { searchField.forceActiveFocus(); /* let search handle it */ }
                }
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    Text { text: "EMOJI"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true; font.letterSpacing: 3 }
                    Rectangle { width: parent.width; height: 1; color: Theme.border }
                    Item {
                        width: parent.width
                        height: 24
                        TextInput {
                            id: searchField
                            anchors.fill: parent
                            color: Theme.text
                            font.family: Theme.fontFamily
                            font.pixelSize: 15
                            focus: true
                            // NOTE: no `text: root.query` binding — that breaks typing
                            // (binding loop resets cursor). We push text -> query only.
                            onTextChanged: { root.query = text; root.selected = 0 }
                            Keys.onPressed: function(event) {
                                var cols = 9
                                var n = root.filtered.length
                                if (event.key === Qt.Key_Right) { if (n > 0) root.selected = (root.selected + 1) % n; grid.positionViewAtIndex(root.selected, GridView.Visible); event.accepted = true }
                                else if (event.key === Qt.Key_Left) { if (n > 0) root.selected = (root.selected - 1 + n) % n; grid.positionViewAtIndex(root.selected, GridView.Visible); event.accepted = true }
                                else if (event.key === Qt.Key_Down) { if (n > 0) root.selected = (root.selected + cols) % n; grid.positionViewAtIndex(root.selected, GridView.Visible); event.accepted = true }
                                else if (event.key === Qt.Key_Up) { if (n > 0) root.selected = (root.selected - cols + n) % n; grid.positionViewAtIndex(root.selected, GridView.Visible); event.accepted = true }
                                else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { if (root.filtered.length > 0) root.copyEmoji(root.filtered[Math.min(root.selected, root.filtered.length - 1)].e); event.accepted = true }
                                else if (event.key === Qt.Key_Escape) { root.closeMenu(); event.accepted = true }
                                else if (event.key === Qt.Key_Tab) { if (n > 0) root.selected = (root.selected + 1) % n; event.accepted = true }
                            }
                        }
                        Text {
                            anchors.fill: parent
                            visible: searchField.text === ""
                            text: "type name: fire, heart, rocket, cat..."
                            color: Theme.textFaint
                            font.family: Theme.fontFamily
                            font.pixelSize: 14
                        }
                    }
                    Text {
                        visible: root.filtered.length > 0 && root.selected < root.filtered.length
                        text: root.filtered.length > 0 ? root.filtered[Math.min(root.selected, root.filtered.length - 1)].n : ""
                        color: Theme.accent
                        font.family: Theme.fontFamily
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        width: parent.width
                    }
                    GridView {
                        id: grid
                        width: parent.width
                        height: parent.height - 170
                        clip: true
                        cellWidth: 48
                        cellHeight: 48
                        model: root.filtered
                        currentIndex: root.selected
                        highlightFollowsCurrentItem: true
                        delegate: Rectangle {
                            required property var modelData
                            required property int index
                            width: 44
                            height: 44
                            radius: 8
                            color: index === root.selected ? Theme.alpha(Theme.accent, 0.15) : "transparent"
                            border.width: 1
                            border.color: index === root.selected ? Theme.accent : Theme.border
                            Text { anchors.centerIn: parent; text: modelData.e; font.pixelSize: 22 }
                            MouseArea {
                                anchors.fill: parent
                                hoverEnabled: true
                                onEntered: root.selected = index
                                onClicked: root.copyEmoji(modelData.e)
                            }
                        }
                    }
                    Text { text: "type to search · ←→↑↓ navigate · enter copies · esc close"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10 }
                }
            }
        }
    }
}
