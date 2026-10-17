pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import "../.."

// Clipboard history: split view (list left, full preview right).
// History helpers live inline here (no separate history script); capture /
// paste / open run the Python backend by argv (never shell).
// History: ~/.local/state/theme/clipboard-history.json (this file is the sole
// writer; the backend only reads it for paste/open by index).
// IPC: qs ipc call clipboard toggle|show|hide|wipe
Scope {
    id: root
    property bool showing: false
    property var targetScreen: Quickshell.screens[0]
    property string query: ""
    property int selected: 0
    property bool cursorActive: false
    property var entries: []
    property bool wipeArmed: false

    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/theme"
    readonly property string historyPath: root.stateDir + "/clipboard-history.json"
    readonly property string backend: Quickshell.env("HOME") + "/.config/quickshell/plugins/clipboard/clipboard.py"
    readonly property int historyLimit: 300
    readonly property int displayLimit: 50
    readonly property int displayTextLimit: 8192

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) { var scr = Quickshell.screens.find(function(s) { return s.name === mon.name }); if (scr) root.targetScreen = scr }
        root.showing = true
        root.query = ""
        root.selected = 0
        root.cursorActive = true
        root.wipeArmed = false
        root.rebuildDisplay()
        pSnapshot.running = true
        Qt.callLater(function() { keyCatcher.forceActiveFocus() })
    }
    function closeMenu() { root.showing = false }
    function toggleMenu() { root.showing ? root.closeMenu() : root.openMenu() }

    IpcHandler {
        target: "clipboard"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
        function wipe(): void { root.wipeAll() }
    }

    // ---------- history store (sole writer) ----------
    FileView {
        id: historyFile
        path: root.historyPath
        watchChanges: true
        printErrors: false
        onLoaded: root.loadHistory(text())
        onLoadFailed: root.loadHistory("[]")
        onFileChanged: reload()
    }
    function loadHistory(raw) {
        var out = []
        try {
            var parsed = JSON.parse(raw || "[]")
            if (Array.isArray(parsed)) for (var i = 0; i < parsed.length; i++) {
                var e = root.normalizeEntry(parsed[i])
                if (e) out.push(e)
            }
        } catch (e) {}
        root.entries = out
        if (root.showing) root.rebuildDisplay()
    }
    function saveHistory() {
        historyFile.setText(JSON.stringify(root.entries.slice(0, root.historyLimit), null, 2) + "\n")
    }
    function addEntry(raw) {
        var line = (raw || "").trim()
        if (!line) return
        var parsed = null
        try { parsed = JSON.parse(line) } catch (e) { return }
        var entry = root.normalizeEntry(parsed)
        if (!entry) return
        var key = root.entryKey(entry)
        var next = [entry]
        for (var i = 0; i < root.entries.length && next.length < root.historyLimit; i++) {
            var existing = root.normalizeEntry(root.entries[i])
            if (!existing || root.entryKey(existing) === key) continue
            next.push(existing)
        }
        root.entries = next
        root.saveHistory()
        if (root.showing) root.rebuildDisplay()
    }

    // ---------- pure entry helpers (no I/O) ----------
    function normalizeEntry(v) {
        if (!v || typeof v !== "object") return null
        if (v.type === "text" && typeof v.text === "string" && v.text.trim().length > 0) return { type: "text", text: v.text }
        if (v.type === "image" && typeof v.path === "string" && v.path) return { type: "image", path: v.path, mime: v.mime || "image/png", capturedAt: v.capturedAt || "" }
        return null
    }
    function entryKey(e) { return e.type === "image" ? "image:" + e.path : "text:" + e.text }
    function decodeFileUri(uri) {
        var value = String(uri || "").trim()
        if (value.indexOf("file://") !== 0) return ""
        var path = value.substring(7)
        if (path.indexOf("localhost/") === 0) path = path.substring(9)
        if (path.charAt(0) !== "/") return ""
        try { return decodeURIComponent(path) } catch (e) { return path }
    }
    function filePaths(entry) {
        if (!entry || entry.type !== "text") return []
        var lines = String(entry.text || "").split(/\r?\n/)
        var paths = []
        for (var i = 0; i < lines.length; i++) {
            var p = root.decodeFileUri(lines[i])
            if (p) paths.push(p)
        }
        return paths
    }
    function fileName(path) { var parts = String(path || "").split("/"); return parts.length > 0 ? parts[parts.length - 1] : String(path || "") }
    function isImagePath(path) { return /\.(png|jpe?g|webp|gif|bmp|tiff?)$/i.test(String(path || "")) }
    function fileEntryText(entry) {
        var paths = root.filePaths(entry)
        if (paths.length === 0) return ""
        if (paths.length === 1) return root.fileName(paths[0])
        return paths.length + " files"
    }
    function imagePreviewText(entry) {
        var timestamp = String((entry && entry.capturedAt) || "")
        if (!timestamp) return "Image"
        var label = String((entry && entry.mime) || "") === "image/png" ? "Screenshot" : "Image"
        return label + " from " + timestamp
    }
    function previewText(entry) {
        if (!entry) return ""
        if (entry.type === "image") return root.imagePreviewText(entry)
        var fileText = root.fileEntryText(entry)
        if (fileText) return fileText
        return String(entry.text || "").replace(/\s+/g, " ")
    }
    function fullText(entry) {
        if (!entry) return ""
        var paths = root.filePaths(entry)
        if (paths.length > 0) return paths.join("\n")
        return String(entry.text || "")
    }
    function searchableText(entry) {
        if (!entry) return ""
        if (entry.type === "image") return "image screenshot " + String(entry.mime || "") + " " + String(entry.capturedAt || "")
        return String(entry.text || "") + " " + root.fileEntryText(entry)
    }
    function cappedEntry(entry) {
        if (!entry || entry.type !== "text" || entry.text.length <= root.displayTextLimit) return entry
        var cut = entry.text.lastIndexOf("\n", root.displayTextLimit)
        return { type: "text", text: entry.text.slice(0, cut > 0 ? cut : root.displayTextLimit) }
    }
    function fileUrl(path) {
        return "file://" + String(path || "").split("/").map(function(seg) { return encodeURIComponent(seg) }).join("/")
    }

    // ---------- display model ----------
    ListModel { id: displayModel }
    function activeRow() {
        if (displayModel.count === 0 || root.selected < 0 || root.selected >= displayModel.count) return null
        return displayModel.get(root.selected)
    }
    function rebuildDisplay() {
        var needle = root.query.trim().toLowerCase()
        displayModel.clear()
        for (var i = 0; i < root.entries.length && displayModel.count < root.displayLimit; i++) {
            var entry = root.cappedEntry(root.normalizeEntry(root.entries[i]))
            if (!entry) continue
            if (needle && root.searchableText(entry).toLowerCase().indexOf(needle) < 0) continue
            var paths = root.filePaths(entry)
            var isFile = paths.length > 0
            var isImage = entry.type === "image"
            var previewPath = isImage ? String(entry.path || "") : (isFile && paths.length === 1 && root.isImagePath(paths[0]) ? paths[0] : "")
            displayModel.append({
                entryType: isFile ? "file" : entry.type,
                fullText: isImage ? "" : root.fullText(entry),
                previewText: root.previewText(entry),
                previewImage: previewPath ? root.fileUrl(previewPath) : "",
                path: isImage ? String(entry.path || "") : (isFile && paths.length === 1 ? paths[0] : ""),
                mime: isImage ? String(entry.mime || "image/png") : "text/plain",
                historyIndex: i
            })
        }
        if (displayModel.count === 0) root.selected = 0
        else if (root.selected >= displayModel.count) root.selected = displayModel.count - 1
        else if (root.selected < 0) root.selected = 0
        Qt.callLater(function() { if (displayModel.count > 0) resultList.positionViewAtIndex(root.selected, ListView.Contain) })
    }
    function select(delta) {
        if (displayModel.count === 0) return
        if (!root.cursorActive) {
            root.cursorActive = true
            root.selected = delta < 0 ? displayModel.count - 1 : 0
        } else {
            root.selected = (root.selected + delta + displayModel.count) % displayModel.count
        }
        resultList.positionViewAtIndex(root.selected, ListView.Contain)
    }
    function selectAbsolute(index) {
        if (displayModel.count === 0) return
        root.cursorActive = true
        root.selected = Math.max(0, Math.min(index, displayModel.count - 1))
        resultList.positionViewAtIndex(root.selected, ListView.Contain)
    }
    function setFilter(next) {
        root.query = next
        root.selected = 0
        root.cursorActive = true
        root.rebuildDisplay()
    }
    function removeDisplayIndex(index) {
        if (index < 0 || index >= displayModel.count) return
        var row = displayModel.get(index)
        var next = root.entries.slice()
        next.splice(row.historyIndex, 1)
        root.entries = next
        root.saveHistory()
        if (displayModel.count <= 1) { root.selected = 0; root.cursorActive = false }
        else if (root.selected >= displayModel.count - 1) root.selected = displayModel.count - 2
        root.rebuildDisplay()
    }
    function wipeAll() {
        root.entries = []
        root.saveHistory()
        root.selected = 0
        root.cursorActive = false
        root.wipeArmed = false
        root.rebuildDisplay()
    }

    // ---------- actions (all argv, never shell) ----------
    Process { id: pOp }
    function activateIndex(index) {
        if (index < 0 || index >= displayModel.count) return
        var row = displayModel.get(index)
        pOp.command = [root.backend, "paste", "--index", String(row.historyIndex)]
        pOp.running = true
        root.closeMenu()
    }
    function copyIndex(index) {
        if (index < 0 || index >= displayModel.count) return
        var row = displayModel.get(index)
        pOp.command = [root.backend, "paste", "--index", String(row.historyIndex), "--copy-only"]
        pOp.running = true
        root.closeMenu()
    }
    function openIndex(index) {
        if (index < 0 || index >= displayModel.count) return
        var row = displayModel.get(index)
        pOp.command = [root.backend, "open", "--index", String(row.historyIndex)]
        pOp.running = true
        root.closeMenu()
    }

    // ---------- capture watchers (owned here) ----------
    Component.onCompleted: { dirProc.running = true; initProc.running = true }
    Process {
        id: dirProc
        command: ["mkdir", "-p", root.stateDir]
        onExited: historyFile.reload()
    }
    Process {
        id: initProc
        command: ["pkill", "-f", "wl-paste .*--watch .*plugins/clipboard/clipboard\\.py"]
        onExited: { textWatch.running = true; imageWatch.running = true }
    }
    Process {
        id: pSnapshot
        command: [root.backend, "capture"]
        stdout: StdioCollector { onStreamFinished: root.addEntry(text) }
    }
    Process {
        id: textWatch
        command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "text", "--watch", root.backend + " capture text"]
        onExited: watchRestart.restart()
        stdout: SplitParser { onRead: function(data) { root.addEntry(data) } }
    }
    Process {
        id: imageWatch
        command: ["setpriv", "--pdeathsig", "TERM", "wl-paste", "--type", "image/png", "--watch", root.backend + " capture image/png"]
        onExited: watchRestart.restart()
        stdout: SplitParser { onRead: function(data) { root.addEntry(data) } }
    }
    Timer {
        id: watchRestart
        interval: 1000
        onTriggered: { if (!textWatch.running) textWatch.running = true; if (!imageWatch.running) imageWatch.running = true }
    }
    Timer { id: wipeTimer; interval: 3000; onTriggered: root.wipeArmed = false }

    PanelWindow {
        id: panel
        visible: root.showing
        screen: root.targetScreen
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        exclusionMode: ExclusionMode.Ignore
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.namespace: "clipboard"
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
            MouseArea { anchors.fill: parent; onClicked: {} }
            // Dedicated focus catcher: a TextInput here
            // fights the list for Up/Down/Enter/Delete, so the filter is typed
            // through Keys.onPressed and rendered as plain text instead.
            Item {
                id: keyCatcher
                anchors.fill: parent
                focus: true
                Keys.priority: Keys.BeforeItem
                Keys.onPressed: function(event) {
                    if (event.key === Qt.Key_Escape) {
                        if (root.query !== "") root.setFilter("")
                        else root.closeMenu()
                        event.accepted = true
                    } else if (event.key === Qt.Key_Delete) {
                        if (event.modifiers & Qt.ShiftModifier) { if (root.wipeArmed) root.wipeAll(); else { root.wipeArmed = true; wipeTimer.restart() } }
                        else root.removeDisplayIndex(root.selected)
                        event.accepted = true
                    } else if (event.key === Qt.Key_Backspace) {
                        if (event.modifiers & Qt.ControlModifier) root.setFilter("")
                        else root.setFilter(root.query.slice(0, -1))
                        event.accepted = true
                    } else if (event.key === Qt.Key_Up) { root.select(-1); event.accepted = true }
                    else if (event.key === Qt.Key_Down) { root.select(1); event.accepted = true }
                    else if (event.key === Qt.Key_PageUp) { root.select(-6); event.accepted = true }
                    else if (event.key === Qt.Key_PageDown) { root.select(6); event.accepted = true }
                    else if (event.key === Qt.Key_Home) { root.selectAbsolute(0); event.accepted = true }
                    else if (event.key === Qt.Key_End) { root.selectAbsolute(displayModel.count - 1); event.accepted = true }
                    else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                        if (root.cursorActive && (event.modifiers & Qt.AltModifier)) root.openIndex(root.selected)
                        else if (root.cursorActive && (event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier))) root.copyIndex(root.selected)
                        else if (root.cursorActive) root.activateIndex(root.selected)
                        else if (displayModel.count > 0) root.cursorActive = true
                        event.accepted = true
                    } else if (event.text && event.text.length === 1 && event.text.charCodeAt(0) >= 32 && event.text.charCodeAt(0) !== 127) {
                        root.setFilter(root.query + event.text)
                        event.accepted = true
                    }
                }
            }
            Column {
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                Row {
                    width: parent.width
                    spacing: 10
                    Text { text: "CLIPBOARD"; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: true; font.letterSpacing: 3 }
                    Rectangle {
                        width: countLabel.width + 14; height: 18; radius: 9
                        anchors.verticalCenter: parent.verticalCenter
                        color: Theme.alpha(Theme.accent, 0.12)
                        Text { id: countLabel; anchors.centerIn: parent; text: root.entries.length + ""; color: Theme.textDim; font.family: Theme.fontFamily; font.pixelSize: 10 }
                    }
                    Item { width: parent.width - 220; height: 1 }
                    Text {
                        text: root.wipeArmed ? "SURE?" : "WIPE ALL"
                        color: Theme.danger
                        font.family: Theme.fontFamily
                        font.pixelSize: 10
                        font.bold: root.wipeArmed
                        anchors.verticalCenter: parent.verticalCenter
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: { if (root.wipeArmed) root.wipeAll(); else { root.wipeArmed = true; wipeTimer.restart() } }
                        }
                    }
                }
                Rectangle { width: parent.width; height: 1; color: Theme.border }
                Text {
                    width: parent.width
                    text: root.query || "Search clipboard…"
                    color: Theme.text
                    opacity: root.query ? 1 : 0.58
                    font.family: Theme.fontFamily
                    font.pixelSize: 14
                    elide: Text.ElideRight
                }
                Item {
                    width: parent.width
                    height: parent.height - 150
                    Row {
                        anchors.fill: parent
                        spacing: 0
                        Item {
                            width: parent.width / 2
                            height: parent.height
                            clip: true
                            ListView {
                                id: resultList
                                anchors.fill: parent
                                anchors.rightMargin: 12
                                clip: true
                                model: displayModel
                                spacing: 4
                                boundsBehavior: Flickable.StopAtBounds
                                delegate: Rectangle {
                                    id: row
                                    required property int index
                                    required property string entryType
                                    required property string previewText
                                    required property string fullText
                                    required property string previewImage
                                    readonly property bool hasCursor: root.cursorActive && index === root.selected
                                    width: ListView.view.width
                                    height: 50
                                    radius: 6
                                    color: hasCursor ? Theme.alpha(Theme.accent, 0.12) : "transparent"
                                    border.width: 1
                                    border.color: hasCursor ? Theme.accent : "transparent"
                                    Row {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 10
                                        anchors.topMargin: 5
                                        anchors.bottomMargin: 5
                                        spacing: 8
                                        Image {
                                            visible: row.previewImage.length > 0
                                            width: visible ? parent.height : 0
                                            height: parent.height
                                            source: row.previewImage
                                            fillMode: Image.PreserveAspectFit
                                            asynchronous: true
                                            smooth: true
                                        }
                                        Text {
                                            width: parent.width - (row.previewImage.length > 0 ? parent.height + parent.spacing : 0)
                                            height: parent.height
                                            verticalAlignment: Text.AlignVCenter
                                            text: row.previewText
                                            color: row.hasCursor ? Theme.text : Theme.textDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            opacity: row.entryType === "image" || row.entryType === "file" ? 0.72 : 1.0
                                            elide: Text.ElideRight
                                            wrapMode: Text.NoWrap
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onPositionChanged: { root.cursorActive = true; root.selected = row.index }
                                        onClicked: { root.cursorActive = true; root.selected = row.index; root.activateIndex(row.index) }
                                    }
                                }
                            }
                        }
                        Item {
                            width: parent.width / 2
                            height: parent.height
                            clip: true
                            property var active: displayModel.count > 0 && root.selected >= 0 && root.selected < displayModel.count ? displayModel.get(root.selected) : null
                            // Divider between list and preview: a thin border
                            // line; borderAccent keeps it visible on dark themes.
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                width: 1
                                color: Theme.borderAccent
                            }
                            Text {
                                visible: parent.active && !parent.active.previewImage
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                text: parent.active ? parent.active.fullText : ""
                                color: Theme.text
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                wrapMode: Text.WrapAnywhere
                                elide: Text.ElideRight
                                verticalAlignment: Text.AlignTop
                            }
                            Image {
                                visible: parent.active && parent.active.previewImage
                                anchors.fill: parent
                                anchors.leftMargin: 12
                                source: parent.active ? parent.active.previewImage : ""
                                fillMode: Image.PreserveAspectFit
                                verticalAlignment: Image.AlignTop
                                asynchronous: true
                                smooth: true
                            }
                        }
                    }
                    Column {
                        anchors.centerIn: parent
                        spacing: 8
                        visible: displayModel.count === 0
                        Text {
                            text: root.entries.length === 0 ? "Clipboard is empty" : "No matches for “" + root.query + "”"
                            color: Theme.text
                            opacity: 0.7
                            font.family: Theme.fontFamily
                            font.pixelSize: 12
                            horizontalAlignment: Text.AlignHCenter
                            width: parent.width
                        }
                    }
                }
                Text { width: parent.width; text: "enter paste · shift+enter copy · alt+enter open · del remove · shift+del wipe · esc close"; color: Theme.textFaint; font.family: Theme.fontFamily; font.pixelSize: 10 }
            }
        }
    }
}
