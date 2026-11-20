import QtQuick

// HSV wheel drawn once by shaders/colorwheel.frag.qsb (no continuous CPU loop).
Item {
  id: wheel
  property real hue: 0       // 0..1
  property real sat: 0       // 0..1
  property real val: 1       // 0..1
  signal picked(real hue, real sat)

  implicitWidth: 150
  implicitHeight: 150
  readonly property real radius: Math.min(width, height) / 2

  ShaderEffect {
    anchors.fill: parent
    property real value: wheel.val
    blending: true
    fragmentShader: Qt.resolvedUrl("shaders/colorwheel.frag.qsb")
  }

  Rectangle {
    id: dot
    width: 14; height: 14; radius: 7
    x: wheel.width / 2 + Math.cos(wheel.hue * 2 * Math.PI) * wheel.sat * wheel.radius - width / 2
    y: wheel.height / 2 + Math.sin(wheel.hue * 2 * Math.PI) * wheel.sat * wheel.radius - height / 2
    color: "transparent"
    border.width: 2
    border.color: wheel.val > 0.55 && wheel.sat < 0.6 ? "#000000" : "#ffffff"
    Rectangle { anchors.fill: parent; anchors.margins: 2; radius: width / 2; color: "transparent"; border.width: 1; border.color: Qt.rgba(0, 0, 0, 0.35) }
  }

  property alias dragging: ma.pressed

  MouseArea {
    id: ma
    anchors.fill: parent
    preventStealing: true
    function pick(m) {
      var dx = m.x - wheel.width / 2, dy = m.y - wheel.height / 2
      var h = Math.atan2(dy, dx) / (2 * Math.PI)
      wheel.picked((h + 1) % 1, Math.min(1, Math.sqrt(dx * dx + dy * dy) / wheel.radius))
    }
    onPressed: function(m) { pick(m) }
    onPositionChanged: function(m) { if (pressed) pick(m) }
  }
}
