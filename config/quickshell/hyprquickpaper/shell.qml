import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Qt.labs.folderlistmodel
import Quickshell.Wayland

PanelWindow {
    id: main
    readonly property real ui: Screen.height / 1080
    readonly property real refWidth: 1920
    readonly property real refHeight: 500
    property int animDuration: 220
    property real zoomScale: 0.8
    property real edgeScale: 0.3
    property real skewFactor: 0
    property real baseSpacing: 0
    property real edgeSpacing: 80
    property int startPosition: 4
    property bool shadowEnabled: true
    property color shadowColor: "#000000"
    property real shadowOpacity: 0.4
    property real shadowBlur: 0.45
    property real shadowX: 6
    property real shadowY: 6
    property string wallpaperPath: configs.wallpaper_path.replace("$HOME", Quickshell.env("HOME"))
    property string cachePath: configs.cache_path.replace("$HOME", Quickshell.env("HOME"))

    property bool showEmpty: false
    property string currentWallpaper: ""
    onCurrentWallpaperChanged: {
        if (currentWallpaper === "" || list.userMoved || folderModel.count <= 0 || folderModel.status !== FolderListModel.Ready) return
        list.currentIndex = list.clampIndex(list.indexOfCurrent())
    }
    readonly property bool looksEmpty: wallpaperPath !== ""
                                       && folderModel.status === FolderListModel.Ready
                                       && folderModel.count === 0

    onLooksEmptyChanged: {
        if (looksEmpty) {
            emptyDelay.restart()
        } else {
            emptyDelay.stop()
            showEmpty = false
        }
    }

    implicitHeight: Screen.height
    implicitWidth: Screen.width
    color: "transparent"
    aboveWindows: true
    exclusionMode: "Ignore"
    exclusiveZone: 1
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    Component.onCompleted: Quickshell.execDetached(["bash", Quickshell.shellPath("cache.sh"), Quickshell.shellDir])

    FileView {
        path: Quickshell.shellPath("config.json")
        watchChanges: true
        onFileChanged: reload()

        JsonAdapter {
            id: configs
            property string wallpaper_path
            property string cache_path
            property int number_of_pictures
            property string border_color
        }
    }

    FileView {
        id: stateFile
        path: Quickshell.env("HOME") + "/.local/state/theme/state.json"
        onLoaded: {
            try {
                const s = JSON.parse(text());
                if (typeof s.wallpaper === "string" && s.wallpaper !== "") {
                    const parts = s.wallpaper.split("/");
                    main.currentWallpaper = parts[parts.length - 1];
                }
            } catch (e) {}
        }
    }

    FolderListModel {
        id: folderModel
        folder: "file://" + main.wallpaperPath
        showDirs: false
        nameFilters: ["*.png", "*.jpg", "*.jpeg", "*.webp"]
        sortField: FolderListModel.Name

        // Center only once the model is fully loaded AND sorted. While it is
        // still Loading, row indices shuffle (unsorted rows, then the sorted
        // order is published with no further count change), so centering
        // earlier locks onto the wrong row permanently.
        onStatusChanged: { if (status === FolderListModel.Ready) list.centerOnStart(); }
        onCountChanged: { if (status === FolderListModel.Ready) list.centerOnStart(); }
    }

    // Dark veil so thumbnails don't blend into the desktop wallpaper.
    Rectangle {
        anchors.fill: parent
        color: "#b3000000"
        z: 0
    }

    MouseArea {
        id: outsideClickArea
        anchors.fill: parent
        z: 0
        onClicked: Qt.quit()
    }

    Timer {
        id: emptyDelay
        interval: 300
        onTriggered: main.showEmpty = main.looksEmpty
    }

    Column {
        id: emptyState
        anchors.centerIn: parent
        spacing: 10 * main.ui
        z: 2
        visible: main.showEmpty

        Text {
            text: "No wallpapers found"
            color: "#ffffff"
            font.pixelSize: 22 * main.ui
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }

        Text {
            text: "Add images to:"
            color: "#aaaaaa"
            font.pixelSize: 13 * main.ui
            anchors.horizontalCenter: parent.horizontalCenter
        }

        TextEdit {
            id: pathText
            text: main.wallpaperPath
            color: "#dddddd"
            font.pixelSize: 14 * main.ui
            readOnly: true
            selectByMouse: true
            anchors.horizontalCenter: parent.horizontalCenter
            horizontalAlignment: Text.AlignHCenter
        }
    }

    ListView {
        id: list
        width: parent.width
        height: tileHeight
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.verticalCenter: parent.verticalCenter
        z: 1
        focus: true
        model: folderModel
        orientation: ListView.Horizontal
        spacing: 0
        clip: true
        cacheBuffer: 400 * main.ui
        boundsBehavior: Flickable.StopAtBounds

        // ListView itself keeps the current tile centered: selection and
        // view can never disagree. No manual contentX math.
        highlightRangeMode: ListView.StrictlyEnforceRange
        preferredHighlightBegin: width / 2 - tileWidth / 2
        preferredHighlightEnd: width / 2 - tileWidth / 2
        highlightMoveDuration: main.animDuration

        readonly property real tileHeight: main.refHeight * main.ui
        readonly property real tileWidth: (main.refWidth / Math.max(1, configs.number_of_pictures) - 10) * main.ui

        readonly property real viewportCenterX: width / 2
        readonly property real falloffRadius: (main.refWidth / 2) * main.ui

        readonly property real sideMargin: Math.max(0, viewportCenterX - tileWidth / 2)
        property bool userMoved: false

        leftMargin: sideMargin
        rightMargin: sideMargin

        function clampIndex(i) { return Math.max(0, Math.min(i, count - 1)) }

        // Prefer the current wallpaper so it opens centered/popped-up.
        function indexOfCurrent() {
            if (main.currentWallpaper !== "") {
                for (let i = 0; i < count; i++) {
                    if (folderModel.get(i, "fileName") === main.currentWallpaper) return i;
                }
            }
            return clampIndex(main.startPosition);
        }

        function centerOnStart() {
            if (userMoved || count <= 0 || configs.number_of_pictures <= 0 || folderModel.status !== FolderListModel.Ready) return
            currentIndex = indexOfCurrent()
        }

        function activateCurrent() {
            if (count <= 0) return
            Quickshell.execDetached(["bash", Quickshell.shellPath("commands.sh"), folderModel.get(currentIndex, "filePath")])
            Qt.quit()
        }

        onCountChanged: centerOnStart()
        onWidthChanged: centerOnStart()
        onTileWidthChanged: centerOnStart()

        Connections {
            target: configs
            function onNumber_of_picturesChanged() { list.centerOnStart() }
        }

        delegate: Item {
            id: delegateItem
            width: list.tileWidth
            height: list.tileHeight

            property bool active: index === list.currentIndex
            readonly property real baseWidth: list.tileWidth
            readonly property real baseCenterX: x - list.contentX + baseWidth / 2
            readonly property real distance: Math.abs(baseCenterX - list.viewportCenterX)
            readonly property real fraction: Math.min(1, distance / list.falloffRadius)
            readonly property real compression: { const t = fraction; return t * t * t * t }
            readonly property real edgeOffset: {
                const amount = main.edgeSpacing * main.ui * compression
                return baseCenterX < list.viewportCenterX ? amount : -amount
            }
            readonly property real scaleFactor: {
                const t = 1 - fraction * fraction * (3 - 2 * fraction)
                return main.edgeScale + (main.zoomScale - main.edgeScale) * t
            }

            Item {
                id: content
                anchors.verticalCenter: parent.verticalCenter
                width: delegateItem.baseWidth * delegateItem.scaleFactor
                height: delegateItem.height * Math.min(1, delegateItem.scaleFactor)
                x: (delegateItem.baseWidth - width) / 2 + delegateItem.edgeOffset

                Image {
                    id: shadowImage
                    x: main.shadowX * main.ui
                    y: main.shadowY * main.ui
                    width: parent.width
                    height: parent.height
                    source: img.source
                    sourceSize.width: img.sourceSize.width
                    sourceSize.height: img.sourceSize.height
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    visible: main.shadowEnabled && delegateItem.active
                    opacity: main.shadowOpacity
                    layer.enabled: true
                    layer.effect: MultiEffect { brightness: -1; blurEnabled: true; blur: main.shadowBlur }
                    transform: Shear { xFactor: main.skewFactor }
                }

                // Cheap static shadow for non-centered tiles: a blurred live
                // shadow on every tile (~10 visible) tanks the frame rate
                // while scrolling, so only the active tile gets the real one.
                Rectangle {
                    x: main.shadowX * main.ui
                    y: main.shadowY * main.ui
                    width: parent.width
                    height: parent.height
                    radius: Math.min(width, height) * 0.04
                    color: main.shadowColor
                    opacity: (main.shadowEnabled && !delegateItem.active) ? main.shadowOpacity * 0.7 : 0
                    visible: opacity > 0
                    transform: Shear { xFactor: main.skewFactor }
                }

                Text {
                    id: alt
                    text: ""
                    color: configs.border_color
                    anchors.centerIn: parent
                    font.pixelSize: 16 * main.ui
                    transform: Shear { xFactor: main.skewFactor }
                }

                Image {
                    id: img
                    anchors.fill: parent
                    opacity: delegateItem.active ? 0.95 : 0.45
                    fillMode: Image.PreserveAspectCrop
                    asynchronous: true
                    cache: true
                    smooth: true
                    source: "file://" + main.cachePath + fileName
                    sourceSize.width: delegateItem.baseWidth * main.zoomScale
                    sourceSize.height: delegateItem.height
                    Behavior on opacity { NumberAnimation { duration: 150 } }
                    transform: Shear { xFactor: main.skewFactor }

                    Timer {
                        id: retryTimer
                        interval: 1000
                        repeat: false
                        onTriggered: { const s = img.source; img.source = ""; img.source = s }
                    }

                    onStatusChanged: {
                        if (status === Image.Error) { alt.text = "Caching"; retryTimer.start() }
                    }
                }

                Rectangle {
                    z: 10
                    anchors.fill: parent
                    visible: delegateItem.active
                    color: "transparent"
                    border.width: Math.max(2, Math.round(3 * main.ui))
                    border.color: configs.border_color
                    transform: Shear { xFactor: main.skewFactor }
                }
            }

            MouseArea {
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                // NOTE: no hover selection here. Click a side tile to center
                // it, click the centered one to apply.
                onClicked: {
                    if (index === list.currentIndex) list.activateCurrent();
                    else {
                        list.userMoved = true;
                        list.currentIndex = index;
                    }
                }
                onWheel: function(wheel) { list.flick(-wheel.angleDelta.y * 8, 0); wheel.accepted = true }
            }
        }

        // Arrow keys (and H/L) drive our own smooth animated selection.
        // They must be accepted here, otherwise ListView's built-in
        // currentIndex navigation fights the animation and the zoomed
        // tile never follows the keys.
        Keys.onPressed: function(event) {
            if (event.key === Qt.Key_Space || event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                activateCurrent()
            } else if (event.key === Qt.Key_Left || event.key === Qt.Key_H) {
                userMoved = true
                decrementCurrentIndex()
            } else if (event.key === Qt.Key_Right || event.key === Qt.Key_L) {
                userMoved = true
                incrementCurrentIndex()
            } else if (event.key === Qt.Key_W || event.key === Qt.Key_Escape) {
                Qt.quit()
            } else {
                return
            }
            event.accepted = true
        }
    }

    // Filename pill: shows exactly which file Enter/Space will apply.
    Rectangle {
        anchors.top: list.bottom
        anchors.topMargin: 24 * main.ui
        anchors.horizontalCenter: parent.horizontalCenter
        width: nameLabel.implicitWidth + 36 * main.ui
        height: nameLabel.implicitHeight + 18 * main.ui
        radius: height / 2
        color: "#cc000000"
        border.width: 1
        border.color: configs.border_color
        z: 2
        visible: list.count > 0

        Text {
            id: nameLabel
            anchors.centerIn: parent
            text: list.count > 0 ? folderModel.get(list.currentIndex, "fileName") : ""
            color: "#ffffff"
            font.pixelSize: 15 * main.ui
        }
    }
}