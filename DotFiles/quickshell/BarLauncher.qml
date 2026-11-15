import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: root

    property string fontFamily: "JetBrainsMono Nerd Font"
    property bool hovered: false                     // set by the parent
    property bool forced: false                       // opened with the shortcut
    readonly property bool active: hovered || forced
    property int selected: 0

    implicitHeight: 20
    implicitWidth: row.implicitWidth

    readonly property var results: {
        const q = input.text.toLowerCase()
        if (q === "") return []
        return DesktopEntries.applications.values
            .filter(e => !e.noDisplay && e.name.toLowerCase().includes(q))
            .sort((a, b) => {
                const as = a.name.toLowerCase().startsWith(q) ? 0 : 1
                const bs = b.name.toLowerCase().startsWith(q) ? 0 : 1
                return as - bs || a.name.localeCompare(b.name)
            })
            .slice(0, 2)
    }

    // Hovering the launcher area activates it

    onActiveChanged: {
        if (active) {
            selected = 0
            // wait a moment so the bar gets keyboard focus first
            focusTimer.restart()
        } else {
            input.text = ""
            input.focus = false
        }
    }

    Timer {
        id: focusTimer
        interval: 50
        onTriggered: input.forceActiveFocus()
    }

    function launch() {
        const entry = results[selected]
        if (entry) entry.execute()
        forced = false
        input.text = ""
    }

    // Shortcut: qs ipc call launcher toggle
    IpcHandler {
        target: "launcher"
        function toggle(): void { root.forced = !root.forced }
    }

    Row {
        id: row
        anchors.verticalCenter: parent.verticalCenter
        spacing: 10

        // The keys you are writing (with a hint when empty)
        Item {
            anchors.verticalCenter: parent.verticalCenter
            width: Math.max(input.contentWidth + 6, 60)
            height: 20

            Text {
                anchors.verticalCenter: parent.verticalCenter
                visible: input.text === ""
                text: "run..."
                color: "#444444"
                font { family: root.fontFamily; pixelSize: 12 }
            }

            TextInput {
                id: input
                anchors.verticalCenter: parent.verticalCenter
                width: parent.width
                color: "white"
                font { family: root.fontFamily; pixelSize: 12 }
                onTextChanged: root.selected = 0

                Keys.onEscapePressed: { root.forced = false; text = ""; focus = false }
                Keys.onReturnPressed: root.launch()
                Keys.onTabPressed: if (root.results.length > 0)
                    root.selected = (root.selected + 1) % root.results.length
                Keys.onRightPressed: if (root.results.length > 0)
                    root.selected = (root.selected + 1) % root.results.length
                Keys.onLeftPressed: if (root.results.length > 0)
                    root.selected = (root.selected + root.results.length - 1) % root.results.length
            }
        }

        // The 2 suggestions
        Repeater {
            model: root.results
            delegate: Rectangle {
                required property var modelData
                required property int index
                anchors.verticalCenter: parent.verticalCenter
                height: 16
                width: label.implicitWidth + 12
                radius: 4
                color: index === root.selected ? "#ffffff" : "#444444"

                Text {
                    id: label
                    anchors.centerIn: parent
                    text: modelData.name
                    font { family: root.fontFamily; pixelSize: 11 }
                    color: index === root.selected ? "#000000" : "white"
                }
            }
        }
    }
}
