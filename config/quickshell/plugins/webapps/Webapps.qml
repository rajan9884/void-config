pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."

// Web apps: install/remove .desktop launchers without a terminal.
// Install and remove run the existing ~/bin backends by argv (they already
// validate names, URLs and .desktop escaping); this file only renders.
// IPC: qs ipc call webapps toggle|show|hide|install|remove
Scope {
    id: root
    property bool showing: false
    property bool mounted: false
    property var targetScreen: Quickshell.screens[0]
    property string mode: "install"
    property string appName: ""
    property string appUrl: ""
    property string appIcon: ""
    property string error: ""
    property string log: ""
    property var applist: []
    property int selected: 0
    property bool removeArmed: false

    readonly property string binDir: Quickshell.env("HOME") + "/.local/bin"
    readonly property string appsDir: Quickshell.env("HOME") + "/.local/share/applications"

    onShowingChanged: {
        if (showing) { unmountTimer.stop(); mounted = true; root.error = ""; root.log = ""; root.removeArmed = false; if (root.mode === "remove") pList.running = true }
        else unmountTimer.restart()
    }
    Timer { id: unmountTimer; interval: 200; onTriggered: root.mounted = false }

    function openMenu(m) {
        var mon = Hyprland.focusedMonitor
        if (mon) { var scr = Quickshell.screens.find(function(s) { return s.name === mon.name }); if (scr) root.targetScreen = scr }
        if (m === "install" || m === "remove") root.mode = m
        root.showing = true
    }
    function closeMenu() { root.showing = false }
    function toggleMenu() { root.showing ? root.closeMenu() : root.openMenu() }

    IpcHandler {
        target: "webapps"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
        function install(): void { root.openMenu("install") }
        function remove(): void { root.openMenu("remove") }
    }

    function say(s) { root.log = (root.log ? root.log + "\n" : "") + s }

    // ---------- install ----------
    Process {
        id: pInstall
        stdout: StdioCollector { onStreamFinished: { root.say(text.trim()); root.say("Find it with the app launcher (SUPER + SPACE).") } }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) { root.error = text.trim().split("\n")[0]; root.say(text.trim()) } } }
        onExited: function(code) { if (code !== 0 && !root.error) root.error = "Install failed (exit " + code + ")." }
    }
    function doInstall() {
        root.error = ""
        var name = root.appName.trim()
        var url = root.appUrl.trim()
        if (!name) { root.error = "Name is required."; return }
        if (name.indexOf("/") >= 0) { root.error = "App name cannot contain '/'."; return }
        if (!url) { root.error = "URL is required."; return }
        root.log = ""
        root.say("$ webapp-install " + name)
        pInstall.command = [root.binDir + "/webapp-install", name, url, root.appIcon.trim()]
        pInstall.running = true
    }

    // ---------- remove ----------
    Process {
        id: pList
        command: [root.binDir + "/webapp-remove", "--list"]
        stdout: StdioCollector {
            onStreamFinished: {
                root.applist = text.trim() ? text.trim().split("\n") : []
                root.selected = 0
                root.removeArmed = false
            }
        }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) root.error = text.trim().split("\n")[0] } }
        onExited: function(code) { if (code !== 0 && !root.error) root.error = "Could not list web apps (exit " + code + ")." }
    }
    Process {
        id: pRemove
        stdout: StdioCollector { onStreamFinished: { if (text.trim()) root.say(text.trim()) } }
        stderr: StdioCollector { onStreamFinished: { if (text.trim()) root.say(text.trim()) } }
        onExited: function(code) { if (code === 0) { root.say("Removed."); pList.running = true } else root.error = "Remove failed (exit " + code + ")." }
    }
    function doRemove() {
        if (root.applist.length === 0) return
        var name = root.applist[Math.min(root.selected, root.applist.length - 1)]
        if (!root.removeArmed) { root.removeArmed = true; return }
        root.removeArmed = false
        root.error = ""
        root.say("$ webapp-remove " + name)
        pRemove.command = [root.binDir + "/webapp-remove", name]
        pRemove.running = true
    }
    property string selectedDesktop: root.mode === "remove" && root.applist.length > 0 ? root.appsDir + "/" + root.applist[Math.min(root.selected, root.applist.length - 1)] + ".desktop" : ""
    FileView {
        id: desktopFile
        path: root.selectedDesktop
        printErrors: false
        onLoaded: { var d = root.parseDesktop(text()); detailUrl = d.url; detailIcon = d.icon }
        onLoadFailed: { detailUrl = ""; detailIcon = "" }
    }
    property string detailUrl: ""
    property string detailIcon: ""
    function parseDesktop(text) {
        var url = "", icon = ""
        var lines = String(text || "").split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (lines[i].indexOf("Exec=") === 0) { var m = /"([^"]+)"/.exec(lines[i]); if (m) url = m[1] }
            else if (lines[i].indexOf("Icon=") === 0) icon = lines[i].slice(5)
        }
        return { url: url, icon: icon }
    }

    LazyLoader {
        active: root.mounted
        PanelWindow {
            screen: root.targetScreen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "webapps"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region { item: root.showing ? card : null }
            MouseArea { anchors.fill: parent; onClicked: root.closeMenu() }
            Rectangle {
                id: card
                width: Math.min(900, parent.width - 80)
                height: Math.min(560, parent.height - 80)
                anchors.centerIn: parent
                radius: Theme.radius
                color: Theme.bg
                border.width: 1
                border.color: Theme.accent
                focus: true
                Keys.onEscapePressed: root.closeMenu()
                Keys.onPressed: function(event) {
                    if (root.mode === "remove") {
                        if (event.key === Qt.Key_Down) { if (root.applist.length > 0) root.selected = (root.selected + 1) % root.applist.length; event.accepted = true }
                        else if (event.key === Qt.Key_Up) { if (root.applist.length > 0) root.selected = (root.selected - 1 + root.applist.length) % root.applist.length; event.accepted = true }
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) { root.doRemove(); event.accepted = true }
                    } else if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier))) {
                        root.doInstall(); event.accepted = true
                    }
                }
                Column {
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 10
                    Row {
                        width: parent.width
                        spacing: 10
                        Text { text: "WEB APPS"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true; font.letterSpacing: 3 }
                        Item { width: 10; height: 1 }
                        Repeater {
                            model: ["install", "remove"]
                            delegate: Rectangle {
                                required property string modelData
                                width: 74; height: 20; radius: 10
                                color: root.mode === modelData ? Theme.alpha(Theme.accent, 0.16) : "transparent"
                                border.width: 1
                                border.color: root.mode === modelData ? Theme.accent : Theme.border
                                Text { anchors.centerIn: parent; text: modelData.toUpperCase(); color: root.mode === modelData ? Theme.text : Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 9; font.bold: root.mode === modelData }
                                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { root.mode = modelData; root.error = ""; root.log = ""; if (modelData === "remove") pList.running = true } }
                            }
                        }
                    }
                    Rectangle { width: parent.width; height: 1; color: Theme.border }
                    Row {
                        width: parent.width
                        height: parent.height - 110
                        spacing: 0
                        Item {
                            width: parent.width / 2 - 8
                            height: parent.height
                            clip: true
                            // install form
                            Column {
                                visible: root.mode === "install"
                                width: parent.width - 8
                                spacing: 10
                                Repeater {
                                    model: [
                                        { label: "Name", key: "appName", placeholder: "My favorite web app" },
                                        { label: "URL", key: "appUrl", placeholder: "https://example.com" },
                                        { label: "Icon (optional)", key: "appIcon", placeholder: "Empty = auto-fetch favicon" }
                                    ]
                                    delegate: Column {
                                        required property var modelData
                                        width: parent.width
                                        spacing: 4
                                        Text { text: modelData.label; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 10 }
                                        Rectangle {
                                            width: parent.width; height: 34; radius: 6
                                            color: Theme.bgPanel
                                            border.width: 1
                                            border.color: Theme.border
                                            TextInput {
                                                anchors.fill: parent
                                                anchors.leftMargin: 10
                                                anchors.rightMargin: 10
                                                verticalAlignment: Text.AlignVCenter
                                                color: Theme.text
                                                font.family: Theme.fontFamily
                                                font.pixelSize: 13
                                                text: root[modelData.key]
                                                onTextChanged: root[modelData.key] = text
                                            }
                                        }
                                    }
                                }
                                Rectangle {
                                    width: 130; height: 32; radius: 6
                                    color: Theme.alpha(Theme.accent, 0.16)
                                    border.width: 1
                                    border.color: Theme.accent
                                    Text { anchors.centerIn: parent; text: "INSTALL"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doInstall() }
                                }
                                Text { visible: root.error !== ""; width: parent.width; text: root.error; color: Theme.danger; font.family: Theme.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
                            }
                            // remove list
                            ListView {
                                visible: root.mode === "remove"
                                anchors.fill: parent
                                anchors.rightMargin: 8
                                clip: true
                                model: root.applist
                                spacing: 4
                                boundsBehavior: Flickable.StopAtBounds
                                delegate: Rectangle {
                                    required property var modelData
                                    required property int index
                                    width: ListView.view.width
                                    height: 40
                                    radius: 6
                                    color: index === root.selected ? Theme.alpha(Theme.accent, 0.12) : "transparent"
                                    border.width: 1
                                    border.color: index === root.selected ? Theme.accent : "transparent"
                                    Text {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        verticalAlignment: Text.AlignVCenter
                                        text: modelData
                                        color: index === root.selected ? Theme.text : Theme.textDim
                                        font.family: Theme.fontFamily
                                        font.pixelSize: 12
                                        elide: Text.ElideRight
                                    }
                                    MouseArea { anchors.fill: parent; onClicked: { root.selected = index; root.removeArmed = false } }
                                }
                            }
                        }
                        Rectangle { width: 1; height: parent.height; color: Theme.alpha(Theme.border, 0.28) }
                        Item {
                            width: parent.width / 2 - 9
                            height: parent.height
                            clip: true
                            Column {
                                width: parent.width - 12
                                x: 12
                                spacing: 8
                                Text {
                                    width: parent.width
                                    text: root.mode === "install" ? "SUMMARY" : "DETAILS"
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 10
                                    font.letterSpacing: 2
                                }
                                Text {
                                    visible: root.mode === "install"
                                    width: parent.width
                                    text: root.appName.trim() ? ("~/.local/share/applications/" + root.appName.trim() + ".desktop\nwebapp-launch \"" + (root.appUrl.trim() || "…") + "\"\nIcon: " + (root.appIcon.trim() || "auto-fetch favicon")) : "Fill in the form — the launcher, command and icon resolve live here."
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    wrapMode: Text.Wrap
                                }
                                Text {
                                    visible: root.mode === "remove" && root.applist.length > 0
                                    width: parent.width
                                    text: (root.detailUrl ? root.detailUrl + "\n" : "") + (root.detailIcon ? "Icon: " + root.detailIcon : "")
                                    color: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 12
                                    wrapMode: Text.WrapAnywhere
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: root.mode === "remove"
                                    width: 130; height: 32; radius: 6
                                    color: root.removeArmed ? Theme.alpha(Theme.danger, 0.2) : Theme.alpha(Theme.danger, 0.08)
                                    border.width: 1
                                    border.color: Theme.danger
                                    Text { anchors.centerIn: parent; text: root.removeArmed ? "CONFIRM" : "REMOVE"; color: Theme.danger; font.family: Theme.fontFamily; font.pixelSize: 11; font.bold: true }
                                    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: root.doRemove() }
                                }
                                Text { visible: root.error !== "" && root.mode === "remove"; width: parent.width; text: root.error; color: Theme.danger; font.family: Theme.fontFamily; font.pixelSize: 11; wrapMode: Text.Wrap }
                                Rectangle { visible: root.log !== ""; width: parent.width; height: 1; color: Theme.border }
                                Text {
                                    visible: root.log !== ""
                                    width: parent.width
                                    text: root.log
                                    color: Theme.textDim
                                    font.family: Theme.fontFamily
                                    font.pixelSize: 11
                                    wrapMode: Text.Wrap
                                }
                            }
                        }
                    }
                    Text { width: parent.width; text: root.mode === "install" ? "enter installs · esc closes" : "enter remove (twice to confirm) · esc closes"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10 }
                }
            }
        }
    }
}
