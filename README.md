# EdgeFX for Omarchy

A small Omarchy/Quickshell MVP for animated, theme-aware screen-edge lighting. It now combines the edge-lighting behavior from the reference videos with an optional media-aware ambient display.

## Features

- Click-through Wayland overlay on every active monitor.
- Animated perimeter glow with moving color segments.
- Scene presets: `Rainbow`, `Sunset`, `Ocean`, `Aurora`, `Fire`, `Ambient`, `Pulse`, and `Alert`.
- Interactive circular color wheel and color swatches.
- Brightness/intensity and bloom controls.
- Optional audio synchronization driven by a dependency-light PipeWire/PulseAudio RMS bridge.
- Optional media overlay with album art, track title, artist, lyrics, and clock/date.
- `playerctl` bridge for MPRIS-compatible players.
- Dynamic colors that shift with the active scene and audio level.
- Omarchy IPC controls and bar widget.
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

Right-click the EdgeFX bar icon for the scene/color/brightness/media panel. Left-click toggles the effect.

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
omarchy-shell edgefx setBloom 0.55
omarchy-shell edgefx setDynamicColors true
omarchy-shell edgefx setAudioSync true
omarchy-shell edgefx setMediaMode true
omarchy-shell edgefx pulse
```

## Audio sync

Enable audio sync from the popup or with `setAudioSync true`, then run:

```bash
edgefx-audio-sync
```

The helper reads the default PipeWire/PulseAudio stream through `parec`, computes a smoothed RMS level, and sends it to EdgeFX with `setAudioLevel`. Press `Ctrl-C` to stop it. It does not record or save audio; it only sends a normalized level to the running plugin.

## Media mode

Enable media mode and start the MPRIS bridge:

```bash
omarchy-shell edgefx setMediaMode true
edgefx-media-sync
```

The bridge uses `playerctl` to send the current track title, artist, and artwork URL. For a lyric line, create:

```text
~/.config/omarchy/edgefx/lyrics.txt
```

The file is read periodically and displayed in the optional media overlay. The overlay is disabled by default so the center of the desktop remains unobstructed.

## Event pulses

Start optional workspace/window pulses:

```bash
edgefx-events
```

To run helpers at login, add them to your Hyprland autostart after installation:

```lua
-- ~/.config/hypr/autostart.lua or your existing autostart file
-- exec-once = "edgefx-events"
-- exec-once = "edgefx-audio-sync"
-- exec-once = "edgefx-media-sync"
```

## Reference comparison

The second reference video demonstrates audio-reactive edge lighting, bloom, dynamic colors, album art, track metadata, lyrics, clock/date, and a settings panel. EdgeFX now implements those core behaviors as an optional native Omarchy/Quickshell overlay. It does not yet provide automatic lyric transcription, full-screen player transport controls, or per-notch geometry for every laptop camera cutout.

## License

MIT. See [LICENSE](LICENSE).
