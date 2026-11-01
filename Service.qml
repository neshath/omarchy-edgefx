pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Wayland

Item {
  id: root
  property bool enabled: true
  property string preset: "ambient"
  property color accent: "#7aa2f7"
  property real intensity: 0.32
  property int speed: 5
  property int pulse: 0
  property real phase: 0

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v))) }
  function normalizedPreset(v) {
    var p = String(v || "ambient").toLowerCase()
    return ["ambient", "flow", "pulse", "alert"].indexOf(p) >= 0 ? p : "ambient"
  }
  function setPreset(v) { preset = normalizedPreset(v); pulse++ }
  function setAccent(v) { try { accent = String(v) } catch (e) {} }
  function setIntensity(v) { intensity = clamp(v, 0.05, 1) }
  function setSpeed(v) { speed = Math.round(clamp(v, 1, 20)) }
  function triggerPulse() { pulse++; pulseAnimation.restart() }
  function state() {
    return JSON.stringify({ enabled: enabled, preset: preset, accent: String(accent), intensity: intensity, speed: speed, screens: Quickshell.screens.length })
  }

  NumberAnimation {
    id: phaseAnimation
    target: root
    property: "phase"
    from: 0; to: 1
    duration: Math.max(1200, 18000 / Math.max(1, root.speed))
    loops: Animation.Infinite
    running: root.enabled
  }
  onSpeedChanged: phaseAnimation.restart()
  SequentialAnimation {
    id: pulseAnimation
    NumberAnimation { target: root; property: "intensity"; to: Math.min(1, root.intensity + 0.38); duration: 90 }
    NumberAnimation { target: root; property: "intensity"; to: Math.max(0.05, root.intensity - 0.08); duration: 650; easing.type: Easing.OutCubic }
  }

  IpcHandler {
    target: "edgefx"
    function toggle(): void { root.enabled = !root.enabled }
    function enable(): void { root.enabled = true }
    function disable(): void { root.enabled = false }
    function pulse(): void { root.triggerPulse() }
    function setPreset(name: string): void { root.setPreset(name) }
    function setAccent(color: string): void { root.setAccent(color) }
    function setIntensity(value: string): void { root.setIntensity(value) }
    function setSpeed(value: string): void { root.setSpeed(value) }
    function status(): string { return root.state() }
  }

  Instantiator {
    model: Quickshell.screens
    delegate: Component {
      EdgeOverlay {
        required property var modelData
        targetScreen: modelData
        active: root.enabled
        preset: root.preset
        accent: root.accent
        intensity: root.intensity
        phase: root.phase
        pulseKey: root.pulse
      }
    }
  }

  component EdgeOverlay: PanelWindow {
    id: edge
    required property var targetScreen
    required property bool active
    required property string preset
    required property color accent
    required property real intensity
    required property real phase
    required property int pulseKey
    readonly property int thickness: Math.max(2, Math.round(2 + 8 * intensity))
    readonly property real idleAlpha: preset === "alert" ? Math.min(1, intensity + 0.2) : intensity
    screen: targetScreen
    visible: active
    color: "transparent"
    WlrLayershell.namespace: "omarchy-edgefx"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    // Empty input region: the overlay is click-through and cannot steal app input.
    mask: Region {}

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      border.width: edge.thickness
      border.color: Qt.rgba(edge.accent.r, edge.accent.g, edge.accent.b, edge.idleAlpha * (edge.preset === "pulse" ? (0.35 + 0.65 * Math.abs(Math.sin(edge.phase * Math.PI * 2))) : 1))
    }

    Rectangle {
      visible: edge.preset !== "ambient"
      x: edge.phase * Math.max(0, parent.width - width)
      y: 0
      width: Math.max(42, parent.width * 0.12)
      height: edge.thickness * 2
      color: Qt.rgba(edge.accent.r, edge.accent.g, edge.accent.b, Math.min(1, edge.idleAlpha * 1.8))
      radius: height / 2
    }
    Rectangle {
      visible: edge.preset !== "ambient"
      x: parent.width - edge.thickness * 2
      y: edge.phase * Math.max(0, parent.height - height)
      width: edge.thickness * 2
      height: Math.max(42, parent.height * 0.12)
      color: Qt.rgba(edge.accent.r, edge.accent.g, edge.accent.b, Math.min(1, edge.idleAlpha * 1.8))
      radius: width / 2
    }
    Rectangle {
      visible: edge.preset !== "ambient"
      x: (1 - edge.phase) * Math.max(0, parent.width - width)
      y: parent.height - height
      width: Math.max(42, parent.width * 0.12)
      height: edge.thickness * 2
      color: Qt.rgba(edge.accent.r, edge.accent.g, edge.accent.b, Math.min(1, edge.idleAlpha * 1.8))
      radius: height / 2
    }
    Rectangle {
      visible: edge.preset !== "ambient"
      x: 0
      y: (1 - edge.phase) * Math.max(0, parent.height - height)
      width: edge.thickness * 2
      height: Math.max(42, parent.height * 0.12)
      color: Qt.rgba(edge.accent.r, edge.accent.g, edge.accent.b, Math.min(1, edge.idleAlpha * 1.8))
      radius: width / 2
    }

    Behavior on opacity { NumberAnimation { duration: 180 } }
  }
}
