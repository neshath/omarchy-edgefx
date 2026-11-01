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
  property bool audioSync: false
  property real audioLevel: 0
  property bool mediaMode: false
  property bool dynamicColors: true
  property real bloom: 0.35
  property string mediaTitle: ""
  property string mediaArtist: ""
  property string mediaArtUrl: ""
  property string lyrics: ""
  property int pulse: 0
  property real phase: 0
  property color sunsetA: "#ffb86c"
  property color sunsetB: "#bd93f9"
  property color oceanA: "#7dd3fc"
  property color oceanB: "#2563eb"
  property color auroraA: "#8ef6d2"
  property color auroraB: "#a78bfa"
  property color fireA: "#ffd166"
  property color fireB: "#ef4444"

  readonly property real effectiveIntensity: clamp(intensity + (audioSync ? audioLevel * 0.48 : 0), 0.05, 1)

  function clamp(v, lo, hi) { return Math.max(lo, Math.min(hi, Number(v))) }
  function normalizedPreset(v) {
    var p = String(v || "ambient").toLowerCase()
    return ["ambient", "flow", "pulse", "alert", "rainbow", "sunset", "ocean", "aurora", "fire"].indexOf(p) >= 0 ? p : "ambient"
  }
  function setPreset(v) { preset = normalizedPreset(v); pulse++ }
  function setAccent(v) { try { accent = String(v) } catch (e) {} }
  function setIntensity(v) { intensity = clamp(v, 0.05, 1) }
  function setSpeed(v) { speed = Math.round(clamp(v, 1, 20)) }
  function setAudioSync(v) { audioSync = v === true || String(v) === "true" }
  function setAudioLevel(v) { audioLevel = clamp(v, 0, 1) }
  function setMediaMode(v) { mediaMode = v === true || String(v) === "true" }
  function setDynamicColors(v) { dynamicColors = v === true || String(v) === "true" }
  function setBloom(v) { bloom = clamp(v, 0, 1) }
  function setMedia(payload) {
    var parts = String(payload || "").split("|")
    mediaTitle = parts[0] || ""
    mediaArtist = parts[1] || ""
    mediaArtUrl = parts[2] || ""
  }
  function setLyrics(value) { lyrics = String(value || "") }
  function triggerPulse() { pulse++; pulseAnimation.restart() }
  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }
  function sceneColor(t) {
    var p = preset
    if (p === "rainbow" || dynamicColors) return Qt.hsva((t + phase + audioLevel * 0.18) % 1, 0.86, 1, 1)
    if (p === "sunset") return mix(sunsetA, sunsetB, t)
    if (p === "ocean") return mix(oceanA, oceanB, t)
    if (p === "aurora") return mix(auroraA, auroraB, t)
    if (p === "fire") return mix(fireA, fireB, t)
    return accent
  }
  function state() {
    return JSON.stringify({ enabled: enabled, preset: preset, accent: String(accent), intensity: intensity, speed: speed, audioSync: audioSync, audioLevel: audioLevel, mediaMode: mediaMode, dynamicColors: dynamicColors, bloom: bloom, screens: Quickshell.screens.length })
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
    function setAudioSync(value: string): void { root.setAudioSync(value) }
    function setAudioLevel(value: string): void { root.setAudioLevel(value) }
    function setMediaMode(value: string): void { root.setMediaMode(value) }
    function setDynamicColors(value: string): void { root.setDynamicColors(value) }
    function setBloom(value: string): void { root.setBloom(value) }
    function setMedia(payload: string): void { root.setMedia(payload) }
    function setLyrics(value: string): void { root.setLyrics(value) }
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
        intensity: root.effectiveIntensity
        phase: root.phase
        pulseKey: root.pulse
        mediaMode: root.mediaMode
        mediaTitle: root.mediaTitle
        mediaArtist: root.mediaArtist
        mediaArtUrl: root.mediaArtUrl
        lyrics: root.lyrics
        bloom: root.bloom
        sceneColor: function(t) { return root.sceneColor(t) }
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
    required property bool mediaMode
    required property string mediaTitle
    required property string mediaArtist
    required property string mediaArtUrl
    required property string lyrics
    required property real bloom
    required property var sceneColor
    property date now: new Date()
    readonly property int thickness: Math.max(2, Math.round(2 + 8 * intensity))
    readonly property real alpha: preset === "alert" ? Math.min(1, intensity + 0.2) : intensity
    screen: targetScreen
    visible: active
    color: "transparent"
    WlrLayershell.namespace: "omarchy-edgefx"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    anchors { top: true; bottom: true; left: true; right: true }
    mask: Region {}

    Rectangle {
      anchors.fill: parent
      color: "transparent"
      border.width: edge.thickness + Math.round(edge.bloom * 18)
      border.color: edge.sceneColor(0.5)
      opacity: edge.alpha * edge.bloom * 0.18
    }
    Rectangle {
      anchors.fill: parent
      color: "transparent"
      border.width: edge.thickness
      border.color: edge.sceneColor(0.20 + edge.phase * 0.60)
      opacity: edge.alpha * (edge.preset === "pulse" ? (0.35 + 0.65 * Math.abs(Math.sin(edge.phase * Math.PI * 2))) : 1)
    }
    Rectangle {
      visible: edge.preset !== "ambient"
      x: edge.phase * Math.max(0, parent.width - width); y: 0
      width: Math.max(46, parent.width * 0.12); height: edge.thickness * 2
      color: edge.sceneColor(edge.phase); opacity: Math.min(1, edge.alpha * 1.8); radius: height / 2
    }
    Rectangle {
      visible: edge.preset !== "ambient"
      x: parent.width - edge.thickness * 2; y: edge.phase * Math.max(0, parent.height - height)
      width: edge.thickness * 2; height: Math.max(46, parent.height * 0.12)
      color: edge.sceneColor((edge.phase + 0.25) % 1); opacity: Math.min(1, edge.alpha * 1.8); radius: width / 2
    }
    Rectangle {
      visible: edge.preset !== "ambient"
      x: (1 - edge.phase) * Math.max(0, parent.width - width); y: parent.height - height
      width: Math.max(46, parent.width * 0.12); height: edge.thickness * 2
      color: edge.sceneColor((edge.phase + 0.5) % 1); opacity: Math.min(1, edge.alpha * 1.8); radius: height / 2
    }
    Rectangle {
      visible: edge.preset !== "ambient"
      x: 0; y: (1 - edge.phase) * Math.max(0, parent.height - height)
      width: edge.thickness * 2; height: Math.max(46, parent.height * 0.12)
      color: edge.sceneColor((edge.phase + 0.75) % 1); opacity: Math.min(1, edge.alpha * 1.8); radius: width / 2
    }

    Rectangle {
      visible: edge.mediaMode && (edge.mediaTitle !== "" || edge.lyrics !== "")
      anchors.centerIn: parent
      width: Math.min(420, parent.width * 0.42)
      height: Math.min(330, parent.height * 0.42)
      radius: 18
      color: Qt.rgba(0.03, 0.04, 0.08, 0.76)
      border.width: 1
      border.color: Qt.rgba(edge.sceneColor(0.35).r, edge.sceneColor(0.35).g, edge.sceneColor(0.35).b, 0.7)
      Column {
        anchors.centerIn: parent
        width: parent.width - 36
        spacing: 8
        Image { visible: edge.mediaArtUrl !== ""; source: edge.mediaArtUrl; width: 150; height: 150; anchors.horizontalCenter: parent.horizontalCenter; fillMode: Image.PreserveAspectCrop; smooth: true }
        Text { text: edge.mediaTitle; color: "white"; font.pixelSize: 22; font.bold: true; elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter }
        Text { text: edge.mediaArtist; color: edge.sceneColor(0.4); font.pixelSize: 14; elide: Text.ElideRight; width: parent.width; horizontalAlignment: Text.AlignHCenter }
        Text { visible: edge.lyrics !== ""; text: edge.lyrics; color: "#f8fafc"; font.pixelSize: 16; width: parent.width; wrapMode: Text.WordWrap; horizontalAlignment: Text.AlignHCenter; maximumLineCount: 3 }
        Text { text: Qt.formatDateTime(edge.now, "HH:mm  ddd, MMM d"); color: "#b8bfd8"; font.pixelSize: 12; width: parent.width; horizontalAlignment: Text.AlignHCenter }
      }
      Timer { interval: 1000; running: edge.visible; repeat: true; onTriggered: edge.now = new Date() }
    }
  }
}
