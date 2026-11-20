import QtQuick
import Quickshell
import qs.Commons

// Always-on EdgeFx service: one click-through overlay per monitor.
Item {
  id: root
  property var shell: null

  readonly property alias settings: store
  readonly property alias themePalette: paletteModel
  readonly property alias tracker: tracker
  readonly property alias audio: audio
  property real time: 0
  property real lastTick: 0

  readonly property bool anyLit: {
    if (!store.enabled) return false
    var s = tracker.screens
    for (var i = 0; i < Quickshell.screens.length; i++) {
      var info = s[Quickshell.screens[i].name]
      if (!info || !info.fullscreen) return true
    }
    return false
  }

  SettingsStore { id: store }
  ThemePalette {
    id: paletteModel
    colorMode: store.colorMode
    customColor: store.customColor
    customHarmony: store.customHarmony
  }
  HyprTracker {
    id: tracker
    active: store.enabled
    // 1 s resize poll only while windows are drawn and at least one monitor is lit.
    pollWindows: store.enabled && store.target !== "screen" && root.anyLit
  }

  AudioTracker {
    id: audio
    active: store.enabled && store.audioSync && root.anyLit
  }

  Variants {
    model: Quickshell.screens
    EdgeWindow { svc: root }
  }

  // 0 FPS when disabled or every monitor is guarded by a fullscreen window.
  Timer {
    id: clock
    interval: Math.round(1000 / store.fps)
    repeat: true
    running: root.anyLit
    onRunningChanged: if (running) root.lastTick = Date.now()
    onTriggered: {
      var now = Date.now()
      var boost = audio.running ? 1 + audio.mid * store.audioSensitivity * 0.8 : 1   // mids gently speed up the flow
      root.time = (root.time + boost * (now - root.lastTick) / 1000) % 3600
      root.lastTick = now
    }
  }

  ShellIpc {
    target: "edgefx"

    function toggle(): void { store.toggle() }
    function nextMode(): void { store.nextMode() }
    function setMode(name: string): void { store.setMode(name) }
    function setTarget(value: string): void { store.setTarget(value) }
    function status(): string { return store.snapshot() }
    function setColorMode(value: string): void { store.setColorMode(value) }
    function setCustomColor(value: string): void { store.setCustomColor(value) }
    function toggleAudio(): void { store.toggleAudio() }
    function setAudioSync(value: string): void { store.setAudioSync(value) }
    function palette(): string { return JSON.stringify(paletteModel.colors) }
  }

  Component.onDestruction: clock.stop()
}
