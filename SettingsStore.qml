import QtQuick
import Quickshell
import Quickshell.Io

// Settings persisted in ~/.config/omarchy/edgefx.json. The service and the
// popover each hold a store; the file watcher keeps them in sync.
Item {
  id: root
  visible: false

  readonly property var modes: ["comet-trail", "pixel-trail", "light-bloom", "overflow-sweep",
    "converge-flash", "accelerating-streak", "segment-chase", "full-light-strip",
    "silk-line", "breathing-pulse", "aurora-wave", "prism-refract", "dual-orbit",
    "radar-sweep", "plasma-flow", "spark-ember", "corner-glow", "neon-flicker",
    "audio-spectrum", "bass-pulse", "eq-wave", "matrix-rain"]
  readonly property var targets: ["screen", "active", "windows", "both"]

  property bool enabled: true
  property string mode: "comet-trail"
  property string target: "both"
  property real intensity: 1.0
  property real speed: 1.0
  property int fps: 60
  property real thickness: 3.0
  property bool audioSync: false
  property real audioSensitivity: 1.0
  property bool audioIdleDim: true
  property string direction: "cw"   // "cw" | "ccw"
  property string colorMode: "theme"          // "theme" | "custom"
  property string customColor: "#7aa2f7"
  property string customHarmony: "harmonized" // "solid" | "harmonized"

  readonly property int modeIndex: Math.max(0, modes.indexOf(mode))
  property var recentWrites: []      // our own recent snapshots; their late watcher events must not revert newer state

  function applyJson(text) {
    if (recentWrites.indexOf(text) >= 0 || saveTimer.running) return
    var j
    try { j = JSON.parse(text) } catch (e) { return }
    if (typeof j !== "object" || j === null) return
    if (typeof j.enabled === "boolean") enabled = j.enabled
    if (modes.indexOf(j.mode) >= 0) mode = j.mode
    if (targets.indexOf(j.target) >= 0) target = j.target
    if (isFinite(j.intensity)) intensity = Math.max(0.1, Math.min(2, Number(j.intensity)))
    if (isFinite(j.speed)) speed = Math.max(0.1, Math.min(3, Number(j.speed)))
    if (j.colorMode === "theme" || j.colorMode === "custom") colorMode = j.colorMode
    if (typeof j.customColor === "string" && /^#[0-9a-fA-F]{6}$/.test(j.customColor)) customColor = j.customColor.toLowerCase()
    if (j.customHarmony === "solid" || j.customHarmony === "harmonized") customHarmony = j.customHarmony
    if (typeof j.audioSync === "boolean") audioSync = j.audioSync
    if (isFinite(j.audioSensitivity)) audioSensitivity = Math.max(0.5, Math.min(2.5, Number(j.audioSensitivity)))
    if (typeof j.audioIdleDim === "boolean") audioIdleDim = j.audioIdleDim
    if (isFinite(j.thickness)) thickness = Math.max(1, Math.min(8, Number(j.thickness)))
    if (j.direction === "cw" || j.direction === "ccw") direction = j.direction
    if (isFinite(j.fps)) fps = Number(j.fps) <= 30 ? 30 : 60
  }

  function snapshot() {
    return JSON.stringify({ enabled: enabled, mode: mode, target: target,
      intensity: Math.round(intensity * 100) / 100, speed: Math.round(speed * 100) / 100, fps: fps, thickness: Math.round(thickness * 10) / 10, direction: direction,
      audioSync: audioSync, audioSensitivity: Math.round(audioSensitivity * 100) / 100, audioIdleDim: audioIdleDim,
      colorMode: colorMode, customColor: customColor, customHarmony: customHarmony }, null, 2) + "\n"
  }

  function save() { saveTimer.restart() }

  function setMode(name) { if (modes.indexOf(name) >= 0) { mode = name; save(); return true } return false }
  function setTarget(name) { if (targets.indexOf(name) >= 0) { target = name; save(); return true } return false }
  function setColorMode(v) { if (v === "theme" || v === "custom") { colorMode = v; save(); return true } return false }
  function setCustomColor(v) {
    var c = String(v).trim().toLowerCase()
    if (!/^#[0-9a-f]{6}$/.test(c)) return false
    customColor = c; save(); return true
  }
  function setCustomHarmony(v) { if (v === "solid" || v === "harmonized") { customHarmony = v; save(); return true } return false }
  function reset() {
    mode = "comet-trail"; target = "both"; intensity = 1.0; speed = 1.0; thickness = 3.0
    direction = "cw"; fps = 60; audioSensitivity = 1.0; audioIdleDim = true; colorMode = "theme"; customHarmony = "harmonized"
    save()
  }
  function toggleAudio() { audioSync = !audioSync; save() }
  function setAudioSync(v) {
    var t = String(v).toLowerCase()
    if (t === "on" || t === "true" || t === "1") audioSync = true
    else if (t === "off" || t === "false" || t === "0") audioSync = false
    else return false
    save(); return true
  }
  function nextMode() { mode = modes[(modeIndex + 1) % modes.length]; save() }
  function toggle() { enabled = !enabled; save() }

  Timer {
    id: saveTimer
    interval: 150
    onTriggered: {
      var snap = root.snapshot()
      root.recentWrites = root.recentWrites.concat([snap]).slice(-8)
      file.setText(snap)
    }
  }

  FileView {
    id: file
    path: Quickshell.env("HOME") + "/.config/omarchy/edgefx.json"
    watchChanges: true
    printErrors: false
    atomicWrites: true
    onFileChanged: reload()
    onLoaded: root.applyJson(text())
    onLoadFailed: function(error) { if (error === FileViewError.FileNotFound) root.save() }
  }

  Component.onDestruction: saveTimer.stop()
}
