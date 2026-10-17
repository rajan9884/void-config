import Quickshell
import Quickshell.Services.Pipewire
import Quickshell.Wayland
import Quickshell.Io
import QtQuick
import QtQuick.Effects

Scope {
    id: root

    // ---- window lifecycle ------------------------------------------------
    property bool mounted: false      // OSD window exists
    property real winW: 0             // reported by the OSD window while mounted
    property real winH: 0
    property real hitW: 0

    // Must be longer than the fade-out (OsdCard opacity/scale = 150ms).
    Timer {
        id: unmountTimer
        interval: 250
        onTriggered: {
            root.mounted = false
            root.winW = 0
            root.winH = 0
            root.hitW = 0
            root.hovered = false
        }
    }

    // OSD sits at the bottom of the screen (above the bar area).
    readonly property int bottomGap: 110
    readonly property int keepVisible: 40
    readonly property int toolsHeight: 22

    readonly property var numSpec: ({
        osdScale:      { min: 60,   max: 160,   def: 80,  step: 5,  unit: "%" },
        mediaWidth:    { min: 300,  max: 600,   def: 420,  step: 20,  unit: "px" },
        portraitWidth: { min: 200,  max: 400,   def: 260,  step: 20,  unit: "px" },
        flyoutWidth:   { min: 200,  max: 500,   def: 320,  step: 20,  unit: "px" },
        artSize:       { min: 32,   max: 96,    def: 52,   step: 4,   unit: "px" },
        barCount:      { min: 4,    max: 64,    def: 24,   step: 2,   unit: "" },
        barRadius:     { min: 0,    max: 20,    def: 20,   step: 2,   unit: "px", full: true },
        barSpacing:    { min: 1,    max: 10,    def: 3,    step: 1,   unit: "px" },
        barHeight:     { min: 10,   max: 60,    def: 20,   step: 2,   unit: "px" },
        barFps:        { min: 15,   max: 60,    def: 30,   step: 5,   unit: " fps" },
        mediaTimeout:  { min: 500,  max: 15000, def: 3000, step: 500, unit: "s" },
        volTimeout:    { min: 300,  max: 8000,  def: 1200, step: 100, unit: "s" },
        bgOpacity:     { min: 10,   max: 100,   def: Math.max(10, Math.round((Theme.bg.a ?? 1) * 20) * 5),        step: 5, unit: "%" },
        artOpacity:    { min: 20,   max: 100,   def: Math.max(20, Math.round((Theme.bgAlpha ?? 1) * 20) * 5),    step: 5, unit: "%" },
        barOpacity:    { min: 30,   max: 100,   def: 90,   step: 5,   unit: "%" },
        barDimOpacity: { min: 0,    max: 60,    def: 30,   step: 5,   unit: "%" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        showVisualizer: true,
        trackChangeOsd: true,
        showArt: true,
        musicOnly: true,
        artistBelow: false,
        portrait: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    readonly property var posKeys: ["offsetX", "offsetY", "volOffsetX", "volOffsetY"]

    property real offsetX: 0
    property real offsetY: 0
    property real volOffsetX: 0
    property real volOffsetY: 0

    property int osdScale: numSpec.osdScale.def
    property int mediaWidth: numSpec.mediaWidth.def
    property int portraitWidth: numSpec.portraitWidth.def
    property int flyoutWidth: numSpec.flyoutWidth.def
    property int artSize: numSpec.artSize.def
    property int barCount: numSpec.barCount.def
    property int barRadius: numSpec.barRadius.def
    property int barSpacing: numSpec.barSpacing.def
    property int barHeight: numSpec.barHeight.def
    property int barFps: numSpec.barFps.def
    property int mediaTimeout: numSpec.mediaTimeout.def
    property int volTimeout: numSpec.volTimeout.def
    property int bgOpacity: numSpec.bgOpacity.def
    property int artOpacity: numSpec.artOpacity.def
    property int barOpacity: numSpec.barOpacity.def
    property int barDimOpacity: numSpec.barDimOpacity.def

    property bool showVisualizer: boolDefaults.showVisualizer
    property bool trackChangeOsd: boolDefaults.trackChangeOsd
    property bool showArt: boolDefaults.showArt
    property bool musicOnly: boolDefaults.musicOnly
    property bool artistBelow: boolDefaults.artistBelow
    property bool portrait: boolDefaults.portrait

    readonly property real scaleFactor: osdScale / 100

    // Card background: theme colour with its alpha replaced by the
    // "Background" setting (100% = fully opaque).
    readonly property color cardColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, bgOpacity / 100)
    readonly property real curX: showMedia ? offsetX : volOffsetX
    readonly property real curY: showMedia ? offsetY : volOffsetY

    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/mediaosd-state.json"

    // ---- player detection --------------------------------------------------
    readonly property var musicPlayers: [
        "spotify", "spotifyd", "spotify_player", "spotify-launcher", "mpd", "mopidy", "cmus",
        "rhythmbox", "strawberry", "amberol", "lollypop", "deadbeef", "audacious",
        "quodlibet", "clementine", "elisa", "youtube-music", "ncspot"
    ]
    readonly property var browserPlayers: [
        "firefox", "librewolf", "zen", "chromium", "chrome", "google-chrome", "brave",
        "vivaldi", "opera", "edge", "microsoft-edge", "plasma-browser-integration"
    ]
    readonly property var musicSites: [
        "music.youtube.com", "open.spotify.com", "soundcloud.com", "bandcamp.com",
        "music.apple.com", "tidal.com", "deezer.com", "music.amazon.", "pandora.com",
        "qobuz.com", "listen.tidal.com", "radio.", "last.fm"
    ]

    function isMusic(p) {
        var name = p.player.split(".")[0].toLowerCase()
        if (musicPlayers.indexOf(name) >= 0)
            return true
        if (browserPlayers.indexOf(name) < 0)
            return false
        if (p.album !== "")
            return true
        var u = p.url.toLowerCase()
        return musicSites.some(function (s) { return u.indexOf(s) >= 0 })
    }

    readonly property string playerFormat:
        "{{playerName}}\t{{status}}\t{{title}}\t{{artist}}\t{{album}}\t{{position}}\t{{mpris:length}}\t{{mpris:artUrl}}\t{{xesam:url}}"

    function parsePlayer(line) {
        if (!line)
            return null
        var f = line.split("\t")
        if (f.length < 3)
            return null
        while (f.length < 9)
            f.push("")
        var p = {
            player: f[0],
            status: f[1],
            title: f[2],
            artist: f[3],
            album: f[4],
            position: parseFloat(f[5]) || 0,
            length: parseFloat(f[6]) || 0,
            art: f[7],
            url: f[8]
        }
        p.music = isMusic(p)
        return p
    }

    function ctl(cmd) {
        var c = ["playerctl"]
        if (player !== "")
            c.push("--player=" + player)
        c.push(cmd)
        Quickshell.execDetached(c)
    }

    function mediaCmd(cmd) {
        ctl(cmd)
        hideTimer.restart()
    }

    property string title: ""
    property string artist: ""
    property string status: "Stopped"
    property string artUrl: ""
    property string player: ""
    property real position: 0
    property real length: 0

    readonly property bool playing: status === "Playing"
    readonly property real progress: length > 0 ? Math.min(position / length, 1) : 0

    function applyPlayer(p, withTiming) {
        player = p.player
        status = p.status
        title = p.title
        artist = p.artist
        artUrl = p.art
        if (withTiming) {
            position = p.position
            length = p.length
        }
    }

    function clearPlayer() {
        status = "Stopped"
        title = ""
        artist = ""
        artUrl = ""
        player = ""
        position = 0
        length = 0
    }

    function pickPlayer(text) {
        var lines = text.trim().split("\n")
        var pool = []

        for (var i = 0; i < lines.length; i++) {
            var p = parsePlayer(lines[i])
            if (!p || (musicOnly && !p.music))
                continue
            pool.push(p)
        }

        return pool.find(function (p) { return p.status === "Playing" }) ?? pool[0] ?? null
    }

    function updateMedia() {
        if (!mediaProcess.running)
            mediaProcess.running = true
    }

    // ---- volume watching (always on, cheap) -------------------------------
    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink?.audio?.volume ?? 0
    readonly property bool muted: sink?.audio?.muted ?? false

    Connections {
        target: root.sink?.audio ?? null
        function onVolumeChanged() { root.triggerOsd() }
        function onMutedChanged() { root.triggerOsd() }
    }

    // ---- OSD state ---------------------------------------------------------
    property bool ready: false
    property bool showing: false
    property bool showMedia: false
    property bool pendingShow: false
    property bool dragging: false
    property bool pinned: false
    property bool hovered: false     // driven by a Binding inside the OSD window

    Timer {
        interval: 2000
        running: true
        onTriggered: root.ready = true
    }

    Timer {
        id: hideTimer
        interval: root.showMedia ? root.mediaTimeout : root.volTimeout
        onTriggered: {
            if (root.hovered || root.dragging || (root.showMedia && root.pinned))
                hideTimer.restart()
            else
                root.showing = false
        }
    }

    function triggerOsd() {
        if (!ready)
            return
        if (showing) {
            hideTimer.restart()
            return
        }
        pendingShow = true
        updateMedia()
    }

    function showMediaOsd() {
        pendingShow = false
        showMedia = true
        showing = true
        hideTimer.restart()
        updateMedia()
    }

    function triggerMediaOsd() {
        if (ready)
            showMediaOsd()
    }

    function togglePinned() {
        pinned = !pinned
        hideTimer.restart()
    }

    function closeAll() {
        dragging = false
        showing = false
    }

    function finishPendingShow() {
        if (!pendingShow)
            return
        pendingShow = false
        showMedia = playing
        showing = true
        hideTimer.restart()
    }

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            showMedia = false
            dragging = false
            pinned = false
            unmountTimer.restart()
        }
    }

    onShowMediaChanged: {
        if (showMedia)
            updateMedia()
        else
            bars = []
    }

    IpcHandler {
        target: "mediaosd"
        function media(): void { root.triggerMediaOsd() }
        function hide(): void { root.closeAll() }
    }

    // ---- position/state helpers (drag handle + state file) ------------------
    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    // Only called while the user drags the handle. Saved offsets are never
    // rewritten by window resizes, so a transient window/card size during
    // mount can no longer squeeze the position you left it at.
    function setPosition(x, y) {
        var nx = x
        var ny = y
        if (winW > 0 && winH > 0 && hitW > 0) {
            var minX = keepVisible - winW / 2 - hitW / 2
            var maxX = winW / 2 - keepVisible + hitW / 2
            // Bottom-anchored card: dragging down (+y) eats bottomGap.
            var minY = -(winH - keepVisible - bottomGap)
            var maxY = Math.max(minY, bottomGap - keepVisible)
            nx = Math.max(minX, Math.min(maxX, x))
            ny = Math.max(minY, Math.min(maxY, y))
        }
        if (showMedia) {
            offsetX = nx
            offsetY = ny
        } else {
            volOffsetX = nx
            volOffsetY = ny
        }
    }

    function resetPos(media) {
        if (media) {
            offsetX = 0
            offsetY = 0
        } else {
            volOffsetX = 0
            volOffsetY = 0
        }
        saveState()
    }

    function saveState() {
        var s = {}
        posKeys.forEach(function (k) { s[k] = root[k] })
        numKeys.forEach(function (k) { s[k] = root[k] })
        boolKeys.forEach(function (k) { s[k] = root[k] })
        stateFile.setText(JSON.stringify(s))
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())

                root.posKeys.forEach(function (k) {
                    if (typeof s[k] === "number")
                        root[k] = s[k]
                })
                root.numKeys.forEach(function (k) {
                    if (typeof s[k] === "number") {
                        var spec = root.numSpec[k]
                        root[k] = root.clamp(s[k], spec.min, spec.max)
                    }
                })
                root.boolKeys.forEach(function (k) {
                    if (typeof s[k] === "boolean")
                        root[k] = s[k]
                })
            } catch (e) {
                console.warn("mediaosd: could not read saved state:", e)
            }
        }
    }

    // ---- background processes (not part of the window) --------------------
    Process {
        id: mediaProcess

        command: ["playerctl", "--all-players", "metadata", "--format", root.playerFormat]

        stdout: StdioCollector {
            onStreamFinished: {
                var pick = root.pickPlayer(this.text)
                if (pick)
                    root.applyPlayer(pick, true)
                else
                    root.clearPlayer()
                root.finishPendingShow()
            }
        }
    }

    Process {
        id: playerEventProcess

        command: ["playerctl", "--all-players", "--follow", "metadata", "--format", root.playerFormat]
        running: true

        stdout: SplitParser {
            onRead: data => {
                var p = root.parsePlayer(data.trim())
                if (!p || (root.musicOnly && !p.music))
                    return

                var trackChanged = p.title !== root.title || p.artist !== root.artist
                root.applyPlayer(p, false)

                if (root.ready && root.trackChangeOsd && trackChanged
                        && p.title !== "" && p.status === "Playing")
                    root.triggerMediaOsd()

                if (root.ready)
                    root.updateMedia()
            }
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.showing && root.showMedia
        onTriggered: root.updateMedia()
    }

    Timer {
        interval: 250
        repeat: true
        running: root.playing && root.showing && root.showMedia
        onTriggered: {
            if (root.length > 0)
                root.position = Math.min(root.position + 250000, root.length)
        }
    }

    property var bars: []
    property bool cavaPaused: false

    Timer {
        id: cavaResume
        interval: 350
        onTriggered: root.cavaPaused = false
    }

    function restartCava() {
        if (cavaProcess.running) {
            cavaPaused = true
            cavaResume.restart()
        }
    }

    onBarCountChanged: restartCava()
    onBarFpsChanged: restartCava()

    Process {
        id: cavaProcess

        running: root.showing && root.showMedia && root.showVisualizer && !root.cavaPaused

        command: [
            "sh", "-c",
            "printf '%s\\n' " +
            "'[general]' 'bars = " + root.barCount + "' 'framerate = " + root.barFps + "' " +
            "'[input]' 'method = pipewire' " +
            "'[output]' 'method = raw' 'raw_target = /dev/stdout' " +
            "'data_format = ascii' 'ascii_max_range = 100' " +
            "'bar_delimiter = 59' 'frame_delimiter = 10' " +
            "> /tmp/quickshell-cava.conf && exec cava -p /tmp/quickshell-cava.conf"
        ]

        stdout: SplitParser {
            onRead: data => {
                var parts = data.split(";")
                var n = root.barCount
                var out = new Array(n)
                for (var i = 0; i < n; i++)
                    out[i] = parseInt(parts[i]) || 0
                root.bars = out
            }
        }
    }

    // ---- OSD window: only exists while mounted ----------------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win

            // The window is created with `showing` already true, so cards
            // bound straight to it would pop in with no animation. `reveal`
            // stays false until one tick after creation, then follows `showing`.
            property bool reveal: false

            readonly property Item activeCard: root.showMedia ? mediaPanel : flyout

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore

            WlrLayershell.layer: WlrLayer.Top
            WlrLayershell.namespace: "mediaosd"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

            mask: Region { item: root.showing ? hitbox : null }

            onWidthChanged: root.winW = width
            onHeightChanged: root.winH = height

            Component.onCompleted: {
                root.winW = width
                root.winH = height
                Qt.callLater(function () {
                    win.reveal = Qt.binding(function () { return root.showing })
                })
            }

            // hover state lives in this window, but the Scope's hide timer needs it
            Binding {
                target: root
                property: "hovered"
                value: flyoutHover.hovered || mediaHover.hovered || toolsHover.hovered
            }

            Item {
                id: scene
                anchors.fill: parent

                Item {
                    id: hitbox
                    width: win.activeCard.width * root.scaleFactor
                    height: (win.activeCard.height + root.toolsHeight) * root.scaleFactor
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.curX
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: root.bottomGap - root.curY - root.toolsHeight * root.scaleFactor

                    onWidthChanged: root.hitW = width
                    Component.onCompleted: root.hitW = width
                }

                OsdCard {
                    id: flyout
                    host: root
                    xOffset: root.volOffsetX
                    yOffset: root.volOffsetY
                    open: win.reveal && root.showing && !root.showMedia
                    width: root.flyoutWidth
                    height: 56
                    radius: 20

                    HoverHandler {
                        id: flyoutHover
                        enabled: flyout.open
                    }

                    // Same layout/typography as SysOsd (brightness): title | bar | value.
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
                            text: "Volume"
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.text
                        }

                        Item {
                            width: parent.width - 118 - 52 - parent.spacing * 2
                            height: 5
                            anchors.verticalCenter: parent.verticalCenter

                            Rectangle {
                                anchors.fill: parent
                                radius: 4
                                color: Theme.alpha(Theme.text, 0.25)
                            }
                            Rectangle {
                                visible: !root.muted
                                width: parent.width * Math.min(root.volume, 1)
                                height: parent.height
                                radius: 4
                                color: Theme.text
                                Behavior on width { NumberAnimation { duration: 100 } }
                            }
                        }

                        Text {
                            width: 52
                            horizontalAlignment: Text.AlignRight
                            verticalAlignment: Text.AlignVCenter
                            text: root.muted ? "Muted" : Math.round(root.volume * 100) + "%"
                            font.pixelSize: 12
                            font.bold: true
                            color: Theme.text
                        }
                    }
                }

                OsdCard {
                    id: mediaPanel
                    host: root
                    xOffset: root.offsetX
                    yOffset: root.offsetY
                    open: win.reveal && root.showing && root.showMedia
                    width: root.portrait ? root.portraitWidth : root.mediaWidth
                    height: mediaCol.height + 28
                    radius: 24

                    readonly property bool artShown: root.showArt
                        && root.artUrl !== "" && artImg.status !== Image.Error

                    HoverHandler {
                        id: mediaHover
                        enabled: mediaPanel.open
                    }

                    MouseArea {
                        anchors.fill: parent
                        enabled: mediaPanel.open
                    }

                    Column {
                        id: mediaCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.topMargin: 14
                        anchors.leftMargin: root.portrait ? 20 : 25
                        anchors.rightMargin: root.portrait ? 20 : 25
                        spacing: 6

                        Item {
                            id: topBlock
                            width: parent.width
                            readonly property real artSize: mediaPanel.artShown ? (root.portrait ? width : root.artSize) : 0
                            height: root.portrait
                                ? artSize + (artSize > 0 ? 8 : 0) + textCol.height
                                : Math.max(artSize, textCol.height)

                            Item {
                                visible: mediaPanel.artShown
                                width: topBlock.artSize
                                height: topBlock.artSize

                                Image {
                                    id: artImg
                                    anchors.fill: parent
                                    source: root.showArt ? root.artUrl : ""
                                    sourceSize: Qt.size(400, 400)
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                    smooth: true
                                    visible: false
                                }

                                Rectangle {
                                    id: artMask
                                    anchors.fill: parent
                                    radius: root.portrait ? 16 : 10
                                    visible: false
                                    layer.enabled: true
                                }

                                MultiEffect {
                                    anchors.fill: parent
                                    source: artImg
                                    maskEnabled: true
                                    maskSource: artMask
                                    opacity: root.artOpacity / 100
                                }
                            }

                            Column {
                                id: textCol
                                readonly property bool sameLine: !root.portrait && !root.artistBelow
                                x: root.portrait ? 0 : (topBlock.artSize > 0 ? topBlock.artSize + 12 : 0)
                                y: root.portrait
                                    ? (topBlock.artSize > 0 ? topBlock.artSize + 8 : 0)
                                    : (topBlock.height - height) / 2
                                width: topBlock.width - x
                                spacing: 2

                                Item {
                                    width: parent.width
                                    height: titleText.implicitHeight

                                    Text {
                                        id: titleText
                                        width: textCol.sameLine ? parent.width / 2 - 5 : parent.width
                                        text: root.title || "Nothing playing"
                                        horizontalAlignment: root.portrait ? Text.AlignHCenter : Text.AlignLeft
                                        elide: Text.ElideRight
                                        font.pixelSize: 13
                                        font.bold: true
                                        color: Theme.text
                                    }
                                    Text {
                                        visible: textCol.sameLine
                                        anchors.right: parent.right
                                        width: parent.width / 2 - 5
                                        text: root.artist || "No artist"
                                        horizontalAlignment: Text.AlignRight
                                        elide: Text.ElideLeft
                                        font.pixelSize: 11
                                        color: Theme.text
                                        opacity: 0.65
                                    }
                                }

                                Text {
                                    visible: !textCol.sameLine
                                    width: parent.width
                                    text: root.artist || "No artist"
                                    horizontalAlignment: root.portrait ? Text.AlignHCenter : Text.AlignLeft
                                    elide: Text.ElideRight
                                    font.pixelSize: 11
                                    color: Theme.text
                                    opacity: 0.65
                                }
                            }
                        }

                        Item {
                            id: visualizer
                            visible: root.showVisualizer
                            width: parent.width
                            height: root.barHeight
                            readonly property real barSpacing: root.barSpacing
                            readonly property real barWidth: Math.max(1, (width - barSpacing * (root.barCount - 1)) / root.barCount)

                            Repeater {
                                model: root.barCount
                                Rectangle {
                                    required property int index
                                    x: index * (visualizer.barWidth + visualizer.barSpacing)
                                    width: visualizer.barWidth
                                    radius: Math.min(root.barRadius, width / 2)
                                    color: Theme.text
                                    opacity: (((index + 0.5) / root.barCount) <= root.progress
                                              ? root.barOpacity : root.barDimOpacity) / 100
                                    height: Math.max(3, ((root.bars[index] ?? 0) / 100) * visualizer.height)
                                    y: visualizer.height - height
                                    Behavior on height { NumberAnimation { duration: 60 } }
                                    Behavior on opacity { NumberAnimation { duration: 200 } }
                                }
                            }
                        }

                        Item {
                            visible: !root.showVisualizer
                            width: parent.width
                            height: Math.min(root.barHeight, 20)

                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width
                                height: 4
                                radius: Math.min(root.barRadius, 2)
                                color: Theme.text
                                opacity: root.barDimOpacity / 100
                            }
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width * root.progress
                                height: 4
                                radius: Math.min(root.barRadius, 2)
                                color: Theme.text
                                opacity: root.barOpacity / 100
                            }
                        }

                        Item {
                            width: parent.width
                            height: 26

                            Row {
                                anchors.centerIn: parent
                                spacing: 28

                                GlyphButton {
                                    text: "󰒮"
                                    font.pixelSize: 19
                                    onClicked: root.mediaCmd("previous")
                                }
                                GlyphButton {
                                    text: root.playing ? "󰏤" : "󰐊"
                                    font.pixelSize: 21
                                    onClicked: root.mediaCmd("play-pause")
                                }
                                GlyphButton {
                                    text: "󰒭"
                                    font.pixelSize: 19
                                    onClicked: root.mediaCmd("next")
                                }
                            }
                        }
                    }
                }

                Item {
                    id: tools
                    width: win.activeCard.width
                    height: root.toolsHeight
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: root.curX
                    // Drag handle sits just below the (bottom-anchored) card.
                    anchors.top: win.activeCard.bottom
                    transformOrigin: Item.Top
                    scale: root.scaleFactor
                    visible: opacity > 0
                    opacity: (root.showing && (root.hovered || root.dragging)) ? 1 : 0
                    Behavior on opacity { NumberAnimation { duration: 150 } }

                    HoverHandler {
                        id: toolsHover
                        enabled: root.showing
                    }

                    Item {
                        anchors.centerIn: parent
                        width: 60
                        height: parent.height

                        Rectangle {
                            anchors.centerIn: parent
                            width: 36; height: 4; radius: 2
                            color: Theme.text
                            opacity: (dragArea.containsMouse || root.dragging) ? 1 : 0.3
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        DragArea {
                            id: dragArea
                            anchors.fill: parent
                            host: root
                            scene: scene
                        }
                    }

                    FooterButton {
                        visible: root.showMedia
                        anchors.right: parent.right
                        anchors.rightMargin: 8
                        anchors.verticalCenter: parent.verticalCenter
                        width: 18; height: 18
                        color: "transparent"
                        label: "\uDB81\uDC03"
                        fontSize: 13
                        active: root.pinned
                        opacity: (hovered || root.pinned) ? 1 : 0.3
                        onClicked: root.togglePinned()
                    }
                }
            }
        }
    }

    // ---- reusable components -----------------------------------------------
    component OsdCard: Rectangle {
        property bool open: false
        property var host
        property real xOffset: 0
        property real yOffset: 0

        color: host.cardColor
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.horizontalCenterOffset: xOffset
        anchors.bottom: parent.bottom
        anchors.bottomMargin: host.bottomGap - yOffset
        transformOrigin: Item.Bottom
        opacity: open ? 1 : 0
        visible: opacity > 0
        scale: (open ? 1 : 0.9) * host.scaleFactor

        Behavior on opacity { NumberAnimation { duration: 150 } }
        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutCubic } }
    }

    component FooterButton: Rectangle {
        id: fb
        property string label: ""
        property int fontSize: 11
        property bool active: false
        readonly property bool hovered: fbArea.containsMouse
        signal clicked()

        width: 16; height: 16; radius: 6
        color: Theme.bg
        Behavior on opacity { NumberAnimation { duration: 120 } }

        Text {
            anchors.centerIn: parent
            text: fb.label
            font.family: "Symbols Nerd Font"
            font.pixelSize: fb.fontSize
            font.bold: true
            color: fb.active ? Theme.accent : (fb.hovered ? Theme.text : Theme.textDim)
        }

        MouseArea {
            id: fbArea
            anchors.fill: parent
            hoverEnabled: true
            onClicked: fb.clicked()
        }
    }

    component GlyphButton: Text {
        signal clicked()
        font.family: "Symbols Nerd Font"
        color: Theme.text
        MouseArea { anchors.fill: parent; onClicked: parent.clicked() }
    }

    component DragArea: MouseArea {
        id: da
        property var host
        property Item scene
        property real pressX: 0
        property real pressY: 0
        property real startX: 0
        property real startY: 0

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton
        cursorShape: host.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor

        function finish() {
            if (!host.dragging)
                return
            host.dragging = false
            host.saveState()
        }

        onPressed: function (mouse) {
            var p = da.mapToItem(da.scene, mouse.x, mouse.y)
            pressX = p.x
            pressY = p.y
            startX = host.curX
            startY = host.curY
            host.dragging = true
        }
        onPositionChanged: function (mouse) {
            if (!host.dragging)
                return
            var p = da.mapToItem(da.scene, mouse.x, mouse.y)
            host.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
        }
        onReleased: finish()
        onCanceled: finish()
        onDoubleClicked: host.resetPos(host.showMedia)
    }

}