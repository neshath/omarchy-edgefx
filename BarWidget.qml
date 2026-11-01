pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.Commons
import qs.Ui

BarWidget {
  id: root
  moduleName: "io.github.neshath.edgefx"
  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function" ? bar.shell.serviceFor(root.moduleName) : null
  readonly property bool active: service ? service.enabled : root.enabled(root.setting("enabled", true))
  readonly property string currentPreset: String(root.setting("preset", "ambient"))
  readonly property string currentAccent: String(root.setting("accent", "#7aa2f7"))
  readonly property real currentIntensity: Number(root.setting("intensity", 0.32))
  readonly property int currentSpeed: Number(root.setting("speed", 5))

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
        } else {
          root.popupOpen = !root.popupOpen
        }
      }
    }
  }

  PopupWindow {
    visible: root.popupOpen
    anchor.window: root.QsWindow ? root.QsWindow.window : null
    anchor.rect.x: 0
    anchor.rect.y: root.height
    implicitWidth: 280
    implicitHeight: 190
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
        spacing: 8
        Text { text: "EdgeFX"; color: "white"; font.bold: true; font.pixelSize: 16 }
        Text { text: "Preset: " + root.currentPreset; color: "#b8bfd8" }
        Row {
          spacing: 6
          Repeater {
            model: ["ambient", "flow", "pulse", "alert"]
            delegate: Rectangle {
              required property string modelData
              width: 56; height: 28; radius: 6
              color: modelData === root.currentPreset ? root.currentAccent : "#2a3040"
              Text { anchors.centerIn: parent; text: parent.modelData; color: "white"; font.pixelSize: 10 }
              MouseArea { anchors.fill: parent; onClicked: { root.commit("preset", modelData); root.sync() } }
            }
          }
        }
        Text { text: "Left click toggles · use CLI for color/speed/intensity"; color: "#8790aa"; font.pixelSize: 11; wrapMode: Text.WordWrap; width: parent.width }
      }
    }
  }
}
