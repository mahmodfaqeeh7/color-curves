"""Generates the game's two ambient music loops (original, procedural).

    python3 tools/make_music.py      -> assets/audio/music_menu.ogg, music_play.ogg

Calm pads over a slow 4-chord progression, sparse pentatonic bell plucks and a
soft reverb. The reverb tail is wrapped to the start, so each file loops with
no seam. Mono, 22.05 kHz, Ogg Vorbis: small files for a small app.
"""
import os
import subprocess
import tempfile
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio")


def midi_hz(m):
    return 440.0 * 2 ** ((m - 69) / 12.0)


def pad(notes, dur, attack=1.2, release=1.4):
    """Soft pad: two slightly detuned sines + an octave-up whisper per note."""
    t = np.arange(int(dur * SR)) / SR
    sig = np.zeros_like(t)
    for m in notes:
        f = midi_hz(m)
        sig += np.sin(2 * np.pi * f * t) + np.sin(2 * np.pi * f * 1.003 * t + 1.3)
        sig += 0.18 * np.sin(2 * np.pi * f * 2.0 * t + 0.4)
    env = np.minimum(1.0, t / attack) * np.minimum(1.0, (dur - t) / release)
    env = np.clip(env, 0.0, 1.0) ** 1.5
    return sig * env / (len(notes) * 2.2)


def pluck(m, dur=2.4):
    """Bell-like pluck: sine plus a soft inharmonic partial, fast decay."""
    t = np.arange(int(dur * SR)) / SR
    f = midi_hz(m)
    env = np.exp(-t * 2.6) * np.minimum(1.0, t / 0.004)
    return env * (np.sin(2 * np.pi * f * t) + 0.25 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 4))


def reverb(x, seconds=2.6, mix=0.32, seed=7):
    rng = np.random.default_rng(seed)
    n = int(seconds * SR)
    ir = rng.standard_normal(n) * np.exp(-np.arange(n) / SR * (6.9 / seconds))
    ir[: int(0.012 * SR)] = 0.0
    size = 1 << int(np.ceil(np.log2(len(x) + n)))
    wet = np.fft.irfft(np.fft.rfft(x, size) * np.fft.rfft(ir, size), size)[: len(x) + n]
    wet /= np.max(np.abs(wet)) + 1e-9
    dry = np.concatenate([x, np.zeros(n)])
    dry /= np.max(np.abs(dry)) + 1e-9
    return (1 - mix) * dry + mix * wet


def lowpass(x, cutoff):
    a = np.exp(-2 * np.pi * cutoff / SR)
    y = np.empty_like(x)
    acc = 0.0
    for i, v in enumerate(x):   # one-pole, short enough to stay fast
        acc = (1 - a) * v + a * acc
        y[i] = acc
    return y


def song(chords, bar_s, bars_per_chord, scale, pluck_prob, pluck_gain, seed, pad_cut):
    rng = np.random.default_rng(seed)
    chord_s = bar_s * bars_per_chord
    total = int(chord_s * len(chords) * SR)
    mix = np.zeros(total + int(4 * SR))
    for i, ch in enumerate(chords):
        start = int(i * chord_s * SR - 0.6 * SR)   # overlap for smooth changes
        p = pad(ch, chord_s + 1.2)
        s0 = max(0, start)
        mix[s0:s0 + len(p) - (s0 - start)] += p[s0 - start:]
        if start < 0:   # wrap the first chord's pre-roll to the end (loop)
            mix[total + start:total] += p[: -start]
    mix = lowpass(mix, pad_cut)
    eighth = bar_s / 8.0
    for k in range(int(total / SR / eighth)):
        if rng.random() < pluck_prob:
            m = int(rng.choice(scale))
            pl = pluck(m) * pluck_gain * (0.7 + 0.3 * rng.random())
            s = int(k * eighth * SR)
            mix[s:s + len(pl)] += pl[: len(mix) - s]
    wet = reverb(mix[:total + int(2.4 * SR)])
    loop = wet[:total].copy()
    tail = wet[total:]
    loop[: len(tail)] += tail   # seamless loop: tail rings into the start
    loop /= np.max(np.abs(loop)) + 1e-9
    return loop * 0.5   # about -6 dBFS peak; the Music bus sets the level


def write_ogg(name, x):
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, "m.wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes())
        out = os.path.join(OUT, name)
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "1", out], check=True)
    print(name, os.path.getsize(out) // 1024, "KB", round(len(x) / SR, 1), "s")


if __name__ == "__main__":
    # Menu: D major, warm and a little brighter, more plucks.
    D = [[50, 57, 62, 66, 69], [47, 54, 59, 62, 66], [43, 50, 55, 59, 62], [45, 52, 57, 61, 64]]
    write_ogg("music_menu.ogg", song(D, bar_s=60 / 68 * 4, bars_per_chord=2,
                                     scale=[74, 76, 78, 81, 83, 86], pluck_prob=0.22, pluck_gain=0.30,
                                     seed=11, pad_cut=1400))
    # Play: G major, softer and sparser so it never competes with thinking.
    G = [[43, 50, 55, 59, 62], [40, 47, 52, 55, 59], [36, 43, 48, 52, 55], [38, 45, 50, 54, 57]]
    write_ogg("music_play.ogg", song(G, bar_s=60 / 60 * 4, bars_per_chord=2,
                                     scale=[67, 69, 71, 74, 76, 79], pluck_prob=0.10, pluck_gain=0.22,
                                     seed=23, pad_cut=1000))
