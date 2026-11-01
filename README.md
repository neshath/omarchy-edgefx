# EdgeFX for Omarchy

A small Omarchy/Quickshell MVP for animated, theme-aware screen-edge lighting. It is inspired by the attached Edgy-style reference: a soft perimeter glow, selectable scenes, color controls, brightness, and beat-reactive intensity.

## Features

- Click-through Wayland overlay on every active monitor.
- Animated perimeter glow with moving color segments.
- Scene presets: `Rainbow`, `Sunset`, `Ocean`, `Aurora`, `Fire`, `Ambient`, `Pulse`, and `Alert`.
- Color swatches for quickly changing the accent in the popup.
- Brightness/intensity slider.
- Optional audio synchronization driven by a dependency-light PipeWire/PulseAudio RMS bridge.
- Omarchy IPC controls and bar widget with quick toggle and scene picker.
- Optional Hyprland event bridge for workspace/window-change pulses.
- No changes to `/usr/share/omarchy`.

## Install

From a local checkout:

```bash
bash install.sh
```

Or directly after publishing:

```bash
omarchy plugin add https://github.com/neshath/omarchy-edgefx.git --enable
```

The plugin is intentionally unsandboxed like other Omarchy plugins. Inspect the source before enabling it.

## Controls

Right-click the EdgeFX bar icon for the scene/color/brightness panel. Left-click toggles the effect.

```bash
omarchy-shell edgefx status
omarchy-shell edgefx toggle
omarchy-shell edgefx setPreset rainbow
omarchy-shell edgefx setPreset sunset
omarchy-shell edgefx setPreset ocean
omarchy-shell edgefx setPreset aurora
omarchy-shell edgefx setPreset fire
omarchy-shell edgefx setAccent '#bb9af7'
omarchy-shell edgefx setIntensity 0.45
omarchy-shell edgefx setSpeed 8
omarchy-shell edgefx setAudioSync true
omarchy-shell edgefx pulse
```

## Audio sync

Enable audio sync from the popup or with `setAudioSync true`, then run:

```bash
edgefx-audio-sync
```

The helper reads the default PipeWire/PulseAudio stream through `parec`, computes a smoothed RMS level, and sends it to EdgeFX with `setAudioLevel`. Press `Ctrl-C` to stop it. It does not record or save audio; it only sends a normalized level to the running plugin.

## Event pulses

Start optional workspace/window pulses:

```bash
edgefx-events
```

To run it at login, add it to your Hyprland autostart after installation:

```lua
-- ~/.config/hypr/autostart.lua or your existing autostart file
-- exec-once = "edgefx-events"
```

## Reference comparison

The reference video demonstrates a colored perimeter glow, scene presets, manual color selection, brightness, and audio-synchronized pulsing. This MVP now implements those behaviors as a native Omarchy/Quickshell overlay. It does not yet include a full circular color wheel, ambient screen-content sampling, camera-notch geometry, or a dedicated settings application; those are planned follow-ups.

## License

MIT. See [LICENSE](LICENSE).
