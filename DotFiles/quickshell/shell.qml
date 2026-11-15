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

WlrLayershell.keyboardFocus: launcher.active
    ? WlrKeyboardFocus.Exclusive
    : WlrKeyboardFocus.OnDemand

WlrLayershell.layer: launcher.active ? WlrLayer.Overlay : WlrLayer.Top

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
        
        Item {
            id: launcherZone
            Layout.fillWidth: true
            Layout.fillHeight: true

            HoverHandler { id: zoneHover }

            BarLauncher {
                id: launcher
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                hovered: zoneHover.hovered
                fontFamily: root.fontFamily
            }
        }

        Rectangle { width: 1; height: 16; color: root.colMuted }

        TerminalInput {
          id: terminalInput
          Layout.preferredWidth: 300
          Layout.fillHeight: true
          commands: root.commands
          colFg: root.colFg
          colBg: root.colBg
          colCyan: root.colCyan
          colMuted: root.colMuted
          fontFamily: root.fontFamily
        }
        // CPU
        Text {
            text: "C: " + root.cpuUsage + "%"            
            color: root.colCyan
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        }

        Rectangle { width: 1; height: 16; color: root.colMuted }

        // Memory
        Text {
            text: "M: " + root.memUsage + "%"
            color: root.colCyan
            font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }
        }


        Rectangle { width: 1; height: 16; color: root.colMuted }


        Loader {
          id: batteryLoader

          // Check if UPower.devices contains an actual physical battery with real capacity
          readonly property bool hasBattery: {
              let list = UPower.devices.values;
              for (let i = 0; i < list.length; i++) {
                  let dev = list[i];
                  if (dev.isLaptopBattery && dev.isPresent && dev.energyCapacity > 0) {
                      return true;
                  }
              }
              return false;
          }

          active: hasBattery
          visible: active

          // Collapse completely in any layout when inactive
          Layout.preferredWidth: active ? implicitWidth : 0
          Layout.preferredHeight: active ? implicitHeight : 0
          width: active ? implicitWidth : 0
          height: active ? implicitHeight : 0

          sourceComponent: Text {
              readonly property var bat: UPower.displayDevice
              property int pct: bat.percentage <= 1 
                  ? Math.round(bat.percentage * 100) 
                  : Math.round(bat.percentage)

              text: "🔋" + pct + "%"
                  color: root.colCyan
                  font { family: root.fontFamily; pixelSize: root.fontSize; bold: true }        
          }


          Rectangle { width: active ? 1 : 0; height: 16; color: root.colMuted }
        }

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
