#!/usr/bin/env python3
"""Feed normalized audio RMS levels into the running EdgeFX service."""
import math
import shutil
import struct
import subprocess
import sys
import time

if not shutil.which("parec"):
    print("parec was not found; install pipewire-pulse or pulseaudio", file=sys.stderr)
    raise SystemExit(1)
if not shutil.which("omarchy-shell"):
    print("omarchy-shell was not found; run this on Omarchy", file=sys.stderr)
    raise SystemExit(1)

cmd = [
    "parec", "--format=s16le", "--rate=16000", "--channels=1",
    "--latency-msec=80",
]
proc = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
previous = 0.0
try:
    while True:
        raw = proc.stdout.read(1600)  # about 100 ms at 16 kHz, mono, 16-bit
        if not raw:
            break
        samples = struct.unpack("<%dh" % (len(raw) // 2), raw[: len(raw) // 2 * 2])
        if not samples:
            continue
        rms = math.sqrt(sum(float(sample) ** 2 for sample in samples) / len(samples)) / 32768.0
        level = max(0.0, min(1.0, rms * 4.5))
        # Fast attack, slower release keeps the border musical without flicker.
        level = max(level, previous * 0.72)
        previous = level
        subprocess.run(["omarchy-shell", "edgefx", "setAudioLevel", f"{level:.3f}"], check=False, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(0.04)
except KeyboardInterrupt:
    pass
finally:
    proc.terminate()
