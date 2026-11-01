# EdgeFX for Omarchy

A small Omarchy/Quickshell MVP for animated, theme-aware screen-edge lighting.

## Features

- Click-through Wayland overlay on every active monitor.
- Four presets: `ambient`, `flow`, `pulse`, and `alert`.
- Moving perimeter energy segment for non-ambient presets.
- Accent color, intensity, speed, and enabled state through Omarchy IPC.
- Bar widget with quick toggle and preset picker.
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

## CLI

```bash
omarchy-shell edgefx status
omarchy-shell edgefx toggle
omarchy-shell edgefx setPreset flow
omarchy-shell edgefx setAccent '#bb9af7'
omarchy-shell edgefx setIntensity 0.45
omarchy-shell edgefx setSpeed 8
omarchy-shell edgefx pulse
```

Start optional event-driven pulses:

```bash
edgefx-events
```

To run it at login, add it to your Hyprland autostart after installation:

```lua
-- ~/.config/hypr/autostart.lua or your existing autostart file
-- exec-once = "edgefx-events"
```

## MVP scope

This version intentionally uses Quickshell `PanelWindow` and `wlr-layer-shell`. The overlay is click-through, so it does not block applications. It provides a stable IPC surface for future audio, notification, battery, cursor, and theme-file integrations.

The current accent defaults to Omarchy's familiar blue. Use the IPC command or bar settings to match the active theme. A future release can read `colors.toml` automatically and add richer shaders without changing the IPC surface.

## License

MIT. See [LICENSE](LICENSE).
