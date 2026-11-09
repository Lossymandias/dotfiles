import Quickshell
import Quickshell.Wayland
import Quickshell.Io
import Quickshell.Hyprland
import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell.Widgets

PanelWindow {
    id: root

    // Allow the bar to receive keyboard input when clicked
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand

    // Theme
    property color colBg: "#000000"
    property color colFg: "#ffffff"
    property color colMuted: "#444444"
    property color colCyan: "#ffffff"
    property color colBlue: "#777777"
    property color colYellow: "#e0af68"
    property string fontFamily: "JetBrainsMono Nerd Font"
    property int fontSize: 14

    // System data
    property int cpuUsage: 0
    property int memUsage: 0
    property real lastCpuIdle: 0
    property real lastCpuTotal: 0

    anchors.top: false
    anchors.bottom: true
    anchors.left: true
    anchors.right: true
    implicitHeight: 20
    color: root.colBg

    // CPU reader: parses the first line of /proc/stat
    Process {
        id: cpuProc
        command: ["sh", "-c", "head -1 /proc/stat"]
        stdout: SplitParser {
            onRead: data => {
                const p = data.trim().split(/\s+/).slice(1).map(Number)
                // user nice system idle iowait irq softirq steal
                const idle = p[3] + p[4]
                const total = p.slice(0, 8).reduce((a, b) => a + b, 0)
                if (root.lastCpuTotal > 0) {
                    const dTotal = total - root.lastCpuTotal
                    const dIdle = idle - root.lastCpuIdle
                    if (dTotal > 0)
                        root.cpuUsage = Math.round(100 * (dTotal - dIdle) / dTotal)
                }
                root.lastCpuTotal = total
                root.lastCpuIdle = idle
            }
        }
      }

    property var commands: []

    Process {
      id: cmdList
      command: ["bash", "-c", "compgen -c | sort -u"]
      running: true
      stdout: StdioCollector {
        onStreamFinished: root.commands = text.split("\n").filter(s => s.length > 0)
      }
    }

    // Memory reader: percent used based on MemAvailable
    Process {
        id: memProc
        command: ["sh", "-c",
            "awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print int((t-a)*100/t)}' /proc/meminfo"]
        stdout: SplitParser {
            onRead: data => root.memUsage = parseInt(data.trim())
        }
    }

    Timer {
        interval: 2000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!cpuProc.running) cpuProc.running = true
            if (!memProc.running) memProc.running = true
        }
    }

    RowLayout {
        anchors.fill: parent
        anchors.leftMargin: 8
        anchors.rightMargin: 8
        anchors.topMargin: 0
        anchors.bottomMargin: 0
        spacing: 8

        // Workspaces
        Repeater {
            model: 9
            Text {
                property var ws: Hyprland.workspaces.values.find(w => w.id === index + 1)
                property bool isActive: Hyprland.focusedWorkspace?.id === (index + 1)
                text: index + 1
                color: isActive ? root.colCyan : (ws ? root.colBlue : root.colMuted)
                font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
                MouseArea {
                    anchors.fill: parent
                    onClicked: Hyprland.dispatch("workspace " + (index + 1))
                }
            }
        }

        Item { Layout.fillWidth: true }

TextField {
    id: terminalInput
    Layout.preferredWidth: 300
    Layout.fillHeight: true
    Layout.topMargin: 0
    color: root.colFg
    selectionColor: root.colCyan
    selectedTextColor: root.colBg
    font { family: root.fontFamily; pixelSize: 11 }
    placeholderText: "..."
    placeholderTextColor: root.colMuted

    background: Rectangle {
        color: "#11111b"
//        border.color: terminalInput.activeFocus ? root.colCyan : root.colMuted
 
        border.width: 1
        radius: 4
      }

      onActiveFocusChanged: {
        if (!activeFocus) {
            text = ""
        }
    }

    property var matches: []
    property int matchIndex: -1
    property string prefix: ""   // everything before the word being completed

    function escapePath(s) {
        return s.replace(/([ '"\\()&;$`!#*?\[\]{}|<>])/g, "\\$1")
    }

    function applyMatch() {
        text = prefix + matches[matchIndex]
        cursorPosition = text.length
    }

    onTextEdited: {
        matches = []
        matchIndex = -1
    }

    Process {
        id: pathProc
        property string query: ""
        command: ["bash", "-c",
            'p="$1"; case "$p" in "~"*) p="$HOME${p#"~"}";; esac; ' +
            'compgen -f -- "$p" | while IFS= read -r f; do ' +
            'if [ -d "$f" ]; then echo "$f/"; else echo "$f"; fi; done',
            "_", query]
        stdout: StdioCollector {
            onStreamFinished: {
                const home = Quickshell.env("HOME")
                const q = pathProc.query
                const wantsHidden = q.split("/").pop().startsWith(".")
                let list = text.split("\n").filter(s => s.length > 0)

                if (!wantsHidden)
                    list = list.filter(s => !s.replace(/\/$/, "").split("/").pop().startsWith("."))

                if (q.startsWith("~"))
                  list = list.map(s => s.startsWith(home) ? "~" + s.slice(home.length) : s)

                list = list.map(terminalInput.escapePath).sort()
                if (list.length === 0) return

                terminalInput.matches = list
                terminalInput.matchIndex = 0
                terminalInput.applyMatch()

                if (list.length === 1) {
                    terminalInput.matches = []
                    terminalInput.matchIndex = -1
                }
            }
        }
    }

    Keys.onTabPressed: event => {
        event.accepted = true

        if (matchIndex !== -1) {
            matchIndex = (matchIndex + 1) % matches.length
            applyMatch()
            return
        }

        const word = text.match(/(?:\\ |[^ ])*$/)[0]
        prefix = text.slice(0, text.length - word.length)
        const isFirstWord = prefix.trim().length === 0

        if (isFirstWord && word.length === 0) return

        if (isFirstWord && !/^[\/~.]/.test(word)) {
            matches = root.commands
                .filter(c => c.startsWith(word))
                .sort((a, b) => a.length - b.length)
                .slice(0, 50)
            if (matches.length === 0) return
            matchIndex = 0
            applyMatch()
        } else {
            pathProc.query = word.replace(/\\(.)/g, "$1")
            pathProc.running = true
        }
    }


    Keys.onEscapePressed: {
      
      focus = false
    }
    onAccepted: {
        if (text.trim().length > 0) {
            Quickshell.execDetached(["sh", "-c", text])
            text = ""
        }
    }
}
        Rectangle { width: 1; height: 16; color: root.colMuted }

        // CPU
        Text {
            text: "CPU: " + root.cpuUsage + "%"
            color: root.colYellow
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        }

        Rectangle { width: 1; height: 16; color: root.colMuted }

        // Memory
        Text {
            text: "Mem: " + root.memUsage + "%"
            color: root.colCyan
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        }

        Rectangle { width: 1; height: 16; color: root.colMuted }

        // Clock
        Text {
            id: clock
            color: root.colBlue
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
            text: Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
            Timer {
                interval: 1000
                running: true
                repeat: true
                onTriggered: clock.text = Qt.formatDateTime(new Date(), "ddd, MMM dd - HH:mm")
            }
        }
    }
}
