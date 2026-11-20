#!/usr/bin/env python3
"""EdgeFx audio meter: PipeWire output monitor -> "level bass mid treble" lines.

Pure stdlib. Captures mono 16-bit PCM from the default sink monitor with parec
(falls back to pw-cat), splits it with one-pole IIR band filters (bass < 250 Hz,
mid 250-2500 Hz, treble > 2500 Hz), applies a noise gate, slow auto-gain and
attack/decay smoothing, and prints ~33 lines/s of floats in 0.0-1.0.

The capture child dies with this script (SIGTERM/SIGINT/closed pipe/parent exit).
"""
import array
import ctypes
import math
import os
import select
import shutil
import signal
import subprocess
import sys
import time

RATE = 16000
FRAME = 480                      # samples per output line (~30 ms -> ~33 Hz)
GATE = 0.0015                    # below this RMS (about -56 dBFS) counts as silence
ATTACK, DECAY = 0.65, 0.14
PEAK_DECAY, PEAK_FLOOR = 0.996, 0.02

CAPTURE_CMDS = [
    ["parec", "--device=@DEFAULT_MONITOR@", "--format=s16le", "--rate=%d" % RATE,
     "--channels=1", "--latency-msec=20"],
    ["pw-cat", "--record", "-P", "stream.capture.sink=true", "--format", "s16",
     "--rate", str(RATE), "--channels", "1", "--raw", "-"],
]

stop = False
child = None


def _pdeathsig():
    """Ask the kernel to SIGTERM us if our parent dies (best effort)."""
    try:
        ctypes.CDLL(None).prctl(1, signal.SIGTERM)
    except Exception:
        pass


def _on_signal(signum, frame):
    global stop
    stop = True


def kill_child():
    global child
    if child is None:
        return
    try:
        if child.poll() is None:
            child.terminate()
            try:
                child.wait(timeout=1.0)
            except subprocess.TimeoutExpired:
                child.kill()
                child.wait()
    except Exception:
        pass
    child = None


def start_capture():
    """Return a running capture process that yields data, or None."""
    global child
    for cmd in CAPTURE_CMDS:
        if shutil.which(cmd[0]) is None:
            continue
        try:
            child = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL,
                                     stdin=subprocess.DEVNULL, preexec_fn=_pdeathsig)
        except OSError:
            child = None
            continue
        r, _, _ = select.select([child.stdout], [], [], 2.0)
        if r:
            return child
        kill_child()
    return None


def main():
    signal.signal(signal.SIGTERM, _on_signal)
    signal.signal(signal.SIGINT, _on_signal)
    _pdeathsig()

    proc = start_capture()
    if proc is None:
        sys.stderr.write("audio-meter: no working capture tool (parec / pw-cat)\n")
        return 1
    fd = proc.stdout.fileno()

    a1 = 1.0 - math.exp(-2.0 * math.pi * 250.0 / RATE)
    a2 = 1.0 - math.exp(-2.0 * math.pi * 2500.0 / RATE)
    lp1 = lp2 = 0.0
    env = [0.0, 0.0, 0.0, 0.0]
    peak = [PEAK_FLOOR] * 4
    pending = bytearray()
    samples = array.array("h")
    last_data = time.monotonic()

    def emit(bands):
        for i in range(4):
            v = bands[i]
            if v < GATE:
                v = 0.0
            else:
                peak[i] = max(v, peak[i] * PEAK_DECAY, PEAK_FLOOR)
                v = min(1.0, v / peak[i]) ** 0.85
            env[i] += (v - env[i]) * (ATTACK if v > env[i] else DECAY)
        sys.stdout.write("%.3f %.3f %.3f %.3f\n" % tuple(env))
        sys.stdout.flush()

    try:
        while not stop:
            r, _, _ = select.select([fd], [], [], 0.1)
            if not r:
                if time.monotonic() - last_data > 0.15:
                    emit((0.0, 0.0, 0.0, 0.0))        # stalled stream: decay to zero
                continue
            chunk = os.read(fd, 4096)
            if not chunk:
                break                                   # capture child exited
            last_data = time.monotonic()
            pending.extend(chunk)
            usable = len(pending) - (len(pending) % 2)
            if usable < FRAME * 2:
                continue
            while len(pending) >= FRAME * 2 and not stop:
                samples = array.array("h")
                samples.frombytes(bytes(pending[:FRAME * 2]))
                del pending[:FRAME * 2]
                s_all = s_b = s_m = s_t = 0.0
                for x in samples:
                    x /= 32768.0
                    lp1 += a1 * (x - lp1)
                    lp2 += a2 * (x - lp2)
                    b, m, t = lp1, lp2 - lp1, x - lp2
                    s_all += x * x
                    s_b += b * b
                    s_m += m * m
                    s_t += t * t
                n = float(FRAME)
                emit((math.sqrt(s_all / n), math.sqrt(s_b / n) * 1.6,
                      math.sqrt(s_m / n) * 1.6, math.sqrt(s_t / n) * 2.0))
    except (BrokenPipeError, KeyboardInterrupt):
        pass
    finally:
        kill_child()
        try:
            sys.stdout.close()
        except Exception:
            pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
