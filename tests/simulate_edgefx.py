#!/usr/bin/env python3
"""Headless visual harness for EdgeFX choreography logic.

This is not a Quickshell replacement. It validates the segment timing and
color choreography without requiring Hyprland or a Wayland compositor.
"""
from __future__ import annotations
import colorsys
import math
import os
import subprocess
from pathlib import Path
from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 960, 540
FPS = 30
SEGMENTS = 24
MODES = ["continuous", "line", "group", "chase", "breathe"]
SECONDS_PER_MODE = 2.4
OUT = Path(__file__).resolve().parent / "edgefx-choreography-preview.mp4"

try:
    FONT = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 20)
    SMALL = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 15)
except OSError:
    FONT = SMALL = ImageFont.load_default()


def rgb(hue: float, sat: float = 0.86, value: float = 1.0):
    return tuple(int(v * 255) for v in colorsys.hsv_to_rgb(hue % 1.0, sat, value))


def perimeter_segments():
    points = []
    inset = 24
    usable_w, usable_h = W - inset * 2, H - inset * 2
    for i in range(SEGMENTS // 4):
        t = i / (SEGMENTS // 4)
        points.append((inset + usable_w * t, inset))
    for i in range(SEGMENTS // 4):
        t = i / (SEGMENTS // 4)
        points.append((W - inset, inset + usable_h * t))
    for i in range(SEGMENTS // 4):
        t = i / (SEGMENTS // 4)
        points.append((W - inset - usable_w * t, H - inset))
    for i in range(SEGMENTS // 4):
        t = i / (SEGMENTS // 4)
        points.append((inset, H - inset - usable_h * t))
    return points


def opacity(mode: str, index: int, phase: float, group_size: int = 4):
    head = int(phase * SEGMENTS) % SEGMENTS
    distance = abs(index - head)
    distance = min(distance, SEGMENTS - distance)
    if mode == "line":
        return 1.0 if distance == 0 else 0.0
    if mode == "group":
        return 1.0 if distance < group_size else 0.0
    if mode == "chase":
        return max(0.0, 1.0 - distance / max(1, group_size * 2))
    if mode == "breathe":
        return 0.35 + 0.65 * abs(math.sin(phase * math.pi * 2))
    return 1.0 if distance < 2 else 0.18


def render(mode: str, frame: int):
    phase = (frame % int(SECONDS_PER_MODE * FPS)) / (SECONDS_PER_MODE * FPS)
    audio = 0.5 + 0.5 * math.sin(frame * 0.34)
    base = Image.new("RGBA", (W, H), (8, 10, 18, 255))
    draw = ImageDraw.Draw(base)
    # Quiet center area makes the perimeter motion easy to see.
    draw.rounded_rectangle((110, 100, W - 110, H - 100), radius=26, fill=(15, 19, 31), outline=(36, 43, 63), width=2)
    draw.text((28, 28), f"EdgeFX headless simulation  ·  {mode.upper()}", font=FONT, fill=(225, 232, 255))
    draw.text((28, H - 48), "segment choreography · audio level %.2f · 24 segments" % audio, font=SMALL, fill=(128, 145, 180))

    points = perimeter_segments()
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i, (x, y) in enumerate(points):
        next_x, next_y = points[(i + 1) % len(points)]
        alpha = int(255 * opacity(mode, i, phase) * (0.65 + audio * 0.35))
        color = rgb(i / SEGMENTS + phase * 0.35 + audio * 0.1, 0.82, 1.0)
        c = (*color, alpha)
        sx, sy = x + (next_x - x) * 0.07, y + (next_y - y) * 0.07
        ex, ey = next_x - (next_x - x) * 0.07, next_y - (next_y - y) * 0.07
        gd.line((sx, sy, ex, ey), fill=c, width=10)
    glow = glow.filter(ImageFilter.GaussianBlur(18))
    base = Image.alpha_composite(base, glow)

    segments_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    draw = ImageDraw.Draw(segments_layer)
    for i, (x, y) in enumerate(points):
        next_x, next_y = points[(i + 1) % len(points)]
        alpha = int(255 * opacity(mode, i, phase) * (0.72 + audio * 0.28))
        color = rgb(i / SEGMENTS + phase * 0.35 + audio * 0.1, 0.82, 1.0)
        sx, sy = x + (next_x - x) * 0.07, y + (next_y - y) * 0.07
        ex, ey = next_x - (next_x - x) * 0.07, next_y - (next_y - y) * 0.07
        draw.line((sx, sy, ex, ey), fill=(*color, alpha), width=5)
    return Image.alpha_composite(base, segments_layer).convert("RGB")


def main():
    OUT.parent.mkdir(parents=True, exist_ok=True)
    frames = OUT.parent / "frames"
    frames.mkdir(exist_ok=True)
    for old in frames.glob("*.png"):
        old.unlink()
    frame_no = 0
    for mode in MODES:
        for _ in range(int(SECONDS_PER_MODE * FPS)):
            render(mode, frame_no).save(frames / f"frame-{frame_no:04d}.png")
            frame_no += 1
    subprocess.run([
        "ffmpeg", "-y", "-loglevel", "error", "-framerate", str(FPS),
        "-i", str(frames / "frame-%04d.png"), "-c:v", "libx264", "-pix_fmt", "yuv420p", str(OUT)
    ], check=True)
    for old in frames.glob("*.png"):
        old.unlink()
    frames.rmdir()
    print(OUT)


if __name__ == "__main__":
    main()
