pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.neshath.edgefx"
  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell.serviceFor(root.moduleName) : null
  readonly property bool active: service ? service.enabled : root.asBool(root.setting("enabled", true))
  readonly property string currentPreset: String(root.setting("preset", "ambient"))
  readonly property string currentAccent: String(root.setting("accent", "#7aa2f7"))
  readonly property real currentIntensity: Number(root.setting("intensity", 0.32))
  readonly property int currentSpeed: Number(root.setting("speed", 5))
  readonly property bool currentAudioSync: root.asBool(root.setting("audioSync", false))
  readonly property bool currentMediaMode: root.asBool(root.setting("mediaMode", false))
  readonly property bool currentDynamicColors: root.asBool(root.setting("dynamicColors", true))
  readonly property real currentBloom: Number(root.setting("bloom", 0.35))
  readonly property var presets: ["ambient", "rainbow", "sunset", "ocean", "aurora", "fire", "pulse", "alert"]
  readonly property var swatches: ["#7aa2f7", "#ff6bcb", "#ffd166", "#4ade80", "#38bdf8", "#f97316", "#bd93f9", "#f8fafc"]

  function asBool(v) { return v === true || String(v) === "true" }
  function commit(key, value) {
    var entry = { id: root.moduleName }
    for (var k in root.settings) if (k !== "id") entry[k] = root.settings[k]
    entry[key] = value
    root.settings = entry
    if (root.bar && root.bar.shell && typeof root.bar.shell.updateEntryInline === "function") root.bar.shell.updateEntryInline(root.moduleName, entry)
  }
  function sync() {
    if (!service) return
    service.enabled = root.asBool(root.setting("enabled", true))
    service.setPreset(root.currentPreset)
    service.setAccent(root.currentAccent)
    service.setIntensity(root.currentIntensity)
    service.setSpeed(root.currentSpeed)
    service.setAudioSync(root.currentAudioSync)
    service.setMediaMode(root.currentMediaMode)
    service.setDynamicColors(root.currentDynamicColors)
    service.setBloom(root.currentBloom)
  }
  function open() { root.popupOpen = true }
  function close() { root.popupOpen = false }
  readonly property bool opened: root.popupOpen
  property bool popupOpen: false

  Component.onCompleted: sync()
  onServiceChanged: sync()
  onSettingsChanged: sync()

  contentItem: Item {
    implicitWidth: 32; implicitHeight: 32
    Text {
      anchors.centerIn: parent
      text: root.active ? "◉" : "○"
      color: root.active ? root.currentAccent : "#777777"
      font.pixelSize: 18
    }
    MouseArea {
      anchors.fill: parent
      acceptedButtons: Qt.LeftButton | Qt.RightButton
      onClicked: function(mouse) {
        if (mouse.button === Qt.LeftButton) {
          var next = !root.active
          if (root.service) root.service.enabled = next
          root.commit("enabled", next)
        } else root.popupOpen = !root.popupOpen
      }
    }
  }

  PopupWindow {
    visible: root.popupOpen
    anchor.window: root.QsWindow ? root.QsWindow.window : null
    anchor.rect.x: 0
    anchor.rect.y: root.height
    implicitWidth: 330
    implicitHeight: 415
    color: "#171a24"
    Rectangle {
      anchors.fill: parent
      color: "#171a24"
      border.color: root.currentAccent
      border.width: 1
      radius: 10
      Column {
        anchors.fill: parent
        anchors.margins: 14
        spacing: 9
        Text { text: "EdgeFX scenes"; color: "white"; font.bold: true; font.pixelSize: 16 }
        Text { text: "Current: " + root.currentPreset; color: "#b8bfd8"; font.pixelSize: 12 }
        Flow {
          width: parent.width
          spacing: 5
          Repeater {
            model: root.presets
            delegate: Rectangle {
              required property string modelData
              width: 68; height: 27; radius: 6
              color: modelData === root.currentPreset ? root.currentAccent : "#2a3040"
              Text { anchors.centerIn: parent; text: modelData; color: "white"; font.pixelSize: 10 }
              MouseArea { anchors.fill: parent; onClicked: { root.commit("preset", modelData); root.sync() } }
            }
          }
        }
        Text { text: "Color"; color: "#b8bfd8"; font.pixelSize: 12 }
        Row {
          spacing: 10
          Canvas {
            id: colorWheel
            width: 112; height: 112
            onPaint: {
              var ctx = getContext("2d")
              ctx.clearRect(0, 0, width, height)
              var cx = width / 2; var cy = height / 2; var radius = width / 2
              for (var i = 0; i < 72; i++) {
                var a0 = i * Math.PI * 2 / 72
                var a1 = (i + 1) * Math.PI * 2 / 72
                ctx.beginPath(); ctx.moveTo(cx, cy); ctx.arc(cx, cy, radius, a0, a1); ctx.closePath()
                ctx.fillStyle = Qt.hsva(i / 72, 0.88, 1, 1); ctx.fill()
              }
              var white = ctx.createRadialGradient(cx, cy, 0, cx, cy, radius)
              white.addColorStop(0, "white"); white.addColorStop(1, "transparent")
              ctx.fillStyle = white; ctx.beginPath(); ctx.arc(cx, cy, radius, 0, Math.PI * 2); ctx.fill()
            }
            MouseArea {
              anchors.fill: parent
              onClicked: function(mouse) {
                var dx = mouse.x - width / 2; var dy = mouse.y - height / 2
                var distance = Math.min(1, Math.sqrt(dx * dx + dy * dy) / (width / 2))
                var hue = (Math.atan2(dy, dx) / (Math.PI * 2) + 1) % 1
                root.commit("accent", Qt.hsva(hue, distance, 1, 1)); root.sync()
              }
            }
          }
          Column {
            spacing: 6
            Text { text: "Click the wheel or choose a swatch"; color: "#8790aa"; font.pixelSize: 10; width: 180; wrapMode: Text.WordWrap }
            Row {
              spacing: 7
              Repeater {
                model: root.swatches
                delegate: Rectangle {
                  required property string modelData
                  width: 24; height: 24; radius: 12
                  color: modelData
                  border.width: modelData === root.currentAccent ? 3 : 1
                  border.color: "white"
                  MouseArea { anchors.fill: parent; onClicked: { root.commit("accent", modelData); root.sync() } }
                }
              }
            }
          }
        }
        Row {
          spacing: 8
          Text { text: "Brightness"; color: "#b8bfd8"; width: 70; anchors.verticalCenter: parent.verticalCenter }
          Rectangle { width: 180; height: 8; radius: 4; color: "#30384c"; anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: parent.width * root.currentIntensity; height: parent.height; radius: 4; color: root.currentAccent }
            MouseArea { anchors.fill: parent; onClicked: function(mouse) { var v = Math.max(0.05, Math.min(1, mouse.x / width)); root.commit("intensity", v); root.sync() } }
          }
        }
        Rectangle {
          width: parent.width; height: 34; radius: 7
          color: root.currentAudioSync ? root.currentAccent : "#2a3040"
          Text { anchors.centerIn: parent; text: root.currentAudioSync ? "Audio Sync: ON" : "Audio Sync: OFF"; color: "white"; font.pixelSize: 12 }
          MouseArea { anchors.fill: parent; onClicked: { root.commit("audioSync", !root.currentAudioSync); root.sync() } }
        }
        Row {
          width: parent.width; spacing: 7
          Rectangle {
            width: (parent.width - 7) / 2; height: 34; radius: 7
            color: root.currentMediaMode ? root.currentAccent : "#2a3040"
            Text { anchors.centerIn: parent; text: root.currentMediaMode ? "Media: ON" : "Media: OFF"; color: "white"; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; onClicked: { root.commit("mediaMode", !root.currentMediaMode); root.sync() } }
          }
          Rectangle {
            width: (parent.width - 7) / 2; height: 34; radius: 7
            color: root.currentDynamicColors ? root.currentAccent : "#2a3040"
            Text { anchors.centerIn: parent; text: root.currentDynamicColors ? "Dynamic: ON" : "Dynamic: OFF"; color: "white"; font.pixelSize: 11 }
            MouseArea { anchors.fill: parent; onClicked: { root.commit("dynamicColors", !root.currentDynamicColors); root.sync() } }
          }
        }
        Row {
          spacing: 8
          Text { text: "Bloom"; color: "#b8bfd8"; width: 70; anchors.verticalCenter: parent.verticalCenter }
          Rectangle { width: 180; height: 8; radius: 4; color: "#30384c"; anchors.verticalCenter: parent.verticalCenter
            Rectangle { width: parent.width * root.currentBloom; height: parent.height; radius: 4; color: root.currentAccent }
            MouseArea { anchors.fill: parent; onClicked: function(mouse) { var v = Math.max(0, Math.min(1, mouse.x / width)); root.commit("bloom", v); root.sync() } }
          }
        }
        Text { text: "Media bridge: edgefx-media-sync · lyrics: ~/.config/omarchy/edgefx/lyrics.txt"; color: "#8790aa"; font.pixelSize: 10; wrapMode: Text.WordWrap; width: parent.width }
        Text { text: "Left click toggles · right click opens controls"; color: "#8790aa"; font.pixelSize: 11 }
      }
    }
  }
}
