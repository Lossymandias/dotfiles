import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io

TextField {
    id: terminalInput

    // Passed in from the bar (no more reliance on the bar's `root` id)
    property var commands: []
    property color colFg: "#ffffff"
    property color colBg: "#000000"
    property color colCyan: "#ffffff"
    property color colMuted: "#444444"
    property string fontFamily: "JetBrainsMono Nerd Font"

    // Tab-completion state
    property var matches: []
    property int matchIndex: -1
    property string prefix: ""   // everything before the word being completed

    color: colFg
    selectionColor: colCyan
    selectedTextColor: colBg
    font { family: terminalInput.fontFamily; pixelSize: 11 }
    placeholderText: "..."
    placeholderTextColor: colMuted

    background: Rectangle {
        color: "#11111b"
        border.width: 1
        radius: 4
    }

    onActiveFocusChanged: {
        if (!activeFocus) text = ""
    }

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

    // File/path completion
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
            matches = commands
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

    Keys.onEscapePressed: focus = false

    onAccepted: {
        if (text.trim().length > 0) {
            Quickshell.execDetached(["sh", "-c", text])
            text = ""
        }
    }
}
