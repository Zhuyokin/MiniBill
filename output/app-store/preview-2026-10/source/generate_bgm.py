#!/usr/bin/env python3
"""Render an original 15-second MiniBill instrumental using Python's standard library."""

from array import array
from math import cos, exp, log10, pi, sin, sqrt
from pathlib import Path
import random
import sys
import wave


RATE = 48_000
BPM = 128
BEAT = 60 / BPM
DURATION = 15.0
FRAMES = int(RATE * DURATION)
TAU = 2 * pi
left = array("d", [0.0]) * FRAMES
right = array("d", [0.0]) * FRAMES
rng = random.Random(20261002)


def frequency(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def mix(start, samples, gain, pan=0.0, echo=False):
    offset = round(start * RATE)
    gl = gain * cos((pan + 1) * pi / 4)
    gr = gain * sin((pan + 1) * pi / 4)
    for i, value in enumerate(samples):
        n = offset + i
        if 0 <= n < FRAMES:
            left[n] += gl * value
            right[n] += gr * value
    if echo:
        # A quiet, short stereo ambience leaves the arrangement close and clear.
        for delay, level, swap in ((0.063, 0.10, True), (0.107, 0.055, False)):
            start_echo = offset + round(delay * RATE)
            el, er = (gr, gl) if swap else (gl, gr)
            for i, value in enumerate(samples):
                n = start_echo + i
                if n < FRAMES:
                    left[n] += el * level * value
                    right[n] += er * level * value


def pitched(midi, seconds, kind):
    f = frequency(midi)
    result = array("d")
    for i in range(round(seconds * RATE)):
        t = i / RATE
        attack = 1 - exp(-t / 0.005)
        release = min(1.0, max(0.0, (seconds - t) / 0.09))
        if kind == "lead":
            value = (sin(TAU * f * t) * exp(-t / 0.30)
                     + 0.20 * sin(TAU * f * 2 * t) * exp(-t / 0.14)
                     + 0.085 * sin(TAU * f * 3.99 * t) * exp(-t / 0.06))
        elif kind == "chord":
            value = (sin(TAU * f * t) * exp(-t / 0.20)
                     + 0.18 * sin(TAU * f * 2 * t) * exp(-t / 0.11)
                     + 0.075 * sin(TAU * f * 3 * t) * exp(-t / 0.08))
        else:
            value = (sin(TAU * f * t) + 0.12 * sin(TAU * f * 2 * t))
            value *= exp(-t / 0.24)
            attack = 1 - exp(-t / 0.011)
        result.append(value * attack * release)
    return result


def note(beat, midi, gain, kind="lead", length=0.9, pan=0.0):
    mix(beat * BEAT, pitched(midi, length, kind), gain, pan, kind != "bass")


def drum(beat, kind, gain, pan=0.0):
    seconds = {"kick": 0.20, "tap": 0.075, "shaker": 0.045}[kind]
    result = array("d")
    low = 0.0
    for i in range(round(seconds * RATE)):
        t = i / RATE
        noise = rng.uniform(-1.0, 1.0)
        low += 0.24 * (noise - low)
        attack = min(1.0, t / 0.0015)
        if kind == "kick":
            phase = TAU * (49 * t + 35 * 0.023 * (1 - exp(-t / 0.023)))
            value = sin(phase) * exp(-t / 0.055)
        elif kind == "tap":
            value = (0.65 * low + 0.24 * sin(TAU * 920 * t)) * exp(-t / 0.012)
        else:
            value = (noise - low) * exp(-t / 0.009) * 0.55
        result.append(value * attack * min(1.0, (seconds - t) / 0.008))
    mix(beat * BEAT, result, gain, pan)


def compose():
    # Cadd9 – Am7 – Fmaj7 – G6, then a tonic cadence.
    chords = [
        (48, [60, 64, 67, 74]),
        (45, [60, 64, 67, 69]),
        (41, [60, 64, 65, 69]),
        (43, [59, 62, 67, 69]),
        (48, [60, 64, 67, 74]),
        (45, [60, 64, 67, 69]),
        (43, [59, 62, 67, 69]),
        (48, [60, 64, 67, 72]),
    ]
    melody = [
        [(0.0, 76), (0.75, 79), (1.5, 81), (2.5, 79), (3.0, 76)],
        [(0.0, 72), (0.75, 76), (1.5, 79), (2.5, 76), (3.0, 74)],
        [(0.0, 72), (0.75, 77), (1.5, 76), (2.5, 72), (3.0, 69)],
        [(0.0, 71), (0.75, 74), (1.5, 79), (2.5, 74), (3.25, 71)],
        [(0.0, 76), (0.75, 79), (1.5, 81), (2.5, 79), (3.0, 76)],
        [(0.0, 72), (0.75, 76), (1.5, 79), (2.5, 81), (3.0, 79)],
        [(0.0, 77), (0.75, 76), (1.5, 74), (2.5, 71), (3.0, 74)],
        [(0.0, 76), (0.75, 74), (1.5, 72)],
    ]
    for bar, (root, tones) in enumerate(chords):
        start = bar * 4
        note(start, root, 0.17, "bass", 0.52)
        if bar < 7:
            note(start + 2, root + (7 if bar in (1, 3, 5) else 0), 0.12, "bass", 0.43)
        for step, index in enumerate((0, 2, 1, 3, 0, 2, 1, 2)):
            if bar == 7 and step >= 4:
                continue
            note(start + step * 0.5, tones[index], 0.051 if step % 2 == 0 else 0.043,
                 "chord", 0.58, -0.40 if step % 2 == 0 else 0.38)
        for index, (offset, midi) in enumerate(melody[bar]):
            note(start + offset, midi, 0.116 if index == 0 else 0.10,
                 length=1.45 if bar == 7 and index == 2 else 0.83, pan=0.08)
        for offset in (0, 2):
            if bar < 7 or offset == 0:
                drum(start + offset, "kick", 0.105)
        if bar < 7:
            for offset in (1, 3):
                drum(start + offset, "tap", 0.056, -0.12)
            for index in range(8):
                drum(start + index * 0.5, "shaker", 0.024 if index % 2 else 0.013, 0.36)
    # The final chord rings through the last bar with a clean, warm resolution.
    for index, midi in enumerate((48, 60, 64, 67)):
        note(29.5 + index * 0.025, midi, 0.047, "chord", 1.7, (index - 1.5) * 0.16)


def render(destination):
    compose()
    peak = max(max(abs(x) for x in left), max(abs(x) for x in right))
    scale = 10 ** (-3.2 / 20) / peak
    pcm = array("h")
    energy = 0.0
    output_peak = 0.0
    for i in range(FRAMES):
        t = i / RATE
        fade = min(1.0, t / 0.012)
        if t > DURATION - 0.38:
            fade *= 0.5 - 0.5 * cos(pi * (DURATION - t) / 0.38)
        for channel in (left, right):
            value = channel[i] * scale * fade
            output_peak = max(output_peak, abs(value))
            energy += value * value
            pcm.append(round(value * 32767))
    if sys.byteorder != "little":
        pcm.byteswap()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(destination), "wb") as output:
        output.setnchannels(2)
        output.setsampwidth(2)
        output.setframerate(RATE)
        output.writeframes(pcm.tobytes())
    rms = sqrt(energy / (2 * FRAMES))
    print(f"{destination}\n{DURATION:.3f} s | {RATE} Hz | stereo | PCM 16-bit")
    print(f"128 BPM | C major | peak {20 * log10(output_peak):.2f} dBFS | RMS {20 * log10(rms):.2f} dBFS")


if __name__ == "__main__":
    target = Path(__file__).resolve().parents[1] / "audio" / "minibill-bgm.wav"
    render(target)
