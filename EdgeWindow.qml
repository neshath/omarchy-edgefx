import QtQuick
import Quickshell
import Quickshell.Wayland

// Click-through overlay covering one monitor.
PanelWindow {
  id: win

  required property var svc
  required property var modelData
  readonly property var info: svc.tracker.screens[modelData.name] || null
  readonly property bool guarded: info ? info.fullscreen : false
  readonly property bool lit: svc.settings.enabled && !guarded
  readonly property real rounding: info ? info.rounding : 0
  readonly property var windowModel: {
    var t = svc.settings.target
    if (t === "screen" || !info) return []
    return t === "active" ? info.windows.filter(function(w) { return w.focused }) : info.windows
  }

  screen: modelData
  visible: lit
  color: "transparent"
  anchors { top: true; bottom: true; left: true; right: true }
  exclusionMode: ExclusionMode.Ignore
  WlrLayershell.layer: WlrLayer.Overlay
  WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
  WlrLayershell.namespace: "edgefx"
  mask: Region {}

  EdgeRect {
    svc: win.svc
    visible: svc.settings.target === "screen" || svc.settings.target === "both"
    x: 0; y: 0; width: win.width; height: win.height
    radius: 0
    outward: -1
    pad: 0
    glowWidth: 16
  }

  Repeater {
    model: win.windowModel
    EdgeRect {
      required property var modelData
      svc: win.svc
      occluders: modelData.occ
      x: modelData.x - pad; y: modelData.y - pad
      width: modelData.w + 2 * pad; height: modelData.h + 2 * pad
      pad: svc.settings.mode === "matrix-rain" ? 52 : 30   // room for full glyph columns
      radius: win.rounding
      outward: 1
      glowWidth: 12
    }
  }
}
