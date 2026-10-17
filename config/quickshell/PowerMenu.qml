pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland

Scope {
    id: root
    // ---- lifecycle -------------------------------------------------------
    property bool showing: false      // logical "menu is open"
    property bool mounted: false      // window exists
    property var targetScreen: Quickshell.screens[0]
    property real winW: 0             // reported by the window while mounted
    property real winH: 0

    onShowingChanged: {
        if (showing) {
            unmountTimer.stop()
            mounted = true
        } else {
            unmountTimer.restart()
        }
    }

    // must be longer than the longest fade-out (panel opacity = animMs)
    Timer {
        id: unmountTimer
        interval: root.animMs + 120
        onTriggered: {
            root.mounted = false
            root.winW = 0
            root.winH = 0
        }
    }

    // ---- settings specs (numbers) ----------------------------------------
    readonly property var numSpec: ({
        menuSize:     { min: 70,  max: 160, def: 100, step: 10, unit: "%" },
        animMs:       { min: 0,   max: 500, def: 200, step: 20, unit: " ms" },

        cardWidth:    { min: 60, max: 700, def: 284, step: 5, unit: "px" },
        itemHeight:   { min: 40,  max: 120, def: 56,  step: 4,  unit: "px" },
        itemSpacing:  { min: 0,   max: 24,  def: 8,   step: 2,  unit: "px" },
        panelPadding: { min: 0,   max: 24,  def: 6,   step: 2,  unit: "px" },
        topGap:       { min: 0,   max: 120, def: 12,  step: 4,  unit: "px" },
        sideGap:      { min: 0,   max: 120, def: 24,  step: 4,  unit: "px" },

        panelRadius:  { min: 0,   max: 40,  def: 20,  step: 2,  unit: "px" },
        itemRadius:   { min: 0,   max: 40,  def: 12,  step: 2,  unit: "px" },
        iconSize:     { min: 12,  max: 56,  def: 20,  step: 2,  unit: "px" },
        labelSize:    { min: 9,   max: 22,  def: 11,  step: 1,  unit: "px" },
        borderWidth:  { min: 0,   max: 4,   def: 1,   step: 1,  unit: "px" },

        // Panel background defaults to the live SUPER+O opacity so the menu
        // matches windows/bar/other panels without needing its own slider.
        panelOpacity: { min: 0,   max: 100, def: Math.round((Theme.bg.a ?? 1) * 20) * 5, step: 5, unit: "%" },
        itemOpacity:  { min: 0,   max: 100, def: Math.round((Theme.bg.a ?? 1) * 20) * 5, step: 5, unit: "%" },
        hoverBoost:   { min: 0,   max: 40,  def: 12,  step: 2,  unit: "%" },
        dimOpacity:   { min: 0,   max: 80,  def: 0,   step: 5,  unit: "%" }
    })
    readonly property var numKeys: Object.keys(numSpec)

    readonly property var boolDefaults: ({
        horizontal: false,
        showIcons: true,
        showLabels: true,
        showKeyHints: true,
        confirmDangerous: false,
        wrapNav: true,
        hoverSelect: true,
        closeOnOutside: true
    })
    readonly property var boolKeys: Object.keys(boolDefaults)

    readonly property var posKeys: ["offsetX", "offsetY"]

    property real offsetX: 0
    property real offsetY: 0

    property int menuSize: numSpec.menuSize.def
    property int animMs: numSpec.animMs.def
    property int cardWidth: numSpec.cardWidth.def
    property int itemHeight: numSpec.itemHeight.def
    property int itemSpacing: numSpec.itemSpacing.def
    property int panelPadding: numSpec.panelPadding.def
    property int topGap: numSpec.topGap.def
    property int sideGap: numSpec.sideGap.def
    property int panelRadius: numSpec.panelRadius.def
    property int itemRadius: numSpec.itemRadius.def
    property int iconSize: numSpec.iconSize.def
    property int labelSize: numSpec.labelSize.def
    property int borderWidth: numSpec.borderWidth.def
    property int panelOpacity: numSpec.panelOpacity.def
    property int itemOpacity: numSpec.itemOpacity.def
    property int hoverBoost: numSpec.hoverBoost.def
    property int dimOpacity: numSpec.dimOpacity.def

    property bool horizontal: boolDefaults.horizontal
    property bool showIcons: boolDefaults.showIcons
    property bool showLabels: boolDefaults.showLabels
    property bool showKeyHints: boolDefaults.showKeyHints
    property bool confirmDangerous: boolDefaults.confirmDangerous
    property bool wrapNav: boolDefaults.wrapNav
    property bool hoverSelect: boolDefaults.hoverSelect
    property bool closeOnOutside: boolDefaults.closeOnOutside

    property bool dragging: false
    property int currentIndex: 0
    property string confirmName: ""
    property var hiddenNames: []

    readonly property int edgeGap: 0
    // how much of the panel must stay on screen when dragged past borders
    readonly property int keepVisible: 40

    // icons: box around the glyph = icon + 12px, texture decoded at 2x
    readonly property int iconBox: showIcons ? iconSize + 12 : 0
    readonly property int iconRes: Math.max(48, iconSize * 2)
    readonly property bool lightMode: Theme._bgBase.hslLightness > 0.5

    // colours derived from the theme + opacity settings
    readonly property color itemColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, itemOpacity / 100)
    readonly property color itemHoverColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b,
                                                    Math.min(1, itemOpacity / 100 + hoverBoost / 100))

    readonly property string iconDir: "file://" + Quickshell.env("HOME") + "/.config/quickshell/imgs/"
    readonly property string statePath: Quickshell.env("HOME") + "/.config/quickshell/state/powermenu-state.json"

    onCurrentIndexChanged: confirmName = ""

    // ---- actions ----------------------------------------------------------
    readonly property var actions: [
        { name: "shutdown",  label: "Shut down", icon: "shutdown.png",  key: "s", danger: true,  cmd: ["systemctl", "poweroff"] },
        { name: "reboot",    label: "Reboot",    icon: "reboot.png",    key: "r", danger: true,  cmd: ["systemctl", "reboot"] },
        { name: "suspend",   label: "Suspend",   icon: "suspend.png",   key: "z", danger: false, cmd: ["systemctl", "suspend"] },
        { name: "logout",    label: "Log out",   icon: "logout.png",    key: "e", danger: true,  dispatch: "hl.dsp.exit()" },
        { name: "hibernate", label: "Hibernate", icon: "hibernate.png", key: "h", danger: false, cmd: ["systemctl", "hibernate"] }
    ]

    readonly property var visibleActions: actions.filter(function (a) {
        return root.hiddenNames.indexOf(a.name) < 0
    })

    function iconFile(name) {
        if (!root.lightMode) return name
        return name.replace(/\.png$/, "2.png")
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, Math.round(v)))
    }

    function runAction(a) {
        if (root.confirmDangerous && a.danger && root.confirmName !== a.name) {
            root.confirmName = a.name
            return
        }
        if (a.dispatch)
            Hyprland.dispatch(a.dispatch)
        else if (a.cmd)
            Quickshell.execDetached({ command: a.cmd })
        root.closeMenu()
    }

    function moveSelection(d) {
        var n = root.visibleActions.length
        if (n <= 0) return
        var i = root.currentIndex + d
        if (root.wrapNav)
            i = (i % n + n) % n
        else
            i = Math.max(0, Math.min(n - 1, i))
        root.currentIndex = i
    }

    function openMenu() {
        var mon = Hyprland.focusedMonitor
        if (mon) {
            var scr = Quickshell.screens.find(function (s) { return s.name === mon.name })
            if (scr) root.targetScreen = scr
        }
        currentIndex = 0
        confirmName = ""
        dragging = false
        showing = true   // onShowingChanged mounts the window
    }

    function closeMenu() {
        showing = false
        dragging = false
        confirmName = ""
    }
    function toggleMenu() { showing ? closeMenu() : openMenu() }

    function resetPosition() {
        root.offsetX = 0
        root.offsetY = 0
        root.saveState()
    }

    function saveState() {
        var s = { hidden: root.hiddenNames }
        posKeys.forEach(function (k) { s[k] = root[k] })
        numKeys.forEach(function (k) { s[k] = root[k] })
        boolKeys.forEach(function (k) { s[k] = root[k] })
        stateFile.setText(JSON.stringify(s))
    }

    // Allows the panel to go past the screen borders (left, right, bottom),
    // keeping at least `keepVisible` px on screen. Top is kept on screen so the
    // drag handle always stays reachable.
    function setPosition(x, y) {
        if (root.winW <= 0 || root.winH <= 0) {
            root.offsetX = x
            root.offsetY = y
            return
        }
        var s = root.menuSize / 100
        var kv = root.keepVisible
        var minX = kv - root.winW + root.sideGap
        var maxX = root.sideGap + root.cardWidth * s - kv
        var minY = root.edgeGap - root.topGap
        var maxY = Math.max(minY, root.winH - kv - root.topGap)
        root.offsetX = Math.max(minX, Math.min(maxX, x))
        root.offsetY = Math.max(minY, Math.min(maxY, y))
    }

    // ---- always-on services (cheap) --------------------------------------
    IpcHandler {
        target: "powermenu"
        function toggle(): void { root.toggleMenu() }
        function show(): void { root.openMenu() }
        function hide(): void { root.closeMenu() }
    }

    FileView {
        id: stateFile
        path: root.statePath
        printErrors: false

        onLoaded: {
            try {
                var s = JSON.parse(stateFile.text())
                var valid = root.actions.map(function (a) { return a.name })

                if (Array.isArray(s.hidden)) {
                    var h = s.hidden.filter(function (n) { return valid.indexOf(n) >= 0 })
                    if (h.length < valid.length) root.hiddenNames = h
                }

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
                console.warn("powermenu: could not read saved state:", e)
            }
        }
    }

    // ---- the menu window: only exists while mounted -----------------------
    LazyLoader {
        active: root.mounted

        PanelWindow {
            id: win
            screen: root.targetScreen

            property bool reveal: false

            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "powermenu"
            WlrLayershell.keyboardFocus: root.showing
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            mask: Region { item: root.showing ? menuRoot : null }

            onWidthChanged: {
                root.winW = width
                if (root.showing) root.setPosition(root.offsetX, root.offsetY)
            }
            onHeightChanged: {
                root.winH = height
                if (root.showing) root.setPosition(root.offsetX, root.offsetY)
            }

            Component.onCompleted: {
                menuRoot.forceActiveFocus()
                root.setPosition(root.offsetX, root.offsetY)
                Qt.callLater(function () {
                    win.reveal = Qt.binding(function () { return root.showing })
                })
            }

            Item {
                id: menuRoot
                anchors.fill: parent
                focus: true
                Keys.onPressed: function (event) {
                    if (!root.showing) return
                    var t = event.text.toLowerCase()

                    if (event.key === Qt.Key_Escape) {
                        root.closeMenu()
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Down
                            || event.key === Qt.Key_Right
                            || event.key === Qt.Key_Tab) {
                        root.moveSelection(1)
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Up
                            || event.key === Qt.Key_Left
                            || event.key === Qt.Key_Backtab) {
                        root.moveSelection(-1)
                        event.accepted = true
                        return
                    }
                    if (event.key === Qt.Key_Return
                            || event.key === Qt.Key_Enter
                            || event.key === Qt.Key_Space) {
                        root.runAction(root.visibleActions[root.currentIndex])
                        event.accepted = true
                        return
                    }
                    for (var i = 0; i < root.visibleActions.length; i++) {
                        if (t === root.visibleActions[i].key) {
                            root.currentIndex = i
                            root.runAction(root.visibleActions[i])
                            event.accepted = true
                            return
                        }
                    }
                }

                // screen dim
                Rectangle {
                    anchors.fill: parent
                    color: "black"
                    opacity: win.reveal ? root.dimOpacity / 100 : 0
                    visible: opacity > 0
                    Behavior on opacity { NumberAnimation { duration: root.animMs } }
                }

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        if (root.closeOnOutside)
                            root.closeMenu()
                    }
                }

                Rectangle {
                    id: panel
                    width: root.cardWidth
                    height: panelCol.height + 2 * root.panelPadding
                    radius: root.panelRadius
                    // No container background: entries float as separate
                    // cards with gaps (itemSpacing), no parent box.
                    color: "transparent"
                    transformOrigin: Item.TopRight
                    scale: root.menuSize / 100
                    anchors.top: parent.top
                    anchors.topMargin: root.topGap + root.offsetY
                    anchors.right: parent.right
                    anchors.rightMargin: root.sideGap - root.offsetX
                    opacity: win.reveal ? 1 : 0
                    visible: opacity > 0

                    Behavior on anchors.rightMargin {
                        enabled: !root.dragging && root.showing
                        NumberAnimation { duration: root.animMs * 1.1; easing.type: Easing.OutCubic }
                    }
                    Behavior on anchors.topMargin {
                        enabled: !root.dragging && root.showing
                        NumberAnimation { duration: root.animMs * 1.1; easing.type: Easing.OutCubic }
                    }
                    Behavior on scale {
                        enabled: root.showing
                        NumberAnimation { duration: root.animMs; easing.type: Easing.OutCubic }
                    }
                    Behavior on opacity {
                        NumberAnimation { duration: root.animMs * 0.9; easing.type: Easing.OutCubic }
                    }
                    onHeightChanged: if (root.showing) root.setPosition(root.offsetX, root.offsetY)

                    MouseArea { anchors.fill: parent }

                    Column {
                        id: panelCol
                        anchors.top: parent.top
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.margins: root.panelPadding
                        spacing: 6

                        // ---- drag handle ----
                        Item {
                            id: header
                            width: parent.width
                            height: 12

                            Rectangle {
                                anchors.centerIn: parent
                                width: 36; height: 4; radius: 2
                                color: Theme.bg
                                opacity: (dragArea.containsMouse || root.dragging) ? 1 : 0.1
                                Behavior on opacity { NumberAnimation { duration: 150 } }
                            }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                hoverEnabled: true
                                acceptedButtons: Qt.LeftButton
                                cursorShape: root.dragging ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                                property real pressX: 0
                                property real pressY: 0
                                property real startX: 0
                                property real startY: 0
                                onPressed: function (mouse) {
                                    var p = dragArea.mapToItem(menuRoot, mouse.x, mouse.y)
                                    pressX = p.x
                                    pressY = p.y
                                    startX = root.offsetX
                                    startY = root.offsetY
                                    root.dragging = true
                                }
                                onPositionChanged: function (mouse) {
                                    if (!root.dragging) return
                                    var p = dragArea.mapToItem(menuRoot, mouse.x, mouse.y)
                                    root.setPosition(startX + (p.x - pressX), startY + (p.y - pressY))
                                }
                                onReleased: {
                                    if (!root.dragging) return
                                    root.dragging = false
                                    root.saveState()
                                }
                                onCanceled: {
                                    if (!root.dragging) return
                                    root.dragging = false
                                    root.saveState()
                                }
                                onDoubleClicked: root.resetPosition()
                            }
                        }

                        // ---- action list (vertical list or horizontal row) ----
                        Grid {
                            id: actionGrid
                            width: parent.width
                            columns: root.horizontal ? Math.max(1, root.visibleActions.length) : 1
                            rowSpacing: root.itemSpacing
                            columnSpacing: root.itemSpacing

                            Repeater {
                                model: root.visibleActions
                                delegate: Rectangle {
                                    id: entry
                                    required property var modelData
                                    required property int index
                                    readonly property bool focused: index === root.currentIndex
                                    readonly property bool pending: root.confirmName === modelData.name
                                    readonly property int count: root.visibleActions.length

                                    width: root.horizontal
                                        ? Math.max(0, (actionGrid.width - root.itemSpacing * (count - 1)) / count)
                                        : actionGrid.width
                                    height: root.itemHeight
                                    radius: root.itemRadius
                                    color: entryArea.pressed || entryArea.containsMouse || entry.focused
                                        ? root.itemHoverColor
                                        : root.itemColor
                                    border.width: entry.focused ? root.borderWidth : 0
                                    border.color: entry.pending ? Theme.text : Theme.accent
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Item {
                                        id: eThumb
                                        visible: root.showIcons
                                        width: root.iconBox
                                        height: root.iconBox
                                        x: root.horizontal ? (entry.width - width) / 2 : 10
                                        y: (root.horizontal && root.showLabels)
                                            ? (entry.height - height - eLabel.implicitHeight - 2) / 2
                                            : (entry.height - height) / 2

                                        Image {
                                            anchors.centerIn: parent
                                            width: root.iconSize
                                            height: root.iconSize
                                            sourceSize: Qt.size(root.iconRes, root.iconRes)
                                            fillMode: Image.PreserveAspectFit
                                            smooth: true
                                            asynchronous: true
                                            source: root.iconDir + root.iconFile(entry.modelData.icon)
                                        }
                                    }

                                    Text {
                                        id: eLabel
                                        visible: root.showLabels
                                        text: entry.pending ? entry.modelData.label + "?" : entry.modelData.label
                                        font.pixelSize: root.labelSize
                                        font.bold: true
                                        color: entry.pending ? Theme.accent : Theme.text
                                        elide: Text.ElideRight
                                        horizontalAlignment: root.horizontal ? Text.AlignHCenter : Text.AlignLeft
                                        x: root.horizontal
                                            ? 2
                                            : (root.showIcons ? eThumb.x + eThumb.width + 10 : 14)
                                        y: root.horizontal
                                            ? (root.showIcons
                                                ? eThumb.y + eThumb.height + 2
                                                : (entry.height - implicitHeight) / 2)
                                            : (entry.height - implicitHeight) / 2
                                        width: root.horizontal
                                            ? entry.width - 4
                                            : Math.max(0, entry.width - x - ((root.showKeyHints) ? 40 : 12))
                                    }

                                    Rectangle {
                                        visible: root.showKeyHints && !root.horizontal
                                        anchors.right: parent.right
                                        anchors.rightMargin: 10
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: 20; height: 20; radius: 6
                                        color: Theme.alpha(Theme.text, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: entry.modelData.key.toUpperCase()
                                            font.pixelSize: 9
                                            font.bold: true
                                            color: Theme.textDim
                                        }
                                    }

                                    MouseArea {
                                        id: entryArea
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onEntered: if (root.hoverSelect) root.currentIndex = entry.index
                                        onClicked: {
                                            root.currentIndex = entry.index
                                            root.runAction(entry.modelData)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

}