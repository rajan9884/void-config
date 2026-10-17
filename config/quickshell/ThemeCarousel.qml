pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import QtQuick.Effects

// Theme picker — same fullscreen cover-flow design as hyprquickpaper.
// Shortcut: Super+Ctrl+Shift+Space -> qs ipc call themes toggle
// Keys: H/Left + L/Right navigate, Enter/Space apply + close (like the
// wallpaper picker), 1-9/0 quick-apply + close, C colorgen, M dark/light
// (toggles stay open for previewing), Esc/Q/W close. The whole system
// picks up the new theme instantly via Theme.qml watching
// ~/.cache/theme/quickshell-theme.json.
Scope {
    id: root
    property bool showing: false
    property bool mounted: false
    property var targetScreen: Quickshell.screens[0]
    property bool colorGen: true
    property bool darkMode: true
    property string currentPreset: ""

    readonly property string thumbPath: Quickshell.env("HOME") + "/.cache/theme/theme-thumbs/"
    readonly property real ui: (Quickshell.screens[0]?.height ?? 1080) / 1080
    readonly property int animDuration: 220
    readonly property int visibleTiles: 7

    readonly property var themes: [
        { label: "DEFAULT", command: "default", preset: "default" },
        { label: "WHITE", command: "preset white", preset: "white" },
        { label: "METAL", command: "preset metal", preset: "metal" },
        { label: "SLATE", command: "preset slate", preset: "slate" },
        { label: "LIGHT GRAY", command: "preset light-gray", preset: "light-gray" },
        { label: "BEIGE", command: "preset beige", preset: "beige" },
        { label: "SILVER", command: "preset silver", preset: "silver" },
        { label: "GOLD", command: "preset gold", preset: "gold" },
        { label: "NORD", command: "preset nord", preset: "nord" },
        { label: "TOKYO NIGHT", command: "preset tokyo-night", preset: "tokyo-night" },
        { label: "CATPPUCCIN MOCHA", command: "preset catppuccin-mocha", preset: "catppuccin-mocha" },
        { label: "EVERFOREST DARK", command: "preset everforest-dark", preset: "everforest-dark" },
        { label: "DRACULA", command: "preset dracula", preset: "dracula" },
        { label: "ONE DARK", command: "preset one-dark", preset: "one-dark" },
        { label: "KANAGAWA", command: "preset kanagawa", preset: "kanagawa" },
        { label: "ROSE PINE", command: "preset rose-pine", preset: "rose-pine" },
        { label: "RED", command: "preset red", preset: "red" },
        { label: "MATRIX", command: "preset matrix", preset: "matrix" }
    ]

    function runTheme(cmd) {
        Quickshell.execDetached(["/bin/sh", "-c",
            "python3 \"$HOME/.config/theme/bin/theme.py\" " + cmd])
        reloadTimer.restart()
    }
    function setColorGen(on) {
        root.colorGen = on
        runTheme("colorgen " + (on ? "on" : "off"))
    }
    function toggleMode() {
        root.darkMode = !root.darkMode
        runTheme("toggle")
    }
    function apply(i) {
        if (i < 0 || i >= themes.length) return
        runTheme(themes[i].command)
    }
    function move(d) {
        // Kept for IPC compat; the strip drives currentIndex natively.
        if (!strip) return
        var n = themes.length
        strip.currentIndex = (strip.currentIndex + d + n) % n
    }

    FileView {
        id: stateView
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/theme/state.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: {
            try {
                root.colorGen = stateAdapter.colorgen
                root.darkMode = stateAdapter.mode_appearance !== "light"
                if (typeof stateAdapter.preset === "string" && stateAdapter.preset !== "")
                    root.currentPreset = stateAdapter.preset
            } catch (e) {}
        }
        adapter: JsonAdapter {
            id: stateAdapter
            property bool colorgen: true
            property string mode_appearance: "dark"
            property string preset: ""
        }
    }
    Timer { id: reloadTimer; interval: 700; onTriggered: stateView.reload() }

    onShowingChanged: {
        if (showing) { unmountTimer.stop(); mounted = true }
        else unmountTimer.restart()
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
        target: "themes"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
        function next(): void { root.move(1) }
        function prev(): void { root.move(-1) }
        function applyIndex(i: int): void { root.apply(i); root.closeMenu() }
    }

    LazyLoader {
        id: loader
        active: root.mounted
        PanelWindow {
            id: win
            screen: root.targetScreen
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "themes"
            WlrLayershell.keyboardFocus: root.showing ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
            mask: Region { item: root.showing ? bar : null }
            Component.onCompleted: {
                strip.forceActiveFocus()
                Quickshell.execDetached(["python3",
                    Quickshell.env("HOME") + "/.config/theme/bin/theme-thumbs.py"])
            }

            // Dark veil so thumbnails don't blend into the desktop.
            Rectangle {
                anchors.fill: parent
                color: "#b3000000"
                z: 0
            }

            MouseArea {
                anchors.fill: parent
                z: 0
                onClicked: root.closeMenu()
            }

            Item {
                id: bar
                anchors.fill: parent
                z: 1
                visible: root.showing

                property real tileHeight: 500 * root.ui
                property real tileWidth: (1920 / Math.max(1, root.visibleTiles) - 10) * root.ui
                property real viewportCenterX: width / 2
                property real falloffRadius: 960 * root.ui
                property real sideMargin: Math.max(0, viewportCenterX - tileWidth / 2)

                // Status pill: colorgen + appearance, mirrors the old header.
                Rectangle {
                    anchors.top: parent.top
                    anchors.topMargin: 48 * root.ui
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: statusLabel.implicitWidth + 36 * root.ui
                    height: statusLabel.implicitHeight + 18 * root.ui
                    radius: height / 2
                    color: "#cc000000"
                    border.width: 1
                    border.color: Theme.accent

                    Text {
                        id: statusLabel
                        anchors.centerIn: parent
                        text: "THEMES  ·  " + (root.colorGen ? "COLORGEN ON" : "COLORGEN OFF")
                              + "  ·  " + (root.darkMode ? "DARK" : "LIGHT")
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: 13 * root.ui
                        font.bold: true
                        font.letterSpacing: 2
                    }
                }

                ListView {
                    id: strip
                    width: parent.width
                    height: bar.tileHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.verticalCenter: parent.verticalCenter
                    focus: true
                    model: root.themes
                    orientation: ListView.Horizontal
                    spacing: 0
                    clip: true
                    cacheBuffer: 400 * root.ui
                    boundsBehavior: Flickable.StopAtBounds

                    // The view itself keeps the current tile centered:
                    // selection and view can never disagree.
                    highlightRangeMode: ListView.StrictlyEnforceRange
                    preferredHighlightBegin: width / 2 - bar.tileWidth / 2
                    preferredHighlightEnd: width / 2 - bar.tileWidth / 2
                    highlightMoveDuration: root.animDuration

                    leftMargin: bar.sideMargin
                    rightMargin: bar.sideMargin

                    function clampIndex(i) { return Math.max(0, Math.min(i, count - 1)) }

                    function indexOfCurrent() {
                        if (root.currentPreset !== "") {
                            for (let i = 0; i < count; i++) {
                                if (root.themes[i].preset === root.currentPreset) return i
                            }
                        }
                        return 0
                    }

                    function centerOnStart() {
                        if (count <= 0) return
                        currentIndex = indexOfCurrent()
                    }

                    function activateCurrent() {
                        if (count <= 0) return
                        // Close like the wallpaper picker: an explicit apply
                        // is a choice, not a preview. C/M toggles stay open.
                        root.apply(currentIndex)
                        root.closeMenu()
                    }

                    function quickApply(i) {
                        if (count <= 0) return
                        root.apply(clampIndex(i))
                        root.closeMenu()
                    }

                    onCountChanged: centerOnStart()
                    Component.onCompleted: centerOnStart()
                    Connections {
                        target: root
                        function onShowingChanged() {
                            if (root.showing) {
                                strip.centerOnStart()
                                strip.forceActiveFocus()
                            }
                        }
                    }

                    delegate: Item {
                        id: delegateItem
                        width: bar.tileWidth
                        height: bar.tileHeight

                        required property var modelData
                        required property int index
                        property bool active: index === strip.currentIndex
                        readonly property real baseWidth: bar.tileWidth
                        readonly property real baseCenterX: x - strip.contentX + baseWidth / 2
                        readonly property real distance: Math.abs(baseCenterX - bar.viewportCenterX)
                        readonly property real fraction: Math.min(1, distance / bar.falloffRadius)
                        readonly property real compression: { const t = fraction; return t * t * t * t }
                        readonly property real edgeOffset: {
                            const amount = 80 * root.ui * compression
                            return baseCenterX < bar.viewportCenterX ? amount : -amount
                        }
                        readonly property real scaleFactor: {
                            const t = 1 - fraction * fraction * (3 - 2 * fraction)
                            return 0.3 + (0.8 - 0.3) * t
                        }

                        Item {
                            id: content
                            anchors.verticalCenter: parent.verticalCenter
                            width: delegateItem.baseWidth * delegateItem.scaleFactor
                            height: delegateItem.height * Math.min(1, delegateItem.scaleFactor)
                            x: (delegateItem.baseWidth - width) / 2 + delegateItem.edgeOffset

                            Image {
                                id: shadowImage
                                x: 6 * root.ui
                                y: 6 * root.ui
                                width: parent.width
                                height: parent.height
                                source: img.source
                                sourceSize.width: img.sourceSize.width
                                sourceSize.height: img.sourceSize.height
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                visible: delegateItem.active
                                opacity: 0.4
                                layer.enabled: true
                                layer.effect: MultiEffect { brightness: -1; blurEnabled: true; blur: 0.45 }
                            }

                            // Cheap static shadow for side tiles.
                            Rectangle {
                                x: 6 * root.ui
                                y: 6 * root.ui
                                width: parent.width
                                height: parent.height
                                radius: Math.min(width, height) * 0.04
                                color: "#000000"
                                opacity: !delegateItem.active ? 0.28 : 0
                                visible: opacity > 0
                            }

                            Text {
                                id: alt
                                text: ""
                                color: "#ffffff"
                                anchors.centerIn: parent
                                font.pixelSize: 16 * root.ui
                            }

                            Image {
                                id: img
                                anchors.fill: parent
                                opacity: delegateItem.active ? 0.95 : 0.45
                                fillMode: Image.PreserveAspectCrop
                                asynchronous: true
                                cache: true
                                smooth: true
                                source: "file://" + root.thumbPath + delegateItem.modelData.preset + ".png"
                                sourceSize.width: delegateItem.baseWidth * 0.8
                                sourceSize.height: delegateItem.height
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                Timer {
                                    id: retryTimer
                                    interval: 1000
                                    repeat: false
                                    onTriggered: { const s = img.source; img.source = ""; img.source = s }
                                }

                                onStatusChanged: {
                                    if (status === Image.Error) { alt.text = "Rendering"; retryTimer.start() }
                                }
                            }

                            Rectangle {
                                z: 10
                                anchors.fill: parent
                                visible: delegateItem.active
                                color: "transparent"
                                border.width: Math.max(2, Math.round(3 * root.ui))
                                border.color: "#ffffff"
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            // Click a side tile to center it,
                            // click the centered one to apply.
                            onClicked: {
                                if (index === strip.currentIndex) strip.activateCurrent();
                                else strip.currentIndex = index;
                            }
                            onWheel: function(wheel) { strip.flick(-wheel.angleDelta.y * 8, 0); wheel.accepted = true }
                        }
                    }

                    Keys.onPressed: function(event) {
                        var k = event.key
                        if (k === Qt.Key_Space || k === Qt.Key_Return || k === Qt.Key_Enter) {
                            activateCurrent()
                        } else if (k === Qt.Key_Left || k === Qt.Key_H) {
                            decrementCurrentIndex()
                        } else if (k === Qt.Key_Right || k === Qt.Key_L) {
                            incrementCurrentIndex()
                        } else if (k === Qt.Key_C) {
                            root.setColorGen(!root.colorGen)
                        } else if (k === Qt.Key_M) {
                            root.toggleMode()
                        } else if (k >= Qt.Key_1 && k <= Qt.Key_9) {
                            quickApply(k - Qt.Key_1)
                        } else if (k === Qt.Key_0) {
                            quickApply(9)
                        } else if (k === Qt.Key_W || k === Qt.Key_Escape || k === Qt.Key_Q) {
                            root.closeMenu()
                        } else {
                            return
                        }
                        event.accepted = true
                    }
                }

                // Name pill: shows exactly which theme Enter/Space will apply.
                Rectangle {
                    anchors.top: strip.bottom
                    anchors.topMargin: 24 * root.ui
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: nameLabel.implicitWidth + 36 * root.ui
                    height: nameLabel.implicitHeight + 18 * root.ui
                    radius: height / 2
                    color: "#cc000000"
                    border.width: 1
                    border.color: "#ffffff"

                    Text {
                        id: nameLabel
                        anchors.centerIn: parent
                        text: strip.count > 0 ? root.themes[strip.currentIndex].label : ""
                        color: "#ffffff"
                        font.pixelSize: 15 * root.ui
                    }
                }

                Text {
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 28 * root.ui
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "h/l ←/→ move · enter apply · 1-9/0 quick · c colorgen · m mode · esc/q close"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily
                    font.pixelSize: 10 * root.ui
                }
            }
        }
    }
}
