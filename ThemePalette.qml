import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons as Commons

// Effective 6-color palette. "theme" mode reads named tokens from the active
// Omarchy colors.toml (per-token fallback to Commons.Color); "custom" mode
// derives it from one picked color (solid, or a harmonized analogous set).
Item {
  id: root
  visible: false

  property string colorMode: "theme"
  property string customColor: "#7aa2f7"
  property string customHarmony: "harmonized"
  property string themeName: ""

  readonly property var tokens: ["accent", "magenta", "cyan", "green", "yellow", "red"]
  property var themeColors: fallbackColors()
  readonly property var colors: build(colorMode, customColor, customHarmony, themeColors)

  function fallbackFor(i) {
    var c = Commons.Color
    var f = [c.accent, c.foreground, c.urgent, c.muted, Qt.lighter(c.accent, 1.4), Qt.darker(c.accent, 1.4)]
    return String(f[i])
  }

  function fallbackColors() {
    var out = []
    for (var i = 0; i < 6; i++) out.push(fallbackFor(i))
    return out
  }

  function hex(c) {
    function h(v) { var n = Math.round(v * 255).toString(16); return n.length < 2 ? "0" + n : n }
    return "#" + h(c.r) + h(c.g) + h(c.b)
  }

  function build(mode, custom, harmony, theme) {
    if (mode !== "custom") return theme
    var c = Qt.color(custom)
    if (harmony === "solid" || c.hsvHue < 0) return [custom, custom, custom, custom, custom, custom]
    var offs = [0, 0.06, -0.06, 0.12, -0.12, 0.5]
    var out = []
    for (var i = 0; i < 6; i++) {
      var hue = (c.hsvHue + offs[i] + 1) % 1
      var sat = Math.min(1, c.hsvSaturation * (i === 5 ? 0.85 : 1))
      out.push(hex(Qt.hsva(hue, sat, c.hsvValue, 1)))
    }
    return out
  }

  function apply(text) {
    var map = {}
    var lines = String(text).split("\n")
    for (var i = 0; i < lines.length; i++) {
      var m = /^\s*([A-Za-z0-9_]+)\s*=\s*["']?(#[0-9a-fA-F]{6,8})["']?/.exec(lines[i])
      if (m) map[m[1]] = m[2]
    }
    var out = []
    for (var j = 0; j < tokens.length; j++) out.push(map[tokens[j]] || fallbackFor(j))
    root.themeColors = out
  }

  FileView {
    id: colorsFile
    path: Commons.Color.currentThemePath + "/colors.toml"
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.apply(text())
    onLoadFailed: root.themeColors = root.fallbackColors()
  }

  // Theme swaps replace the theme directory; poke a reload when shell colors change.
  Connections {
    target: Commons.Color
    function onAccentChanged() { colorsFile.reload() }
    function onBackgroundChanged() { colorsFile.reload() }
  }

  FileView {
    id: themeName
    path: Quickshell.env("HOME") + "/.local/state/omarchy/current/theme.name"
    watchChanges: true
    printErrors: false
    onFileChanged: { reload(); colorsFile.reload() }
    onLoaded: root.themeName = String(text()).trim()
  }
}
