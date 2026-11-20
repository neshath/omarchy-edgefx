import QtQuick
import Quickshell
import Quickshell.Io

// Runs scripts/audio-meter.py (PipeWire monitor -> level/bass/mid/treble) only
// while `active`, and eases the values back to 0 when it stops.
Item {
  id: root
  visible: false

  property bool active: false
  property real level: 0
  property real bass: 0
  property real mid: 0
  property real treble: 0
  readonly property bool running: proc.running

  readonly property string scriptPath: Qt.resolvedUrl("scripts/audio-meter.py").toString().replace(/^file:\/\//, "")
  property int restarts: 0

  function clamp01(v) { return isFinite(v) ? Math.max(0, Math.min(1, v)) : 0 }

  onActiveChanged: {
    restarts = 0
    if (!active) restartTimer.stop()
  }

  Process {
    id: proc
    running: root.active
    command: ["python3", root.scriptPath]
    stdout: SplitParser {
      onRead: function(line) {
        var p = String(line).trim().split(" ")
        if (p.length < 4) return
        root.level = root.clamp01(Number(p[0]))
        root.bass = root.clamp01(Number(p[1]))
        root.mid = root.clamp01(Number(p[2]))
        root.treble = root.clamp01(Number(p[3]))
      }
    }
    onExited: if (root.active && root.restarts < 5) restartTimer.restart()
  }

  Timer {
    id: restartTimer
    interval: 3000
    onTriggered: if (root.active) { root.restarts++; proc.running = true }
  }

  // Smooth fall to zero once the meter stops.
  Timer {
    interval: 33
    repeat: true
    running: !root.active && (root.level + root.bass + root.mid + root.treble) > 0.004
    onTriggered: {
      root.level *= 0.8; root.bass *= 0.8; root.mid *= 0.8; root.treble *= 0.8
      if (root.level + root.bass + root.mid + root.treble <= 0.004) { root.level = 0; root.bass = 0; root.mid = 0; root.treble = 0 }
    }
  }

  Component.onDestruction: {
    restartTimer.stop()
    proc.running = false
  }
}
