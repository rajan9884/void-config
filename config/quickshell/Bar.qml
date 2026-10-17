import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Services.UPower
import Quickshell.Services.SystemTray

Scope {
    id: root

    // ───────────────────────── Config ─────────────────────────
    // Single source of truth for defaults (used by the config adapter).
    readonly property var defaults: ({
        position: "top", style: "joined", thickness: 20, margin: 4,
        scale: 1.0, bgOpacity: 0.5, border: false, radius: Theme.radius, calRadius: 15,
        statsMode: "compact", tooltips: true, tooltipHints: true,
        hidden: "stats,wall",
        startMods: "stats,ws",
        centerMods: "clock",
        endMods: "media,tray,caffeine,volume,battery,net,notif,wall,power"
    })
    readonly property var positions: ["top", "right", "bottom", "left"]
    readonly property var styles: ["floating", "joined", "strip"]
    readonly property var statsModes: ["default", "compact"]

    // Active tray entry whose popup menu is currently open
    property var activeTrayEntry: null

    // Idle-lock (hypridle) state for the caffeine module; polled so the
    // icon tracks toggles from any source (bar click, SUPER+CTRL+I, CLI).
    property bool idleOn: true
    Process {
        id: idleCheck
        command: ["sh", "-c", "pgrep -x hypridle >/dev/null && echo 1 || echo 0"]
        stdout: StdioCollector { onStreamFinished: root.idleOn = text.trim() === "1" }
    }
    Timer {
        interval: 2000; running: true; repeat: true; triggeredOnStart: true
        onTriggered: if (!idleCheck.running) idleCheck.running = true
    }
    
    FileView {
        id: cfgFile
        path: Quickshell.env("HOME") + "/.config/quickshell/state/bar-state.json"
        printErrors: false
        onAdapterUpdated: saveTimer.restart()
        onLoadFailed: error => { if (error === FileViewError.FileNotFound) writeAdapter(); }

        adapter: JsonAdapter {
            id: cfg
            property string position: root.defaults.position
            property string style: root.defaults.style
            property int thickness: root.defaults.thickness
            property int margin: root.defaults.margin
            property real scale: root.defaults.scale
            property real bgOpacity: root.defaults.bgOpacity
            property bool border: root.defaults.border
            property int radius: root.defaults.radius            // bar corner radius
            property int calRadius: root.defaults.calRadius      // calendar popup corner radius
            property string statsMode: root.defaults.statsMode   // "default" | "compact"
            property bool tooltips: root.defaults.tooltips
            property bool tooltipHints: root.defaults.tooltipHints // show "Left click: ..." lines in tooltips
            property string hidden: root.defaults.hidden         // comma list of disabled modules
            property string startMods: root.defaults.startMods
            property string centerMods: root.defaults.centerMods
            property string endMods: root.defaults.endMods
        }
    }

    Timer { id: saveTimer; interval: 300; onTriggered: cfgFile.writeAdapter() }

    // ───────────────────────── Derived layout ─────────────────────────
    readonly property bool vertical: cfg.position === "left" || cfg.position === "right"
    readonly property bool joined: cfg.style !== "floating"
    readonly property bool strip: cfg.style === "strip"
    readonly property int panelThick: vertical ? cfg.thickness + 12 : cfg.thickness
    readonly property int effEdge: strip ? 0 : cfg.margin
    readonly property int effGap: strip ? 0 : 6
    readonly property real barRadius: strip ? 0 : cfg.radius
    // Theme.bg already carries Theme.bgAlpha — replacing the alpha (not
    // multiplying it) keeps the bar at the same SUPER+O opacity as windows.
    readonly property color bgColor: Qt.rgba(Theme.bg.r, Theme.bg.g, Theme.bg.b, cfg.bgOpacity)
    readonly property color borderColor: Qt.alpha(Theme.accent, 0.25)

    function s(n) { return Math.round(n * cfg.scale); }

    readonly property var sz: ({
        stat: s(12), clock: s(12), marquee: s(11),
        icon: s(16), batIcon: s(13), batText: s(12), power: s(13),
        calTime: s(30), calDate: s(12), calMonth: s(13), calArrow: s(16),
        calWeekday: s(11), calDay: s(12)
    })
    readonly property int sizeIconGap: 12
    readonly property int iconYOffset: 1

    // margin for one side of the bar frame
    function edgeMargin(side) {
        if (cfg.position === side) return effEdge;
        const alongBar = vertical ? (side === "top" || side === "bottom")
                                  : (side === "left" || side === "right");
        return alongBar ? effGap : 0;
    }

    // ───────────────────────── Battery ─────────────────────────
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)
    readonly property int batPct: battery ? Math.round(battery.percentage * 100) : 0
    readonly property bool batCharging: battery !== null
        && (battery.state === UPowerDeviceState.Charging
            || battery.state === UPowerDeviceState.PendingCharge
            || battery.state === UPowerDeviceState.FullyCharged)
    readonly property bool batLow: battery !== null && !batCharging && batPct <= 15
    readonly property var batIcons: ["\uf244", "\uf243", "\uf242", "\uf241", "\uf240"]
    readonly property string batIcon: batIcons[batPct >= 90 ? 4 : batPct >= 65 ? 3 : batPct >= 40 ? 2 : batPct >= 15 ? 1 : 0]

    function fmtTime(sec) {
        const h = Math.floor(sec / 3600), m = Math.floor((sec % 3600) / 60);
        return h > 0 ? h + "h " + m + "m" : m + "m";
    }

    readonly property string batTip: {
        if (battery === null) return "";
        const t = batCharging ? battery.timeToFull : battery.timeToEmpty;
        const st = battery.state === UPowerDeviceState.FullyCharged ? "fully charged"
                 : batCharging ? "charging" : "on battery";
        return "Battery " + batPct + "% · " + st
            + (t > 0 ? " · " + fmtTime(t) + (batCharging ? " to full" : " left") : "");
    }

    // ───────────────────────── Module registry ─────────────────────────
    // Modules with `cmd` are rendered by the generic iconC component:
    //   g = glyph, tip = tooltip title, hint = left-click description.
    // Modules without it have a dedicated Component below (see `comps`).
    readonly property var moduleDefs: [
        { id: "logo",     l: "Void logo" },
        { id: "stats",    l: "CPU / RAM" },
        { id: "ws",       l: "Workspaces" },
        { id: "media",    l: "Media" },
        { id: "volume",   l: "Volume" },
        { id: "battery",  l: "Battery" },
        { id: "caffeine", l: "Idle / caffeine" },
        { id: "net",      l: "Network",       cmd: "qs ipc call network toggle",
                                              hint: "Open network panel" },
        { id: "notif",    l: "Notifications", cmd: "qs ipc call notifications toggle", g: "\uDB80\uDC9C",
                                              tip: "Notifications", hint: "Toggle notification panel" },
        { id: "wall",     l: "Wallpapers",    cmd: "qs -n -p ~/.config/quickshell/hyprquickpaper", g: "\uDB80\uDEE9",
                                              tip: "Wallpapers", hint: "Open wallpaper picker" },
        { id: "tray",     l: "System tray" },
        { id: "power",    l: "Power",         cmd: "qs ipc call powermenu toggle", g: "\u23FB",
                                          tip: "Power menu", hint: "Open", fixed: true }
    ]
    readonly property var moduleIds: moduleDefs.map(d => d.id)
    readonly property var defMap: moduleDefs.reduce((m, d) => { m[d.id] = d; return m; }, {})
    readonly property var comps: ({
        stats: statsC, ws: wsC, media: mediaC, volume: volumeC, battery: batteryC,
        logo: logoC, caffeine: caffeineC, tray: trayC, icon: iconC
    })

    function csv(str) { return str === "" ? [] : str.split(","); }
    function valid(id) { return moduleIds.indexOf(id) >= 0; }

    // enable / disable (persisted in bar-state.json `hidden`)
    readonly property var hiddenList: csv(cfg.hidden)
    function isOn(id) { return hiddenList.indexOf(id) < 0; }

    function modVisible(id) {
        if (!isOn(id)) return false;
        switch (id) {
        case "stats":   return !vertical || cfg.statsMode === "compact";   // compact fits vertical bars
        case "media":   return Marquee.player !== null && Marquee.title !== "";
        case "battery": return battery !== null;
        // tray exists only while apps register SNI items (i.e. while used)
        case "tray":    return SystemTray.items.values.length > 0;
        default:        return true;
        }
    }

    // sections
    // `logo` is always the first module; drop a stale "logo" entry in
    // saved config so it can't render twice.
    readonly property var startList: ["logo"].concat(csv(cfg.startMods).filter(x => x !== "logo" && valid(x)))
    readonly property var centerList: {
        const a = csv(cfg.centerMods).filter(x => x === "clock" || valid(x));
        return a.indexOf("clock") >= 0 ? a : ["clock"].concat(a);
    }
    readonly property var endList: {
        let a = cfg.endMods.split(",").map(m => m.trim()).filter(m => m !== "" && valid(m));
        // Remove duplicates while preserving order
        const seen = {};
        let deduped = a.filter(m => {
            if (seen[m]) {
                return false;
            }
            seen[m] = true;
            return true;
        });
        // Ensure tray and caffeine sit just before the audio (volume) module
        const iVol = deduped.indexOf("volume");
        if (iVol >= 0) {
            deduped = deduped.filter(x => x !== "tray" && x !== "caffeine");
            const newIVol = deduped.indexOf("volume");
            if (!startList.includes("tray") && !centerList.includes("tray")) {
                deduped.splice(newIVol, 0, "tray");
            }
            if (!startList.includes("caffeine") && !centerList.includes("caffeine")) {
                deduped.splice(deduped.indexOf("volume"), 0, "caffeine");
            }
        }
        // Remove any that are already in startList or centerList
        const filtered = deduped.filter(m => !startList.includes(m) && !centerList.includes(m));
        // Append any remaining moduleIds not in startList, centerList, or filtered
        return filtered.concat(moduleIds.filter(m =>
            !startList.includes(m) &&
            !centerList.includes(m) &&
            !filtered.includes(m)));
    }

    // ───────────────────────── State / IPC ─────────────────────────
    property bool barVisible: true
    property bool barLive: true

    function rebuildBar() { barLive = false; rebuildTimer.restart(); }
    Timer { id: rebuildTimer; interval: 80; onTriggered: root.barLive = true }
    Connections {
        target: cfg
        function onPositionChanged() { root.rebuildBar(); }
        function onStyleChanged() { root.rebuildBar(); }
    }

    IpcHandler {
        target: "bar"
        function toggle(): void { root.barVisible = !root.barVisible; }
        function show(): void { root.barVisible = true; }
        function hide(): void { root.barVisible = false; }
        function setPosition(pos: string): void { if (root.positions.indexOf(pos) >= 0) cfg.position = pos; }
        function cyclePosition(): void {
            cfg.position = root.positions[(root.positions.indexOf(cfg.position) + 1) % 4];
        }
        function setStyle(st: string): void { if (root.styles.indexOf(st) >= 0) cfg.style = st; }
        function setStatsMode(mode: string): void { if (root.statsModes.indexOf(mode) >= 0) cfg.statsMode = mode; }
    }

    // ───────────────────────── System stats ─────────────────────────
    property int cpuUsage: 0
    property int memPercent: 0
    property real memUsedG: 0
    property real memTotalG: 0
    property string netState: "disconnected"
    property real _prevTotal: 0
    property real _prevIdle: 0

    readonly property string netGlyph: netState === "wifi" ? "\uDB81\uDDA9"
                                     : netState === "ethernet" ? "\uDB80\uDE00" : "\uDB81\uDDAA"
    readonly property string netTip: netState === "wifi" ? "Wi-Fi connected"
                                   : netState === "ethernet" ? "Ethernet connected" : "Disconnected"

    FileView {
        id: statFile
        path: "/proc/stat"
        onLoaded: {
            const f = text().split("\n")[0].trim().split(/\s+/).slice(1, 9).map(Number);
            const total = f.reduce((a, b) => a + b, 0);
            const idle = f[3] + f[4];
            const dT = total - root._prevTotal, dI = idle - root._prevIdle;
            if (root._prevTotal > 0 && dT > 0) root.cpuUsage = Math.round(100 * (dT - dI) / dT);
            root._prevTotal = total;
            root._prevIdle = idle;
        }
    }

    FileView {
        id: memFile
        path: "/proc/meminfo"
        onLoaded: {
            const t = text();
            const kb = k => Number(t.match(new RegExp(k + ":\\s+(\\d+)"))[1]);
            const total = kb("MemTotal"), used = total - kb("MemAvailable");
            root.memPercent = Math.round(100 * used / total);
            root.memUsedG = used / 1048576;
            root.memTotalG = total / 1048576;
        }
    }

    // Notification count: the notifications panel persists its history here
    property int notifCount: 0
    readonly property string notifTip: notifCount > 0 ? "Notifications: " + notifCount : "No notifications"

    FileView {
        id: notifFile
        path: Quickshell.env("HOME") + "/.cache/theme/notifications.json"
        printErrors: false
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try { root.notifCount = JSON.parse(text()).length; }
            catch (e) { root.notifCount = 0; }
        }
        onLoadFailed: root.notifCount = 0
    }

    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "device"]
        stdout: StdioCollector {
            onStreamFinished: {
                let st = "disconnected";
                for (const l of text.split("\n")) {
                    if (l === "ethernet:connected") { st = "ethernet"; break; }
                    if (l === "wifi:connected") st = "wifi";
                }
                if (st !== root.netState) root.netState = st;
            }
        }
    }

    Timer {
        interval: 2000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: { statFile.reload(); memFile.reload(); }
    }
    Timer {
        interval: 10000; running: root.barVisible; repeat: true; triggeredOnStart: true
        onTriggered: if (!netProc.running) netProc.running = true
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }

    Process { id: runner }
    function run(cmd) { runner.command = ["sh", "-c", cmd]; runner.running = true; }

    function mediaAct(kind) {
        const p = Marquee.player;
        if (!p) return;
        if (kind === "toggle") p.togglePlaying();
        else if (kind === "next") p.next();
        else p.previous();
    }

    readonly property string wsHints: "Left click: Switch to workspace\nScroll: Previous / next workspace"

    // ───────────────────────── Interaction model ─────────────────────────
    // Convention used by every bar module:
    //   Left click   → primary action
    //   Right click  → secondary action (only if the module defines one)
    //   Middle click → tertiary action (optional)
    //   Scroll       → adjust a value (optional)
    // Hints declared on a module are shown automatically in its tooltip.
    // States: hover · pressed · active (accent) · warning (danger) · disabled.

    component Lane: GridLayout {
        property int gap: 0
        flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
        rowSpacing: gap
        columnSpacing: gap
    }

    // Hover tooltip, anchored next to `target` on the side facing away from the bar edge.
    component Tip: Item {
        id: tp
        property Item target: parent
        property bool hot: false
        property string title: ""
        property string hints: ""
        property bool shown: false
        property bool suppressed: false   // set on click; cleared when the pointer leaves
        readonly property bool usable: cfg.tooltips && !suppressed && (title !== "" || hints !== "")

        width: 0
        height: 0
        onHotChanged: if (!hot) { shown = false; suppressed = false; }

        Timer {
            interval: 450
            running: tp.hot && tp.usable && !tp.shown
            onTriggered: tp.shown = true
        }

        LazyLoader {
            active: tp.shown && tp.usable

            PopupWindow {
                readonly property var win: tp.target.QsWindow.window
                readonly property point p: win.contentItem.mapFromItem(tp.target, 0, 0)

                anchor.window: win
                anchor.adjustment: PopupAdjustment.Slide
                anchor.rect.x: root.vertical
                    ? (cfg.position === "left" ? p.x + tp.target.width + 6 : p.x - implicitWidth - 6)
                    : p.x + (tp.target.width - implicitWidth) / 2
                anchor.rect.y: root.vertical
                    ? p.y + (tp.target.height - implicitHeight) / 2
                    : (cfg.position === "top" ? p.y + tp.target.height + 6 : p.y - implicitHeight - 6)
                implicitWidth: tcol.implicitWidth + 20
                implicitHeight: tcol.implicitHeight + 14
                color: "transparent"
                visible: true

                Rectangle {
                    anchors.fill: parent
                    radius: 6
                    color: root.bgColor
                    border.width: 1
                    border.color: root.borderColor

                    Column {
                        id: tcol
                        anchors.centerIn: parent
                        spacing: 3
                        Text {
                            visible: tp.title !== ""
                            text: tp.title
                            color: Theme.text
                            font.family: Theme.iconFont
                            font.pixelSize: 12
                            font.bold: true
                        }
                        Text {
                            visible: tp.hints !== ""
                            text: tp.hints
                            color: Theme.textDim
                            font.family: Theme.iconFont
                            font.pixelSize: 11
                        }
                    }
                }
            }
        }
    }

    // Behaviour + visual states shared by every interactive bar element.
    component Interactive: Item {
        id: it
        property string tip: ""
        property string primaryHint: ""
        property string secondaryHint: ""      // empty → right click opens bar settings
        property string tertiaryHint: ""
        property string scrollHint: ""
        property string disabledReason: ""
        property bool active: false            // accent tint (e.g. calendar open)
        property bool warning: false           // danger tint (e.g. low battery, muted)
        property bool disabled: false          // dimmed, ignores input, tooltip explains why
        property bool interactive: true        // false → informational only (no hover tint / pointer)
        property bool noTip: false             // never show a tooltip for this element
        signal primary()
        signal secondary()
        signal tertiary()
        signal scrolled(real delta)

        readonly property bool hovered: ma.containsMouse && !disabled
        readonly property string hintText: {
            if (disabled) return disabledReason;
            if (!cfg.tooltipHints) return "";
            const l = [];
            if (primaryHint !== "") l.push("Left click: " + primaryHint);
            if (secondaryHint !== "") l.push("Right click: " + secondaryHint);
            if (tertiaryHint !== "") l.push("Middle click: " + tertiaryHint);
            if (scrollHint !== "") l.push("Scroll: " + scrollHint);
            return l.join("\n");
        }

        function secondaryAction() {
            if (secondaryHint !== "") secondary();
        }

        opacity: disabled ? 0.4 : 1
        Behavior on opacity { NumberAnimation { duration: 120 } }

        // state layer: pressed > active > warning, with a hover overlay
        Rectangle {
            anchors.fill: parent
            anchors.margins: 1
            radius: Theme.radius
            color: ma.pressed && it.interactive && !it.disabled ? Qt.alpha(Theme.accent, 0.35)
                 : it.active ? Qt.alpha(Theme.accent, 0.22)
                 : it.warning ? Qt.alpha(Theme.danger, 0.16)
                 : Qt.alpha(Theme.text, 0)
            Behavior on color { ColorAnimation { duration: 100 } }

            Rectangle {
                anchors.fill: parent
                radius: parent.radius
                color: it.hovered && it.interactive ? Qt.alpha(Theme.text, 0.1) : Qt.alpha(Theme.text, 0)
                Behavior on color { ColorAnimation { duration: 100 } }
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
            cursorShape: it.interactive && !it.disabled ? Qt.PointingHandCursor : Qt.ArrowCursor
            onPressed: { tipper.suppressed = true; tipper.shown = false; }
            onClicked: mouse => {
                if (it.disabled) return;
                if (mouse.button === Qt.LeftButton) it.primary();
                else if (mouse.button === Qt.MiddleButton) it.tertiary();
                else if (mouse.button === Qt.RightButton) it.secondary();
            }
            onWheel: wheel => {
                wheel.accepted = it.scrollHint !== "" && !it.disabled;
                if (wheel.accepted) it.scrolled(wheel.angleDelta.y);
            }
        }

        Tip {
            id: tipper
            target: it
            hot: !it.noTip && ma.containsMouse
            title: it.tip
            hints: it.hintText
        }
    }

    // Icon / text module built on Interactive
    component Mod: Interactive {
        id: mod
        property string mid: ""          // set by Slot; used by generic icon modules
        property string text: ""
        property string vtext: text
        property string glyph: ""
        property string vglyph: glyph
        property real glyphSize: 16
        property real baseSize: 11
        property color color: Theme.text
        property bool bold: false
        property real yOffset: 0
        property int spacing: root.sizeIconGap
        property int padX: 20

        readonly property color fg: warning ? Theme.danger : active ? Theme.accent : color
        readonly property string shown: root.vertical ? vtext : text
        readonly property string shownGlyph: root.vertical ? vglyph : glyph

        Layout.alignment: Qt.AlignCenter
        implicitWidth: root.vertical ? root.panelThick : content.implicitWidth + padX
        implicitHeight: root.vertical ? Math.max(20, content.implicitHeight + 8)
                                      : Math.max(root.panelThick - 2, content.implicitHeight)

        GridLayout {
            id: content
            anchors.centerIn: parent
            anchors.verticalCenterOffset: root.vertical ? 0 : mod.yOffset
            flow: root.vertical ? GridLayout.TopToBottom : GridLayout.LeftToRight
            rowSpacing: 2
            columnSpacing: mod.spacing

            Text {
                visible: mod.shownGlyph !== ""
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: mod.shownGlyph
                color: mod.fg
                font.family: Theme.iconFont
                font.pixelSize: mod.glyphSize
                renderType: Text.NativeRendering
            }
            Text {
                visible: mod.shown !== ""
                Layout.alignment: Qt.AlignCenter
                horizontalAlignment: Text.AlignHCenter
                text: mod.shown
                color: mod.fg
                font.family: Theme.iconFont
                font.bold: mod.bold
                font.pixelSize: mod.baseSize
                renderType: Text.NativeRendering
            }
        }
    }

    component Slot: Loader {
        required property string modelData
        property Component clockComp: null
        visible: root.modVisible(modelData)
        Layout.alignment: Qt.AlignCenter
        sourceComponent: modelData === "clock" ? clockComp : (root.comps[modelData] ?? root.comps.icon)
        onLoaded: if (item.mid !== undefined) item.mid = modelData
    }

    // One of the three bar sections: a rounded panel holding a Lane of Slots
    component Panel: Rectangle {
        id: panel
        property var model: []
        property Component clockComp: null
        readonly property Item lane: laneItem

        visible: (root.vertical ? laneItem.implicitHeight : laneItem.implicitWidth) > 0
        width: root.vertical ? root.panelThick : laneItem.implicitWidth + 4
        height: root.vertical ? laneItem.implicitHeight + 4 : root.panelThick
        radius: root.barRadius
        color: root.joined ? "transparent" : root.bgColor
        border.width: cfg.border && !root.joined ? 1 : 0
        border.color: root.borderColor

        Lane {
            id: laneItem
            anchors.centerIn: parent
            Repeater {
                model: panel.model
                delegate: Slot { clockComp: panel.clockComp }
            }
        }
    }

    // ── Shared divider ──
    component Rule: Rectangle {
        height: 1
        color: Qt.alpha(Theme.text, 0.12)
    }

    component Arrow: Item {
        id: ar
        property string glyph: ""
        signal clicked()
        width: 28
        height: 26
        Text {
            anchors.centerIn: parent
            text: ar.glyph
            color: arMa.containsMouse ? Theme.accent : Theme.text
            font.family: Theme.iconFont
            font.pixelSize: root.sz.calArrow
        }
        MouseArea {
            id: arMa
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: ar.clicked()
        }
    }

    // Scrolling now-playing text. Rotated 90° by its parent on vertical bars.
    component MarqueeStrip: Item {
        clip: true
        Row {
            x: Marquee.animating ? Marquee.x : 0
            spacing: Marquee.gap
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: root.vertical ? 0 : root.iconYOffset

            Repeater {
                model: Marquee.animating ? 2 : 1
                delegate: Text {
                    required property int index
                    text: Marquee.text
                    color: Theme.text
                    font.family: Theme.iconFont
                    font.pixelSize: root.sz.marquee
                    renderType: root.vertical ? Text.QtRendering : Text.NativeRendering
                    // first copy is width-limited/elided when not scrolling
                    width: index === 0 ? (Marquee.animating ? Marquee.textW
                                                            : Math.min(Marquee.textW, Marquee.maxW))
                                       : implicitWidth
                    elide: index === 0 && !Marquee.animating ? Text.ElideRight : Text.ElideNone
                }
            }
        }
    }

    // ───────────────────────── Module components ─────────────────────────
    // Generic icon button: net / notif / wall / settings / power (driven by moduleDefs)
    Component {
        id: iconC
        Mod {
            property var def: root.defMap[mid] ?? ({})
            readonly property bool isNet: mid === "net"
            baseSize: mid === "power" ? root.sz.power : root.sz.icon
            yOffset: root.iconYOffset
            text: isNet ? root.netGlyph : (def.g ?? "")
            tip: isNet ? root.netTip : mid === "notif" ? root.notifTip : (def.tip ?? "")
            primaryHint: def.hint ?? ""
            warning: isNet && root.netState === "disconnected"
            onPrimary: if (def.cmd) root.run(def.cmd)
        }
    }

    // CPU / RAM — "default": `CPU 12%`   "compact": small icon + `12%`
    Component {
        id: statsC
        Lane {
            Repeater {
                model: ["CPU", "RAM"]
                delegate: Mod {
                    required property string modelData
                    readonly property bool isCpu: modelData === "CPU"
                    readonly property bool compact: cfg.statsMode === "compact"
                    readonly property int val: isCpu ? root.cpuUsage : root.memPercent

                    baseSize: root.sz.stat
                    glyphSize: root.sz.stat + 2
                    glyph: compact ? (isCpu ? "\uDB81\uDE1A" : "\uDB80\uDF5B") : ""
                    text: compact ? val + "%" : modelData + " " + val + "%"
                    spacing: compact ? 4 : root.sizeIconGap
                    padX: compact ? 12 : 20

                    interactive: false
                    warning: val >= 85
                    tip: isCpu ? "CPU usage: " + val + "%"
                               : "Memory: " + root.memUsedG.toFixed(1) + " / " + root.memTotalG.toFixed(1)
                                 + " GiB (" + val + "%)"
                }
            }
        }
    }

    Component {
        id: wsC
        Item {
            implicitWidth: root.vertical ? root.panelThick : wsLane.implicitWidth + 12
            implicitHeight: wsLane.implicitHeight + (root.vertical ? 12 : 0)

            Lane {
                id: wsLane
                anchors.centerIn: parent
                gap: 8

                Repeater {
                    model: Hyprland.workspaces
                    delegate: Rectangle {
                        id: dot
                        required property var modelData
                        // UntypedObjectModel: size via .values.length (.count does not exist).
                        readonly property bool occupied: modelData.toplevels.values.length > 0
                        visible: modelData.id > 0
                        Layout.alignment: Qt.AlignCenter
                        implicitWidth: modelData.focused ? 12 : 10
                        implicitHeight: modelData.focused ? 12 : 10
                        radius: width / 2
                        // occupied = solid dot, empty = hollow outline
                        color: modelData.urgent ? Theme.danger
                             : modelData.focused ? Qt.alpha(Theme.accent, 0.85)
                             : !occupied ? "transparent"
                             : dotMa.containsMouse ? Theme.accent2
                             : Theme.text
                        border.width: modelData.focused || modelData.urgent || occupied ? 0 : 1
                        border.color: Qt.alpha(Theme.textFaint, 0.7)

                        Behavior on implicitWidth { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }
                        Behavior on implicitHeight { NumberAnimation { duration: Theme.animMed; easing.type: Easing.OutQuad } }

                        MouseArea {
                            id: dotMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            acceptedButtons: Qt.LeftButton | Qt.RightButton
                            onPressed: { dotTip.suppressed = true; dotTip.shown = false; }
                            onClicked: mouse => {
                                if (mouse.button === Qt.LeftButton) dot.modelData.activate();
                            }
                        }

                        Tip {
                            id: dotTip
                            hot: dotMa.containsMouse
                            title: "Workspace " + dot.modelData.id
                                   + (dot.modelData.urgent ? " · urgent" : dot.modelData.focused ? " · focused" : dot.occupied ? " · occupied" : " · empty")
                            hints: cfg.tooltipHints ? root.wsHints : ""
                        }
                    }
                }
            }

            WheelHandler {
                acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                onWheel: e => root.run("~/.config/hypr/scripts/workspace-cycle.sh "
                                       + (e.angleDelta.y > 0 ? "next" : "prev"))
            }
        }
    }

    Component {
        id: mediaC
        Interactive {
            readonly property bool playing: Marquee.player !== null && Marquee.player.isPlaying === true
            readonly property real len: Math.min(Marquee.textW, Marquee.maxW)   // visible text length

            implicitWidth: root.vertical ? root.panelThick : len + 20
            implicitHeight: root.vertical ? len + 20 : 18

            tip: Marquee.text
            primaryHint: playing ? "Pause" : "Play"
            secondaryHint: "Next track"
            tertiaryHint: "Previous track"
            onPrimary: root.mediaAct("toggle")
            onSecondary: root.mediaAct("next")
            onTertiary: root.mediaAct("prev")

            // On vertical bars the same marquee is rotated: reads bottom→top on the left, top→bottom on the right.
            MarqueeStrip {
                anchors.centerIn: parent
                width: parent.len
                height: 18
                rotation: root.vertical ? (cfg.position === "left" ? -90 : 90) : 0
            }
        }
    }

    Component {
        id: volumeC
        Mod {
            readonly property var sink: Pipewire.defaultAudioSink
            readonly property bool ready: !!(sink && sink.audio)
            readonly property real vol: ready ? sink.audio.volume : 0
            readonly property bool muted: ready ? sink.audio.muted : false

            glyphSize: root.sz.icon
            glyph: muted || vol <= 0 ? "\uDB81\uDF5F" : "\uDB81\uDD7E"
            warning: muted
            disabled: !ready
            disabledReason: "No audio output available"
            tip: !ready ? "Volume" : muted ? "Volume: muted" : "Volume: " + Math.round(vol * 100) + "%"
            primaryHint: "Open sound settings"
            secondaryHint: "Mute / unmute"
            scrollHint: "Adjust volume"

            onPrimary: root.run("qs ipc call audio toggle")
            onSecondary: root.run("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle")
            onScrolled: delta => {
                if (!ready) return;
                sink.audio.volume = Math.max(0, Math.min(1.0, sink.audio.volume + (delta / 120) * 0.02));
            }
        }
    }

    Component {
        id: batteryC
        Mod {
            baseSize: root.sz.batText
            glyphSize: root.sz.batIcon
            glyph: (root.batCharging ? "\uf0e7 " : "") + root.batIcon
            vglyph: root.batIcon
            text: root.batPct + "%"
            vtext: root.batPct + ""
            warning: root.batLow
            active: root.vertical && root.batCharging
            tip: root.batTip
            primaryHint: "Power profiles (performance / balanced / saver)"
            onPrimary: root.run("qs ipc call settings page power")
        }
    }

    // Void Linux mark — leftmost module, decorative
    Component {
        id: logoC
        Mod {
            glyph: "\uf32e"   // nf-linux-void
            glyphSize: root.s(15)
            padX: 12
            interactive: false
            tip: "Void Linux"
        }
    }

    // Caffeine — click toggles idle lock (hypridle) via idle-toggle.sh,
    // the same mechanism as SUPER+CTRL+I.
    Component {
        id: caffeineC
        Mod {
            glyphSize: root.sz.icon
            glyph: "\uef59"   // nf-fa-mug_hot (steaming mug)
            active: !root.idleOn
            tip: root.idleOn ? "Idle lock on" : "Caffeine on — idle lock off"
            primaryHint: root.idleOn ? "Toggle idle lock (caffeine)" : "Re-enable idle lock"
            onPrimary: {
                root.run(Quickshell.env("HOME") + "/.config/hypr/scripts/idle-toggle.sh")
                idleRecheck.restart()
            }
        }
    }

    // Λ System tray (StatusNotifierItem): apps register an icon while they run
    // (e.g. ChatGPT in tray, pavucontrol, NetworkManager applet). Items appear
    // Λ System tray (StatusNotifierItem): apps register an icon while they run
    // (e.g. ChatGPT in tray, pavucontrol, NetworkManager applet). Items appear
    // as soon as the app registers and vanish when it exits — nothing is shown
    // when nothing is running. Left click activates (opens the window); if the
    // item is menu-only (ItemIsMenu) it opens its menu instead. Right click
    // opens a native themed QML menu matching the bar aesthetics.
    Component {
        id: trayC
        Item {
            id: trayRoot
            readonly property var items: SystemTray.items.values
            readonly property int side: root.sz.icon   // icon pixel size (16)

            implicitWidth: root.vertical ? root.panelThick : trayLane.implicitWidth
            implicitHeight: root.vertical
                ? Math.max(20, trayLane.implicitHeight + 8)
                : Math.max(root.panelThick - 2, side + 4)

            Lane {
                id: trayLane
                anchors.centerIn: parent
                gap: 2

                Repeater {
                    model: trayRoot.items

                    delegate: Interactive {
                        id: trayEntry
                        required property var modelData
                        readonly property string name: modelData.tooltipTitle !== "" ? modelData.tooltipTitle : (modelData.title !== "" ? modelData.title : modelData.id)
                        readonly property alias entryOpener: entryOpener
                        readonly property var menuEntries: (entryOpener && entryOpener.children && entryOpener.children.values) ? entryOpener.children.values : []

                        QsMenuOpener {
                            id: entryOpener
                            menu: trayEntry.modelData.hasMenu ? trayEntry.modelData.menu : null
                        }

                        function toggleMenu() {
                            if (root.activeTrayEntry === trayEntry) {
                                root.activeTrayEntry = null;
                            } else {
                                root.activeTrayEntry = trayEntry;
                            }
                        }

                        implicitWidth: trayRoot.side + 12
                        implicitHeight: root.vertical ? trayRoot.side + 8 : trayRoot.side + 4

                        active: root.activeTrayEntry === trayEntry
                        interactive: true
                        tip: name
                        primaryHint: modelData.onlyMenu ? (root.activeTrayEntry === trayEntry ? "Close menu" : "Open menu") : "Activate"
                        secondaryHint: modelData.hasMenu ? (root.activeTrayEntry === trayEntry ? "Close menu" : "Open menu") : ""

                        onPrimary: {
                            if (trayEntry.modelData.onlyMenu) {
                                trayEntry.toggleMenu();
                            } else {
                                if (typeof trayEntry.modelData.activate === 'function') {
                                    trayEntry.modelData.activate();
                                } else if (trayEntry.modelData.hasMenu) {
                                    trayEntry.toggleMenu();
                                }
                            }
                        }
                        onSecondary: {
                            trayEntry.toggleMenu();
                        }

                        Image {
                            anchors.centerIn: parent
                            source: trayEntry.modelData.icon
                            sourceSize.width: trayRoot.side
                            sourceSize.height: trayRoot.side
                            fillMode: Image.PreserveAspectFit
                            smooth: true
                        }
                    }
                }
            }

            LazyLoader {
                active: root.activeTrayEntry !== null

                PopupWindow {
                    id: trayMenuPopup
                    readonly property var target: root.activeTrayEntry
                    readonly property var win: target ? target.QsWindow.window : null
                    readonly property point p: win && target ? win.contentItem.mapFromItem(target, 0, 0) : Qt.point(0, 0)

                    anchor.window: win
                    anchor.adjustment: PopupAdjustment.Slide | PopupAdjustment.Flip
                    anchor.rect.x: root.vertical
                        ? (cfg.position === "left" ? p.x + (target ? target.width : 0) + 6
                                                   : p.x - implicitWidth - 6)
                        : (win ? Math.max(8, Math.min(win.width - implicitWidth - 8, p.x + ((target ? target.width : 0) - implicitWidth) / 2)) : p.x)
                    anchor.rect.y: root.vertical
                        ? (win ? Math.max(8, Math.min(win.height - implicitHeight - 8, p.y + ((target ? target.height : 0) - implicitHeight) / 2)) : p.y)
                        : (cfg.position === "top" ? p.y + (target ? target.height : 0) + 6
                                                  : p.y - implicitHeight - 6)

                    implicitWidth: 200
                    implicitHeight: menuCol.implicitHeight + 12
                    color: "transparent"
                    visible: true
                    grabFocus: true

                    onVisibleChanged: {
                        if (!visible) {
                            root.activeTrayEntry = null;
                        }
                    }

                    Connections {
                        target: Hyprland
                        function onActiveToplevelChanged() { root.activeTrayEntry = null; }
                        function onFocusedWorkspaceChanged() { root.activeTrayEntry = null; }
                    }

                    Rectangle {
                        id: menuCard
                        anchors.fill: parent
                        radius: Theme.radius
                        color: Qt.rgba(Theme.bgPanel.r, Theme.bgPanel.g, Theme.bgPanel.b, 0.94)
                        border.width: 1
                        border.color: root.borderColor
                        focus: true
                        Component.onCompleted: menuCard.forceActiveFocus()
                        Keys.onEscapePressed: {
                            root.activeTrayEntry = null;
                        }

                        Column {
                            id: menuCol
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 6
                            spacing: 2

                            Text {
                                visible: menuRepeater.count === 0
                                text: "No menu items"
                                color: Theme.textDim
                                font.family: Theme.fontFamily
                                font.pixelSize: 12
                                anchors.horizontalCenter: parent.horizontalCenter
                                topPadding: 6
                                bottomPadding: 6
                            }

                            Repeater {
                                id: menuRepeater
                                model: (root.activeTrayEntry && root.activeTrayEntry.menuEntries)
                                    ? root.activeTrayEntry.menuEntries
                                    : []

                                delegate: Item {
                                    id: itemDelegate
                                    required property var modelData
                                    readonly property bool isSep: modelData.isSeparator
                                    readonly property bool isEnabled: modelData.enabled !== false

                                    readonly property var parts: (modelData.text && typeof modelData.text === "string") ? modelData.text.split("\t") : [""]
                                    readonly property string itemText: parts[0]
                                    readonly property string itemShortcut: parts.length > 1 ? parts[1] : ""

                                    width: menuCol.width
                                    height: isSep ? 7 : 32
                                    visible: isSep || (itemText && itemText.length > 0)

                                    Rectangle {
                                        visible: itemDelegate.isSep
                                        anchors.centerIn: parent
                                        width: parent.width - 8
                                        height: 1
                                        color: Qt.alpha(Theme.border, 0.7)
                                    }

                                    Rectangle {
                                        id: itemBox
                                        visible: !itemDelegate.isSep
                                        anchors.fill: parent
                                        radius: Math.max(4, Theme.radius - 4)
                                        color: itemMa.pressed && itemDelegate.isEnabled
                                            ? Qt.alpha(Theme.accent, 0.35)
                                            : (itemMa.containsMouse && itemDelegate.isEnabled)
                                                ? Qt.alpha(Theme.accent, 0.18)
                                                : "transparent"
                                        opacity: itemDelegate.isEnabled ? 1.0 : 0.4
                                        Behavior on color { ColorAnimation { duration: 80 } }

                                        MouseArea {
                                            id: itemMa
                                            anchors.fill: parent
                                            hoverEnabled: itemDelegate.isEnabled
                                            cursorShape: itemDelegate.isEnabled ? Qt.PointingHandCursor : Qt.ArrowCursor

                                            onClicked: {
                                                if (!itemDelegate.isEnabled) return;
                                                if (typeof itemDelegate.modelData.triggered === "function") {
                                                    itemDelegate.modelData.triggered();
                                                }
                                                root.activeTrayEntry = null;
                                            }
                                        }

                                        Text {
                                            id: checkIcon
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: itemDelegate.modelData.buttonType !== undefined && itemDelegate.modelData.buttonType !== 0
                                            font.family: Theme.iconFont
                                            font.pixelSize: 13
                                            color: Theme.accent
                                            text: {
                                                if (itemDelegate.modelData.buttonType === 1) {
                                                    return itemDelegate.modelData.checkState === Qt.Checked ? "\u2713" : "  ";
                                                } else if (itemDelegate.modelData.buttonType === 2) {
                                                    return itemDelegate.modelData.checkState === Qt.Checked ? "\u25CF" : "\u25CB";
                                                }
                                                return "";
                                            }
                                        }

                                        Image {
                                            id: entryIcon
                                            anchors.left: parent.left
                                            anchors.leftMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !checkIcon.visible && itemDelegate.modelData.icon && itemDelegate.modelData.icon !== ""
                                            source: itemDelegate.modelData.icon || ""
                                            sourceSize.width: 16
                                            sourceSize.height: 16
                                            width: 16
                                            height: 16
                                            fillMode: Image.PreserveAspectFit
                                        }

                                        Text {
                                            id: textLabel
                                            anchors.left: parent.left
                                            anchors.leftMargin: (checkIcon.visible || entryIcon.visible) ? 30 : 10
                                            anchors.right: shortcutLabel.visible ? shortcutLabel.left : (subArrow.visible ? subArrow.left : parent.right)
                                            anchors.rightMargin: 6
                                            anchors.verticalCenter: parent.verticalCenter
                                            text: itemDelegate.itemText
                                            color: itemDelegate.isEnabled ? Theme.text : Theme.textDim
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 13
                                            font.weight: Font.Medium
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            id: shortcutLabel
                                            anchors.right: subArrow.visible ? subArrow.left : parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: itemDelegate.itemShortcut !== ""
                                            text: itemDelegate.itemShortcut
                                            color: Theme.textFaint
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 11
                                        }

                                        Text {
                                            id: subArrow
                                            anchors.right: parent.right
                                            anchors.rightMargin: 8
                                            anchors.verticalCenter: parent.verticalCenter
                                            visible: !!itemDelegate.modelData.hasChildren
                                            font.family: Theme.fontFamily
                                            font.pixelSize: 12
                                            color: Theme.textDim
                                            text: "\u203A"
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

    Timer {
        id: idleRecheck
        interval: 800
        onTriggered: if (!idleCheck.running) idleCheck.running = true
    }

    // ───────────────────────── The bar ─────────────────────────
    Variants {
        model: root.barLive ? Quickshell.screens : []

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: cfg.position !== "bottom"
                bottom: cfg.position !== "top"
                left: cfg.position !== "right"
                right: cfg.position !== "left"
            }
            implicitWidth: root.vertical ? root.panelThick + root.effEdge : 0
            implicitHeight: root.vertical ? 0 : root.panelThick + root.effEdge
            color: "transparent"
            visible: root.barVisible
            // Grab keyboard focus while the calendar popup is open so
            // Esc reaches the bar and can close it.
            WlrLayershell.keyboardFocus: clockPanel.calOpen
                ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None

            Item {
                id: frame
                focus: true
                Keys.onEscapePressed: {
                    if (root.activeTrayEntry !== null) {
                        root.activeTrayEntry = null
                        event.accepted = true
                    } else if (clockPanel.calOpen) {
                        clockPanel.calOpen = false
                        event.accepted = true
                    }
                }
                anchors {
                    fill: parent
                    topMargin: root.edgeMargin("top")
                    bottomMargin: root.edgeMargin("bottom")
                    leftMargin: root.edgeMargin("left")
                    rightMargin: root.edgeMargin("right")
                }

                Rectangle {
                    visible: root.joined
                    anchors.fill: parent
                    radius: root.barRadius
                    color: root.bgColor
                    border.width: cfg.border ? 1 : 0
                    border.color: root.borderColor
                }

                Panel {
                    model: root.startList
                    anchors.left: frame.left
                    anchors.top: frame.top
                }

                Panel {
                    id: clockPanel
                    model: root.centerList
                    clockComp: clockC
                    anchors.horizontalCenter: root.vertical ? undefined : frame.horizontalCenter
                    anchors.verticalCenter: root.vertical ? frame.verticalCenter : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined

                    property bool calOpen: false
                    property int monthOffset: 0

                    SystemClock { id: clk; precision: SystemClock.Minutes }

                    Component {
                        id: clockC
                        Mod {
                            bold: true
                            baseSize: root.sz.clock
                            text: Qt.formatDateTime(clk.date, "HH:mm")
                            vtext: Qt.formatDateTime(clk.date, "HH") + "\n" + Qt.formatDateTime(clk.date, "mm")
                            active: clockPanel.calOpen
                            tip: Qt.formatDate(clk.date, "dddd, d MMMM yyyy")
                            primaryHint: clockPanel.calOpen ? "Close calendar" : "Open calendar"
                            onPrimary: {
                                clockPanel.monthOffset = 0;
                                clockPanel.calOpen = !clockPanel.calOpen;
                            }
                        }
                    }

                    LazyLoader {
                        active: clockPanel.calOpen

                        PopupWindow {
                            readonly property point p: bar.contentItem.mapFromItem(clockPanel, 0, 0)

                            anchor.window: bar
                            anchor.rect.x: root.vertical
                                ? (cfg.position === "left" ? p.x + clockPanel.width + 6
                                                           : p.x - implicitWidth - 6)
                                : p.x + (clockPanel.width - implicitWidth) / 2
                            anchor.rect.y: root.vertical
                                ? p.y + (clockPanel.height - implicitHeight) / 2
                                : (cfg.position === "top" ? p.y + clockPanel.height + 4
                                                          : p.y - implicitHeight - 4)
                            implicitWidth: calBox.gridW + 2 * calBox.pad
                            implicitHeight: calCol.implicitHeight + 2 * calBox.pad
                            color: "transparent"
                            visible: true

                            Rectangle {
                                id: calBox
                                anchors.fill: parent
                                radius: cfg.calRadius
                                color: root.bgColor
                                border.width: cfg.border ? 1 : 0
                                border.color: root.borderColor

                                readonly property int firstDay: 1
                                readonly property int cellW: 36
                                readonly property int cellH: 30
                                readonly property int pad: 16
                                readonly property int gridW: cellW * 7

                                readonly property date now: clk.date
                                readonly property date view: new Date(now.getFullYear(), now.getMonth() + clockPanel.monthOffset, 1)

                                readonly property var cells: {
                                    const first = (view.getDay() - firstDay + 7) % 7;
                                    const y = view.getFullYear(), m = view.getMonth();
                                    const ty = now.getFullYear(), tm = now.getMonth(), td = now.getDate();
                                    return Array.from({ length: 42 }, (_, i) => {
                                        const d = new Date(y, m, i - first + 1);
                                        return {
                                            n: d.getDate(),
                                            inMonth: d.getMonth() === m,
                                            today: d.getFullYear() === ty && d.getMonth() === tm && d.getDate() === td
                                        };
                                    });
                                }

                                WheelHandler {
                                    onWheel: e => clockPanel.monthOffset += (e.angleDelta.y > 0 ? -1 : 1)
                                }

                                Column {
                                    id: calCol
                                    anchors.centerIn: parent
                                    spacing: 12

                                    Column {
                                        spacing: 2
                                        Text {
                                            text: Qt.formatTime(calBox.now, "HH:mm")
                                            color: Theme.text
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sz.calTime
                                            font.bold: true
                                        }
                                        Text {
                                            text: Qt.formatDate(calBox.now, "dddd, d MMMM yyyy")
                                            color: Theme.textDim
                                            font.family: Theme.iconFont
                                            font.pixelSize: root.sz.calDate
                                        }
                                    }

                                    Rule { width: calBox.gridW }

                                    Item {
                                        width: calBox.gridW
                                        height: 26

                                        Arrow {
                                            anchors.left: parent.left
                                            glyph: "\uDB80\uDD41"
                                            onClicked: clockPanel.monthOffset -= 1
                                        }

                                        Item {
                                            anchors.centerIn: parent
                                            width: monthTitle.implicitWidth + 16
                                            height: parent.height
                                            Text {
                                                id: monthTitle
                                                anchors.centerIn: parent
                                                text: Qt.formatDate(calBox.view, "MMMM yyyy")
                                                color: titleMa.containsMouse ? Theme.accent : Theme.text
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sz.calMonth
                                                font.bold: true
                                            }
                                            MouseArea {
                                                id: titleMa
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                cursorShape: Qt.PointingHandCursor
                                                onClicked: clockPanel.monthOffset = 0
                                            }
                                        }

                                        Arrow {
                                            anchors.right: parent.right
                                            glyph: "\uDB80\uDD42"
                                            onClicked: clockPanel.monthOffset += 1
                                        }
                                    }

                                    Row {
                                        Repeater {
                                            model: 7
                                            delegate: Text {
                                                required property int index
                                                width: calBox.cellW
                                                horizontalAlignment: Text.AlignHCenter
                                                text: Qt.locale().dayName((index + calBox.firstDay) % 7, Locale.ShortFormat)
                                                color: Theme.textDim
                                                font.family: Theme.iconFont
                                                font.pixelSize: root.sz.calWeekday
                                            }
                                        }
                                    }

                                    Grid {
                                        columns: 7
                                        Repeater {
                                            model: calBox.cells
                                            delegate: Item {
                                                required property var modelData
                                                width: calBox.cellW
                                                height: calBox.cellH

                                                Rectangle {
                                                    visible: parent.modelData.today
                                                    anchors.fill: parent
                                                    anchors.margins: 2
                                                    radius: Theme.radius
                                                    color: Qt.alpha(Theme.accent, 0.45)
                                                    border.width: 1
                                                    border.color: Theme.accent
                                                }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: parent.modelData.n
                                                    color: parent.modelData.inMonth ? Theme.text : Theme.textFaint
                                                    font.family: Theme.iconFont
                                                    font.pixelSize: root.sz.calDay
                                                    font.bold: parent.modelData.today
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                Panel {
                    model: root.endList
                    anchors.right: root.vertical ? undefined : frame.right
                    anchors.bottom: root.vertical ? frame.bottom : undefined
                    anchors.top: root.vertical ? undefined : frame.top
                    anchors.left: root.vertical ? frame.left : undefined
                }
            }
        }
    }
}