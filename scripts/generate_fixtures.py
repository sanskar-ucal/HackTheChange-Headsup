#!/usr/bin/env python3
"""Generate synthetic head-pose traces for HeadsUpKit tests.

Mirrors `TraceSynth` in HeadsUpKit/Tests/HeadsUpKitTests/TraceSynth.swift: 25 Hz samples,
sine-shaped nods/shakes, deterministic sinusoidal "noise". Output columns are radians and
radians/second: timestamp,yaw,pitch,roll,pitchRate,yawRate,rollRate

Usage: python scripts/generate_fixtures.py
"""
import math
import os

RATE = 25.0
OUT = os.path.join(os.path.dirname(__file__), "..", "HeadsUpKit", "Tests", "HeadsUpKitTests", "Fixtures")


def nod(start, amplitude=15.0, period=0.6):
    """Down-then-up nod. Returns (value(t), rate(t)) in degrees and deg/s."""
    def value(t):
        u = t - start
        return -amplitude * (1 - math.cos(2 * math.pi * u / period)) / 2 if 0 <= u <= period else 0.0

    def rate(t):
        u = t - start
        return -amplitude * math.pi / period * math.sin(2 * math.pi * u / period) if 0 <= u <= period else 0.0
    return value, rate


def shake(start, amplitude=15.0, period=0.6):
    """Right-left-back shake (one full sine cycle)."""
    def value(t):
        u = t - start
        return amplitude * math.sin(2 * math.pi * u / period) if 0 <= u <= period else 0.0

    def rate(t):
        u = t - start
        return amplitude * 2 * math.pi / period * math.cos(2 * math.pi * u / period) if 0 <= u <= period else 0.0
    return value, rate


def pan(rate_deg):
    return (lambda t: rate_deg * t), (lambda t: rate_deg)


def jitter(angle_amp, rate_amp, seed):
    def value(t):
        return angle_amp * (0.6 * math.sin(91.7 * t + seed) + 0.4 * math.sin(53.3 * t + 2 * seed))

    def rate(t):
        return rate_amp * (0.6 * math.sin(77.1 * t + 3 * seed) + 0.4 * math.cos(41.9 * t + seed))
    return value, rate


def trace(duration, yaw=(), pitch=(), roll=()):
    rows = []
    n = int(round(duration * RATE))
    for i in range(n):
        t = i / RATE
        def total(components, index):
            return sum(c[index](t) for c in components)
        y, p, r = total(yaw, 0), total(pitch, 0), total(roll, 0)
        yr, pr, rr = total(yaw, 1), total(pitch, 1), total(roll, 1)
        rows.append([t, math.radians(y), math.radians(p), math.radians(r),
                     math.radians(pr), math.radians(yr), math.radians(rr)])
    return rows


def noise(seed):
    return jitter(0.05, 2.0, seed)


FIXTURES = {
    "nod": trace(2.0, yaw=[noise(1)], pitch=[nod(0.6), noise(2)], roll=[noise(3)]),
    "shake": trace(2.0, yaw=[shake(0.6), noise(4)], pitch=[noise(5)], roll=[noise(6)]),
    "slow_pan": trace(3.0, yaw=[pan(25.0), noise(7)], pitch=[pan(-8.0), noise(8)], roll=[noise(9)]),
    "jitter": trace(3.0, yaw=[jitter(0.6, 25.0, 10)], pitch=[jitter(0.6, 25.0, 11)], roll=[jitter(0.6, 25.0, 12)]),
    "nod_while_panning": trace(2.4, yaw=[pan(15.0), noise(13)], pitch=[nod(0.8), noise(14)], roll=[noise(15)]),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, rows in FIXTURES.items():
        path = os.path.join(OUT, name + ".csv")
        with open(path, "w", newline="\n") as f:
            f.write("timestamp,yaw,pitch,roll,pitchRate,yawRate,rollRate\n")
            for row in rows:
                f.write(",".join("%.6f" % v for v in row) + "\n")
        print("wrote", os.path.normpath(path), len(rows), "samples")


if __name__ == "__main__":
    main()
