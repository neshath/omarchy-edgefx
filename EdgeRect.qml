import QtQuick

// One lit rounded rectangle (the screen perimeter, or a single window border).
ShaderEffect {
  id: fx

  required property var svc
  property var occluders: []
  property real radius: 0
  property real outward: -1      // +1: light outside the rect (windows), -1: inside (screen)
  property real pad: 0           // gap between item edge and the lit rect
  property real glowWidth: 14
  property real ledWidth: svc.settings.thickness

  blending: true

  property real time: svc.time
  property real intensity: svc.settings.intensity
  property real speed: svc.settings.speed
  property int mode: svc.settings.modeIndex
  property real dir: svc.settings.direction === "ccw" ? -1 : 1
  property vector4d uAudio: Qt.vector4d(svc.audio.level, svc.audio.bass, svc.audio.mid, svc.audio.treble)
  property real uAudioEnabled: svc.audio.running ? 1 : 0
  property real uAudioSensitivity: svc.settings.audioSensitivity
  property real uAudioIdleDim: svc.settings.audioIdleDim ? 1 : 0
  property vector2d size: Qt.vector2d(width, height)
  property vector4d box: Qt.vector4d(pad, pad, width - 2 * pad, height - 2 * pad)
  property vector4d params: Qt.vector4d(radius, outward, glowWidth, ledWidth)

  function occAt(i) {
    var o = occluders && occluders[i]
    return o ? Qt.vector4d(o.x - x, o.y - y, o.w, o.h) : Qt.vector4d(0, 0, 0, 0)
  }
  property vector4d occ0: occAt(0)
  property vector4d occ1: occAt(1)
  property vector4d occ2: occAt(2)
  property vector4d occ3: occAt(3)

  property color pal0: svc.themePalette.colors[0]
  property color pal1: svc.themePalette.colors[1]
  property color pal2: svc.themePalette.colors[2]
  property color pal3: svc.themePalette.colors[3]
  property color pal4: svc.themePalette.colors[4]
  property color pal5: svc.themePalette.colors[5]

  fragmentShader: Qt.resolvedUrl("shaders/edgefx.frag.qsb")
}
