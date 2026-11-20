import QtQuick
import Quickshell
import qs.Commons
import qs.Commons as Commons
import qs.Ui

Panel {
  id: root
  moduleName: "io.github.neshath.edgefx"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null
  readonly property var barIdentity: hostWidget || root
  property int tab: 0

  function open() { root.controller.show() }
  function openFromHotkey() { root.controller.show() }
  function close() { root.controller.hide() }
  function toggle() { root.opened ? root.close() : root.open() }

  SettingsStore { id: store }
  ThemePalette {
    id: themeColors
    colorMode: store.colorMode
    customColor: store.customColor
    customHarmony: store.customHarmony
  }

  readonly property color fg: Commons.Color.popups.text
  readonly property color accent: Commons.Color.accent
  readonly property color popBg: Commons.Color.popups.background
  readonly property color primary: themeColors.colors[0]
  readonly property color mutedFg: Qt.alpha(fg, 0.45)
  readonly property bool rounded: Style.cornerRadius > 0
  function pill(h) { return rounded ? h / 2 : 0 }
  function soft(r) { return rounded ? r : 0 }

  // One shared preview clock: 30 FPS, only while the popover is open on the Effects tab.
  property real previewTime: 1.8
  property real lastPreviewTick: 0
  Timer {
    interval: 33
    repeat: true
    running: root.opened && root.tab === 0
    onRunningChanged: if (running) root.lastPreviewTick = Date.now()
    onTriggered: {
      var now = Date.now()
      root.previewTime = (root.previewTime + (now - root.lastPreviewTick) / 1000) % 3600
      root.lastPreviewTick = now
    }
  }

  // Wheel state (HSV). Re-synced from the store only for external changes (IPC).
  property real hue: 0.6
  property real sat: 0.5
  property real val: 1.0
  property string lastCommitted: ""

  function hexOf(h, s, v) {
    var c = Qt.hsva(h, s, v, 1)
    function p(x) { var n = Math.round(x * 255).toString(16); return n.length < 2 ? "0" + n : n }
    return "#" + p(c.r) + p(c.g) + p(c.b)
  }
  function commit() {
    lastCommitted = hexOf(hue, sat, val)
    store.setCustomColor(lastCommitted)
  }
  function syncFromStore() {
    if (store.customColor === lastCommitted) return
    var c = Qt.color(store.customColor)
    if (c.hsvHue >= 0) hue = c.hsvHue
    sat = c.hsvSaturation
    val = c.hsvValue
    lastCommitted = store.customColor
  }
  Connections { target: store; function onCustomColorChanged() { root.syncFromStore() } }
  Component.onCompleted: syncFromStore()

  function prettyName(n) {
    if (n === "matrix-rain") return "Matrix"
    var s = String(n).replace(/-/g, " ")
    return s.charAt(0).toUpperCase() + s.slice(1)
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    centerOnBar: false
    focusTarget: panel.loadedContent
    contentWidth: panel.fittedContentWidth(Style.space(360))
    contentHeight: panel.fittedContentHeight(panel.loadedContentHeight)

    content: PanelKeyCatcher {
      id: body
      implicitHeight: Style.space(470)
      onCloseRequested: root.close()

      // Always reopen scrolled to the top of the effect grid.
      Connections { target: root; function onOpenedChanged() { if (root.opened) effectsView.contentY = 0 } }

      // ---- Header -------------------------------------------------------
      Item {
        id: header
        anchors { top: parent.top; left: parent.left; right: parent.right }
        height: Style.space(30)

        Item {
          id: statusDot
          anchors.verticalCenter: parent.verticalCenter
          width: Style.space(14); height: width
          Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: store.enabled ? Qt.alpha(root.primary, 0.28) : "transparent"
            Behavior on color { ColorAnimation { duration: 160 } }
          }
          Rectangle {
            anchors.centerIn: parent
            width: Style.space(8); height: width; radius: width / 2
            color: store.enabled ? root.primary : root.mutedFg
            Behavior on color { ColorAnimation { duration: 160 } }
          }
        }
        Text {
          anchors.left: statusDot.right
          anchors.leftMargin: Style.space(8)
          anchors.verticalCenter: parent.verticalCenter
          text: "EdgeFx"
          color: root.fg
          font.family: Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: Style.space(10)

          Rectangle {
            id: resetBtn
            width: Style.space(26); height: width
            radius: root.pill(height)
            color: resetMa.containsMouse ? Qt.alpha(root.fg, 0.12) : "transparent"
            anchors.verticalCenter: parent.verticalCenter
            Text {
              anchors.centerIn: parent
              text: "↺"
              color: resetMa.containsMouse ? root.fg : root.mutedFg
              font.pixelSize: Style.font.title
            }
            MouseArea {
              id: resetMa
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: store.reset()
            }
          }

          Rectangle {   // pill power toggle
            id: power
            width: Style.space(40); height: Style.space(22)
            anchors.verticalCenter: parent.verticalCenter
            radius: root.pill(height)
            color: store.enabled ? Qt.alpha(root.primary, 0.9) : Qt.alpha(root.fg, 0.16)
            Behavior on color { ColorAnimation { duration: 160 } }
            Rectangle {
              width: parent.height - Style.space(6); height: width
              radius: root.pill(height)
              anchors.verticalCenter: parent.verticalCenter
              x: store.enabled ? parent.width - width - Style.space(3) : Style.space(3)
              color: store.enabled ? root.popBg : root.fg
              Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            }
            MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: store.toggle() }
          }
        }
      }

      // ---- Tab bar ------------------------------------------------------
      Segmented {
        id: tabBar
        anchors { top: header.bottom; topMargin: Style.space(12); left: parent.left; right: parent.right }
        labels: ["Effects", "Color", "Tune"]
        current: root.tab
        onPicked: function(i) { root.tab = i }
      }

      // ---- Effects tab --------------------------------------------------
      Flickable {
        id: effectsView
        visible: root.tab === 0
        anchors { top: tabBar.bottom; topMargin: Style.space(12); left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: grid.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Grid {
          id: grid
          width: effectsView.width
          columns: 2
          spacing: Style.space(8)
          Repeater {
            model: store.modes
            ModeCard {
              required property int index
              required property var modelData
              width: (grid.width - grid.spacing) / 2
              modeId: index
              name: root.prettyName(modelData)
              selected: store.mode === modelData
              onClicked: store.setMode(modelData)
            }
          }
        }
      }

      // ---- Color tab ----------------------------------------------------
      Flickable {
        id: colorView
        visible: root.tab === 1
        anchors { top: tabBar.bottom; topMargin: Style.space(12); left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: colorCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height && !wheel.dragging

        Column {
          id: colorCol
          width: colorView.width
          spacing: Style.space(12)

          Row {   // live gradient strip of the active 6 colors
            width: parent.width
            height: Style.space(6)
            Repeater {
              model: 5
              Rectangle {
                required property int index
                width: colorCol.width / 5
                height: parent.height
                gradient: Gradient {
                  orientation: Gradient.Horizontal
                  GradientStop { position: 0; color: themeColors.colors[index] }
                  GradientStop { position: 1; color: themeColors.colors[index + 1] }
                }
              }
            }
          }

          Segmented {
            width: parent.width
            labels: ["Theme", "Custom"]
            current: store.colorMode === "custom" ? 1 : 0
            onPicked: function(i) { store.setColorMode(i === 1 ? "custom" : "theme") }
          }

          Column {   // Theme
            width: parent.width
            spacing: Style.space(8)
            visible: store.colorMode === "theme"
            Text {
              text: themeColors.themeName !== "" ? root.prettyName(themeColors.themeName) : "Active theme"
              color: root.fg
              font.family: Style.font.family
              font.pixelSize: Style.font.subtitle
              font.bold: true
            }
            Text {
              text: "Synced live from your Omarchy theme"
              color: root.mutedFg
              font.family: Style.font.family
              font.pixelSize: Style.font.caption
            }
            Row {
              spacing: Style.space(6)
              Repeater {
                model: themeColors.colors
                Rectangle {
                  required property var modelData
                  width: (colorCol.width - Style.space(6) * 5) / 6
                  height: Style.space(26)
                  radius: root.pill(height)
                  color: modelData
                  border.width: 1
                  border.color: Qt.alpha(root.fg, 0.18)
                }
              }
            }
          }

          Column {   // Custom
            width: parent.width
            spacing: Style.space(12)
            visible: store.colorMode === "custom"

            Item {
              width: parent.width
              height: Style.space(160)
              Rectangle {   // crisp ring behind the wheel
                anchors.centerIn: parent
                width: Style.space(156); height: width; radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Qt.alpha(root.fg, 0.28)
              }
              ColorWheel {
                id: wheel
                anchors.centerIn: parent
                width: Style.space(148); height: width
                hue: root.hue; sat: root.sat; val: root.val
                onPicked: function(h, s) { root.hue = h; root.sat = s; root.commit() }
              }
            }

            Slim {
              width: parent.width
              label: "Brightness"
              from: 0.0; to: 1.0
              value: root.val
              display: Math.round(root.val * 100) + "%"
              onMoved: function(v) { root.val = v; root.commit() }
            }

            Row {
              spacing: Style.space(10)
              Rectangle {   // hex readout pill
                height: Style.space(26)
                width: hexText.implicitWidth + height + Style.space(10)
                radius: root.pill(height)
                color: Qt.alpha(root.fg, 0.08)
                border.width: 1
                border.color: Qt.alpha(root.fg, 0.18)
                Rectangle {
                  x: Style.space(5); anchors.verticalCenter: parent.verticalCenter
                  width: parent.height - Style.space(10); height: width
                  radius: root.pill(height)
                  color: store.customColor
                }
                Text {
                  id: hexText
                  anchors.right: parent.right
                  anchors.rightMargin: Style.space(10)
                  anchors.verticalCenter: parent.verticalCenter
                  text: store.customColor.toUpperCase()
                  color: root.fg
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                }
              }
              Repeater {   // preset dots
                model: ["#00ff41", "#ff3b5c", "#ff9f1c", "#2ec4b6", "#4ea8ff", "#b565ff"]
                Rectangle {
                  required property var modelData
                  width: Style.space(22); height: width; radius: width / 2
                  anchors.verticalCenter: parent.verticalCenter
                  color: modelData
                  border.width: store.customColor === modelData ? 2 : 1
                  border.color: store.customColor === modelData ? root.fg : Qt.alpha(root.fg, 0.25)
                  MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: store.setCustomColor(parent.modelData) }
                }
              }
            }

            Segmented {
              width: parent.width
              labels: ["Solid", "Harmonized"]
              current: store.customHarmony === "solid" ? 0 : 1
              onPicked: function(i) { store.setCustomHarmony(i === 0 ? "solid" : "harmonized") }
            }
          }
        }
      }

      // ---- Tune tab -----------------------------------------------------
      Flickable {
        id: tuneView
        visible: root.tab === 2
        anchors { top: tabBar.bottom; topMargin: Style.space(12); left: parent.left; right: parent.right; bottom: parent.bottom }
        contentWidth: width
        contentHeight: tuneCol.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Column {
          id: tuneCol
          width: tuneView.width
          spacing: Style.space(14)

          Column {   // Music Sync
            width: parent.width
            spacing: Style.space(10)

            Item {
              width: parent.width
              height: Style.space(24)
              Row {
                anchors.verticalCenter: parent.verticalCenter
                spacing: Style.space(8)
                Item {   // tiny 3-bar indicator (animates only while sync is on and the panel is open)
                  id: eqIcon
                  width: Style.space(16); height: Style.space(14)
                  anchors.verticalCenter: parent.verticalCenter
                  readonly property bool live: store.enabled && store.audioSync && root.opened && root.tab === 2
                  Repeater {
                    model: 3
                    Rectangle {
                      id: bar
                      required property int index
                      width: Style.space(3); radius: root.pill(width)
                      x: index * Style.space(6)
                      anchors.bottom: parent.bottom
                      color: store.audioSync ? root.primary : root.mutedFg
                      height: Style.space(4)
                      SequentialAnimation on height {
                        running: eqIcon.live
                        loops: Animation.Infinite
                        NumberAnimation { to: Style.space(14); duration: 260 + bar.index * 90; easing.type: Easing.InOutSine }
                        NumberAnimation { to: Style.space(4); duration: 300 + bar.index * 70; easing.type: Easing.InOutSine }
                      }
                    }
                  }
                }
                Text {
                  anchors.verticalCenter: parent.verticalCenter
                  text: "Music Sync"
                  color: root.fg
                  font.family: Style.font.family
                  font.pixelSize: Style.font.subtitle
                  font.bold: true
                }
              }
              Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(40); height: Style.space(22)
                radius: root.pill(height)
                color: store.audioSync ? Qt.alpha(root.primary, 0.9) : Qt.alpha(root.fg, 0.16)
                Behavior on color { ColorAnimation { duration: 160 } }
                Rectangle {
                  width: parent.height - Style.space(6); height: width
                  radius: root.pill(height)
                  anchors.verticalCenter: parent.verticalCenter
                  x: store.audioSync ? parent.width - width - Style.space(3) : Style.space(3)
                  color: store.audioSync ? root.popBg : root.fg
                  Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: store.toggleAudio() }
              }
            }

            Slim {
              width: parent.width
              label: "Reactivity"
              from: 0.5; to: 2.5
              value: store.audioSensitivity
              display: store.audioSensitivity.toFixed(1) + "x"
              onMoved: function(v) { store.audioSensitivity = v; store.save() }
            }

            Item {
              width: parent.width
              height: Style.space(24)
              Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "Dim when silent"
                color: root.fg
                font.family: Style.font.family
                font.pixelSize: Style.font.body
              }
              Rectangle {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                width: Style.space(40); height: Style.space(22)
                radius: root.pill(height)
                color: store.audioIdleDim ? Qt.alpha(root.primary, 0.9) : Qt.alpha(root.fg, 0.16)
                Behavior on color { ColorAnimation { duration: 160 } }
                Rectangle {
                  width: parent.height - Style.space(6); height: width
                  radius: root.pill(height)
                  anchors.verticalCenter: parent.verticalCenter
                  x: store.audioIdleDim ? parent.width - width - Style.space(3) : Style.space(3)
                  color: store.audioIdleDim ? root.popBg : root.fg
                  Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                }
                MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { store.audioIdleDim = !store.audioIdleDim; store.save() } }
              }
            }

            Rectangle { width: parent.width; height: 1; color: Qt.alpha(root.fg, 0.1) }
          }

          Slim {
            width: parent.width
            label: "Thickness"
            from: 1; to: 8
            value: store.thickness
            display: store.thickness.toFixed(1) + " px"
            onMoved: function(v) { store.thickness = v; store.save() }
          }
          Slim {
            width: parent.width
            label: "Intensity"
            from: 0.1; to: 2.0
            value: store.intensity
            display: Math.round(store.intensity * 100) + "%"
            onMoved: function(v) { store.intensity = v; store.save() }
          }
          Slim {
            width: parent.width
            label: "Speed"
            from: 0.1; to: 3.0
            value: store.speed
            display: store.speed.toFixed(1) + "x"
            onMoved: function(v) { store.speed = v; store.save() }
          }

          Column {
            width: parent.width
            spacing: Style.space(6)
            Text { text: "Target"; color: root.mutedFg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
            Segmented {
              width: parent.width
              labels: ["Screen", "Active", "Windows", "Both"]
              current: Math.max(0, store.targets.indexOf(store.target))
              onPicked: function(i) { store.setTarget(store.targets[i]) }
            }
          }
          Row {
            width: parent.width
            spacing: Style.space(12)
            Column {
              width: (parent.width - Style.space(12)) / 2
              spacing: Style.space(6)
              Text { text: "Direction"; color: root.mutedFg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Segmented {
                width: parent.width
                labels: ["CW", "CCW"]
                current: store.direction === "ccw" ? 1 : 0
                onPicked: function(i) { store.direction = i === 1 ? "ccw" : "cw"; store.save() }
              }
            }
            Column {
              width: (parent.width - Style.space(12)) / 2
              spacing: Style.space(6)
              Text { text: "FPS"; color: root.mutedFg; font.family: Style.font.family; font.pixelSize: Style.font.caption }
              Segmented {
                width: parent.width
                labels: ["30", "60"]
                current: store.fps <= 30 ? 0 : 1
                onPicked: function(i) { store.fps = i === 0 ? 30 : 60; store.save() }
              }
            }
          }
        }
      }
    }
  }

  // ---- Components -------------------------------------------------------

  // Effect card: its own border is the live shader preview. Only hovered or
  // selected cards animate; the rest are cached once at a fixed timestamp.
  component ModeCard: Item {
    id: card
    property int modeId: 0
    property string name: ""
    property bool selected: false
    signal clicked()
    readonly property bool hot: selected || ma.containsMouse
    height: Style.space(60)
    scale: ma.containsMouse && !selected ? 1.02 : 1.0
    Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }

    Rectangle {
      id: bg
      anchors.fill: parent
      radius: root.soft(Style.space(10))
      color: ma.containsMouse ? Qt.alpha(root.fg, 0.1) : Qt.alpha(root.fg, 0.05)
      Behavior on color { ColorAnimation { duration: 120 } }
    }

    ShaderEffect {
      id: fx
      anchors.fill: parent
      blending: true
      property real time: card.hot ? root.previewTime : 1.8
      property real intensity: Math.min(1.4, store.intensity)
      property real speed: store.speed
      property int mode: card.modeId
      property real dir: store.direction === "ccw" ? -1 : 1
      property vector2d size: Qt.vector2d(width, height)
      property vector4d box: Qt.vector4d(0, 0, width, height)
      property vector4d params: Qt.vector4d(root.soft(Style.space(10)), -1, 7, 2)
      property color pal0: themeColors.colors[0]
      property color pal1: themeColors.colors[1]
      property color pal2: themeColors.colors[2]
      property color pal3: themeColors.colors[3]
      property color pal4: themeColors.colors[4]
      property color pal5: themeColors.colors[5]
      fragmentShader: Qt.resolvedUrl("shaders/edgefx.frag.qsb")
    }
    ShaderEffectSource {
      id: cache
      anchors.fill: parent
      sourceItem: fx
      hideSource: true
      live: card.hot
      onVisibleChanged: if (visible) scheduleUpdate()
    }
    Connections { target: themeColors; function onColorsChanged() { cache.scheduleUpdate() } }
    Connections { target: store; function onModeChanged() { cache.scheduleUpdate() } function onDirectionChanged() { cache.scheduleUpdate() } }
    onHotChanged: if (!hot) Qt.callLater(cache.scheduleUpdate)
    Component.onCompleted: Qt.callLater(cache.scheduleUpdate)

    Rectangle {   // active border
      anchors.fill: parent
      radius: bg.radius
      color: "transparent"
      border.width: card.selected ? 2 : (ma.containsMouse ? 1 : 0)
      border.color: card.selected ? root.fg : Qt.alpha(root.fg, 0.5)
    }

    Rectangle {   // label chip
      anchors.left: parent.left; anchors.bottom: parent.bottom
      anchors.margins: Style.space(9)
      height: lbl.implicitHeight + Style.space(4)
      width: lbl.implicitWidth + Style.space(10)
      radius: root.pill(height)
      color: Qt.alpha(root.popBg, 0.78)
      Text {
        id: lbl
        anchors.centerIn: parent
        text: card.name
        color: root.fg
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }
    }

    Rectangle {   // selected badge
      visible: card.selected
      anchors.right: parent.right; anchors.top: parent.top
      anchors.margins: Style.space(9)
      width: Style.space(14); height: width; radius: width / 2
      color: root.fg
      Text { anchors.centerIn: parent; text: "✓"; color: root.popBg; font.pixelSize: Style.font.caption; font.bold: true }
    }

    MouseArea {
      id: ma
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: card.clicked()
    }
  }

  // Segmented pill control with a sliding active pill.
  component Segmented: Item {
    id: seg
    property var labels: []
    property int current: 0
    signal picked(int i)
    height: Style.space(28)
    readonly property real cell: (width - Style.space(4)) / Math.max(1, labels.length)

    Rectangle {
      anchors.fill: parent
      radius: root.pill(height)
      color: Qt.alpha(root.fg, 0.07)
      border.width: 1
      border.color: Qt.alpha(root.fg, 0.12)
    }
    Rectangle {
      x: Style.space(2) + seg.current * seg.cell
      y: Style.space(2)
      width: seg.cell
      height: parent.height - Style.space(4)
      radius: root.pill(height)
      color: Qt.alpha(root.accent, 0.28)
      border.width: 1
      border.color: Qt.alpha(root.accent, 0.9)
      Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
    }
    Row {
      x: Style.space(2); y: Style.space(2)
      Repeater {
        model: seg.labels
        Item {
          required property int index
          required property var modelData
          width: seg.cell
          height: seg.height - Style.space(4)
          Text {
            anchors.centerIn: parent
            text: parent.modelData
            color: seg.current === parent.index ? root.fg : root.mutedFg
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: seg.current === parent.index
          }
          MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: seg.picked(parent.index) }
        }
      }
    }
  }

  // Slim slider: filled track, round handle, right-aligned live value pill.
  component Slim: Item {
    id: sl
    property string label: ""
    property string display: ""
    property real from: 0
    property real to: 1
    property real value: 0
    signal moved(real v)
    height: Style.space(42)
    readonly property real frac: Math.max(0, Math.min(1, (value - from) / (to - from)))

    Text {
      text: sl.label
      color: root.mutedFg
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
    }
    Rectangle {
      anchors.right: parent.right
      height: Style.space(18)
      width: valueText.implicitWidth + Style.space(14)
      radius: root.pill(height)
      color: Qt.alpha(root.fg, 0.08)
      Text {
        id: valueText
        anchors.centerIn: parent
        text: sl.display
        color: root.fg
        font.family: Style.font.family
        font.pixelSize: Style.font.caption
      }
    }
    Rectangle {
      id: track
      anchors.left: parent.left; anchors.right: parent.right
      anchors.bottom: parent.bottom
      anchors.bottomMargin: Style.space(6)
      height: Style.space(4)
      radius: root.pill(height)
      color: Qt.alpha(root.fg, 0.16)
      Rectangle {
        width: track.width * sl.frac
        height: parent.height
        radius: parent.radius
        color: root.accent
      }
      Rectangle {
        x: track.width * sl.frac - width / 2
        anchors.verticalCenter: parent.verticalCenter
        width: handleMa.pressed ? Style.space(15) : Style.space(13)
        height: width
        radius: width / 2
        color: root.fg
        border.width: 2
        border.color: root.accent
        Behavior on width { NumberAnimation { duration: 90 } }
      }
      MouseArea {
        id: handleMa
        anchors.fill: parent
        anchors.topMargin: -Style.space(10); anchors.bottomMargin: -Style.space(10)
        preventStealing: true
        function setFrom(mx) { sl.moved(sl.from + (sl.to - sl.from) * Math.max(0, Math.min(1, mx / track.width))) }
        onPressed: function(m) { setFrom(m.x) }
        onPositionChanged: function(m) { if (pressed) setFrom(m.x) }
      }
    }
  }
}
