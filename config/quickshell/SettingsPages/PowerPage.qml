// Power page — profile switcher for the Settings center.
// Supersedes the waybar power-profile.sh + power-profiles menu (rofi removed):
// `power-profiles set <profile>` keeps the AC/battery memory, and
// `power-profiles watch` re-applies it when the power source flips.
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower
import "../"

Item {
    id: page
    width: parent ? parent.width : 600
    height: parent ? parent.height : 480

    property real marginLeft: 0
    property real marginRight: 55
    property real marginTop: 0
    property real marginBottom: 0

    // Profiles bottom-up, current first — exactly what `power-profiles list`
    // prints: "<profile>\t<1 when current|0>"
    property var profiles: []
    property string current: ""
    property string statusText: ""

    // Battery state from UPower (same resolution as the Bar battery module)
    readonly property var battery: UPower.devices.values.find(d => d.isLaptopBattery)
        ?? (UPower.displayDevice && UPower.displayDevice.isPresent
            && UPower.displayDevice.type === UPowerDeviceType.Battery
            ? UPower.displayDevice : null)
    readonly property real batteryFrac: battery ? battery.percentage : 0
    readonly property bool onAc: battery
        ? (battery.state === UPowerDeviceState.Charging || battery.state === UPowerDeviceState.FullyCharged)
        : false

    Timer { id: statusTimer; interval: 3000; onTriggered: page.statusText = "" }

    function setStatus(text) {
        page.statusText = text
        statusTimer.restart()
    }

    Process {
        id: pList
        stdout: StdioCollector {
            onStreamFinished: {
                const rows = []
                const lines = text.trim().split("\n")
                for (let i = 0; i < lines.length; i++) {
                    const parts = lines[i].split("\t")
                    if (parts.length !== 2) continue
                    const name = parts[0].trim()
                    if (name === "") continue
                    rows.push({ name: name, active: parts[1].trim() === "1" })
                }
                page.profiles = rows
                const cur = rows.find(r => r.active)
                page.current = cur ? cur.name : ""
            }
        }
        stderr: StdioCollector { onStreamFinished: {} }
    }

    Process {
        id: pSet
        stdout: StdioCollector { onStreamFinished: {} }
        stderr: StdioCollector { onStreamFinished: {
            if (text.trim() !== "") page.setStatus(text.trim())
        }}
        onExited: {
            page.refresh()
        }
    }

    function refresh() {
        pList.command = ["sh", "-c", "$HOME/.local/bin/power-profiles list"]
        if (!pList.running) pList.running = true
    }

    function choose(name) {
        if (name === page.current) return
        pList.command = []
        pSet.command = ["sh", "-c", "$HOME/.local/bin/power-profiles set " + name]
        if (!pSet.running) pSet.running = true
        page.setStatus("Switching to " + name + "...")
    }

    Component.onCompleted: refresh()

    // ──────────────────────────────────────────────────────────────
    //  Layout
    // ──────────────────────────────────────────────────────────────
    Flickable {
        id: flick
        anchors.fill: parent
        anchors.leftMargin: page.marginLeft
        anchors.rightMargin: page.marginRight
        anchors.topMargin: page.marginTop
        anchors.bottomMargin: page.marginBottom
        contentWidth: width
        contentHeight: content.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        ScrollBar.vertical: ScrollBar {
            background: Rectangle { color: "transparent"; radius: width / 2 }
            contentItem: Rectangle { color: "transparent"; radius: width / 2 }
        }

        Column {
            id: content
            width: flick.width
            spacing: 14

            Text {
                text: "POWER"
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 19; font.letterSpacing: 3
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Text {
                width: parent.width
                text: page.onAc
                    ? "AC POWER · battery " + Math.round(page.batteryFrac * 100) + "%"
                    : "ON BATTERY · " + Math.round(page.batteryFrac * 100) + "%"
                color: page.onAc ? Theme.text : Theme.textDim
                font.family: Theme.fontFamily; font.pixelSize: 12
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Column {
                width: parent.width; spacing: 8

                Text {
                    text: "PROFILE"
                    color: Theme.textFaint
                    font.family: Theme.fontFamily; font.pixelSize: 11; font.letterSpacing: 2
                }

                Repeater {
                    model: [{ id: "performance", icon: "\udb81\udcc5", label: "PERFORMANCE" },
                            { id: "balanced",     icon: "\udb83\uDDF85", label: "BALANCED" },
                            { id: "power-saver",  icon: "\udb83\uDDF86",       label: "POWER SAVER" }]

                    delegate: Rectangle {
                        id: card
                        required property var modelData
                        readonly property string name: modelData.id
                        readonly property bool available: page.profiles.some(p => p.name === name)
                        readonly property bool active: page.current === name
                        width: parent.width
                        height: 46
                        radius: Theme.radius
                        color: active ? Theme.alpha(Theme.accent, 0.10) : "transparent"
                        border.width: 1
                        border.color: active ? Theme.accent : Theme.border
                        opacity: (available || active) ? 1 : 0.35

                        Row {
                            anchors.fill: parent
                            anchors.leftMargin: 12
                            anchors.rightMargin: 12
                            spacing: 10

                            Rectangle {
                                width: 28; height: 28; radius: Theme.radius
                                anchors.verticalCenter: parent.verticalCenter
                                color: active ? Theme.accent : Theme.trackBg
                                border.width: 1
                                border.color: active ? Theme.accent : Theme.border
                                Text {
                                    anchors.centerIn: parent
                                    text: card.modelData.icon
                                    color: active ? Theme.bg : Theme.textDim
                                    font.family: Theme.iconFont; font.pixelSize: 13
                                }
                            }

                            Column {
                                width: parent.width - 28 - parent.spacing - 20
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 1
                                Text {
                                    width: parent.width
                                    text: card.modelData.label + (card.active ? "  · ACTIVE" : "")
                                    color: card.active ? Theme.accent : Theme.text
                                    font.family: Theme.fontFamily; font.pixelSize: 14; font.bold: card.active
                                }
                                Text {
                                    width: parent.width
                                    visible: !card.available
                                    text: "not available on this device"
                                    color: Theme.textFaint
                                    font.family: Theme.fontFamily; font.pixelSize: 10
                                }
                            }

                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                visible: card.active
                                text: "\udb80\udd2c"
                                color: Theme.accent
                                font.family: Theme.iconFont; font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            anchors.fill: parent
                            enabled: card.available && !card.active
                            cursorShape: card.available && !card.active ? Qt.PointingHandCursor : Qt.ArrowCursor
                            onClicked: page.choose(card.name)
                        }
                    }
                }
            }

            Rectangle { width: parent.width; height: 1; color: Theme.border }

            Text {
                width: parent.width
                text: "Choice is remembered per AC / battery; power-profiles watch reapplies it\nevery time the power source changes."
                color: Theme.textFaint
                font.family: Theme.fontFamily; font.pixelSize: 11
                textFormat: Text.PlainText
            }

            Text {
                width: parent.width
                visible: page.statusText !== ""
                text: page.statusText
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 12
            }
        }
    }
}
