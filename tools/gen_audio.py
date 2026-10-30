"""Procedural sound design for Driftlands.

    python3 tools/gen_audio.py assets/audio

Writes small mono 16-bit WAVs: one-shot effects, a wind loop, and single-note
instrument samples (pad / bell / pluck / drone) that the in-game generative
music sequencer transposes with pitch_scale.
"""
import os
import sys
import wave

import numpy as np
from scipy import signal

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/audio"
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(7)


def t(dur):
    return np.arange(int(SR * dur)) / SR


def noise(dur):
    return rng.uniform(-1, 1, int(SR * dur))


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], btype="band")
    return signal.lfilter(b, a, x)


def lp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), btype="low")
    return signal.lfilter(b, a, x)


def hp(x, f, order=2):
    b, a = signal.butter(order, f / (SR / 2), btype="high")
    return signal.lfilter(b, a, x)


def env(n, attack, decay_pow=1.0, release=0.0):
    e = np.ones(n)
    a = max(1, int(SR * attack))
    e[:a] = np.linspace(0, 1, a)
    if release > 0:
        r = int(SR * release)
        e[-r:] *= np.linspace(1, 0, r) ** decay_pow
    return e


def expdec(n, rate):
    return np.exp(-np.arange(n) / SR * rate)


def bell(freq, dur, bright=1.0):
    tt = t(dur)
    partials = [(1, 1.0, 2.2), (2.0, 0.5, 3.0), (2.76, 0.35 * bright, 4.5), (5.4, 0.2 * bright, 7), (8.93, 0.1 * bright, 10)]
    x = sum(a * np.sin(2 * np.pi * freq * r * tt) * np.exp(-tt * d) for r, a, d in partials)
    return x * env(len(tt), 0.003)


def pluck(freq, dur):
    n = int(SR * dur)
    p = int(SR / freq)
    buf = rng.uniform(-1, 1, p)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % p]
        buf[i % p] = 0.5 * (buf[i % p] + buf[(i + 1) % p]) * 0.996
    return lp(out, 3000)


def saw(freq, tt):
    return 2 * ((freq * tt) % 1.0) - 1


def reverbish(x, mix=0.3):
    out = x.copy()
    for d, g in [(0.031, 0.5), (0.047, 0.45), (0.071, 0.4), (0.113, 0.33), (0.167, 0.25), (0.229, 0.18)]:
        k = int(SR * d)
        out[k:] += x[:-k] * g * mix
    return out


def add(*xs):
    out = np.zeros(max(len(x) for x in xs))
    for x in xs:
        out[:len(x)] += x
    return out


def save(name, x, peak=0.85):
    x = np.asarray(x, dtype=np.float64)
    m = np.max(np.abs(x)) or 1.0
    x = x / m * peak
    fade = min(len(x), int(SR * 0.005))
    x[-fade:] *= np.linspace(1, 0, fade)
    data = (x * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print("wrote", name, f"{len(x) / SR:.2f}s")


# ---------------------------------------------------------------- movement
for i in range(3):
    n = noise(0.14)
    x = bp(n, 300 + i * 80, 2200 + i * 300) * expdec(len(n), 38) * env(len(n), 0.004)
    save(f"step_grass_{i}", x, 0.5)
    n = noise(0.09)
    click = np.sin(2 * np.pi * (900 + i * 120) * t(0.09)) * expdec(len(n), 90)
    x = (bp(n, 1200, 5000) * 0.6 + click * 0.5) * expdec(len(n), 55)
    save(f"step_stone_{i}", x, 0.5)

n = noise(0.35)
sweep = np.linspace(0, 1, len(n))
x = sum(bp(n, 400 + 1200 * s0, 900 + 2400 * s0) for s0 in (0.2,)) * np.sin(np.pi * sweep) ** 2
save("jump", x, 0.45)

tt = t(0.3)
x = np.sin(2 * np.pi * 70 * tt * (1 - tt)) * expdec(len(tt), 14) + lp(noise(0.3), 600) * expdec(len(tt), 20) * 0.8
save("land", x, 0.7)

n = noise(0.45)
am = np.clip(np.sin(2 * np.pi * 9 * t(0.45)), 0, 1) ** 2 * np.exp(-t(0.45) * 4)
save("glider_open", bp(n, 700, 3500) * am, 0.6)

# seamless wind loop: filtered noise, crossfaded ends
L = 6.0
n = noise(L + 1.0)
w = lp(n, 500, 2) * 0.8 + bp(n, 600, 1800) * 0.25
mod = 0.7 + 0.3 * np.sin(2 * np.pi * t(L + 1.0) / 3.0)
w *= mod
k = int(SR * 1.0)
body = w[:int(SR * L)].copy()
body[:k] = body[:k] * np.linspace(0, 1, k) + w[int(SR * L):int(SR * L) + k] * np.linspace(1, 0, k)
save("wind_loop", body, 0.6)

# ---------------------------------------------------------------- pickups / world
save("shard_chime", reverbish(add(bell(1046.5, 2.5), 0.6 * bell(1568, 2.0))), 0.7)
arp = np.zeros(int(SR * 3.2))
for i, f in enumerate([587.3, 740.0, 880.0, 1174.7]):
    s = int(SR * 0.16 * i)
    b = bell(f, 2.6)
    arp[s:s + len(b)] += b[:len(arp) - s]
save("collect", reverbish(arp, 0.5), 0.75)

tt = t(7.0)
chord = sum(lp(saw(f, tt) + saw(f * 1.004, tt), 1800) for f in (146.8, 220.0, 293.7, 370.0, 440.0))
shimmer = sum(np.sin(2 * np.pi * f * tt) for f in (1174.7, 1480.0, 1760.0)) * (0.5 + 0.5 * np.sin(2 * np.pi * 6 * tt))
x = chord * np.clip(tt / 3.0, 0, 1) ** 2 * np.clip((7.0 - tt) / 2.0, 0, 1) + shimmer * 0.15 * np.clip((tt - 2) / 3, 0, 1) * np.clip((7.0 - tt) / 2.0, 0, 1)
save("beacon", reverbish(x, 0.5), 0.8)

n = noise(0.7)
tt = t(0.7)
x = bp(n, 500, 4000) * np.sin(np.pi * tt / 0.7) ** 1.5 + 0.4 * np.sin(2 * np.pi * (300 + 900 * tt) * tt) * np.exp(-tt * 3)
save("boost", x, 0.6)

tt = t(0.9)
x = np.sin(2 * np.pi * 60 * tt) * np.exp(-tt * 12) * 1.2 + 0.5 * np.sin(2 * np.pi * (200 + 700 * tt ** 0.7) * tt) * np.exp(-tt * 2.5) + bp(noise(0.9), 300, 2500) * np.exp(-tt * 5) * 0.6
save("launch", x, 0.7)

tt = t(0.45)
x = np.tanh(3 * np.sin(2 * np.pi * 90 * tt * (1 - 0.5 * tt))) * np.exp(-tt * 8) + 0.3 * (np.sin(2 * np.pi * 311 * tt) + np.sin(2 * np.pi * 330 * tt)) * np.exp(-tt * 6)
save("hurt", x, 0.7)

tt = t(0.5)
x = bp(noise(0.5), 200, 1500) * np.exp(-tt * 30) + 0.4 * np.sin(2 * np.pi * 523 * tt) * np.exp(-tt * 6) * env(len(tt), 0.02)
save("plate_on", reverbish(x), 0.6)
x = bp(noise(0.4), 200, 1200) * np.exp(-tt[:len(t(0.4))] * 30)
save("plate_off", x, 0.5)

save("gate", reverbish(add(bell(1318.5, 1.2, 0.6), bell(1975.5, 1.0, 0.4) * 0.5)), 0.6)
g = np.concatenate([bell(659.3, 0.35, 0.3)[:int(SR * 0.25)], bell(523.3, 0.8, 0.3)])
save("gate_fail", g, 0.55)

tt = t(1.8)
x = sum(np.sin(2 * np.pi * f * (1 + 0.5 * tt) * tt) for f in (523.3, 659.3, 784.0)) * np.sin(np.pi * tt / 1.8) ** 2
x += bp(noise(1.8), 3000, 8000) * np.sin(np.pi * tt / 1.8) * 0.3
save("cage_open", reverbish(x, 0.5), 0.6)

tt = t(0.05)
save("ui_hover", np.sin(2 * np.pi * 1800 * tt) * np.exp(-tt * 120), 0.25)
save("ui_click", pluck(660, 0.4) + 0.3 * bell(1320, 0.4, 0.2), 0.45)

tt = t(0.5)
grind = bp(noise(0.5), 80, 700) * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * tt)) * np.sin(np.pi * tt / 0.5)
save("mirror", grind, 0.6)

tt = t(1.0)
cr = np.zeros(len(tt))
for _ in range(14):
    s = rng.integers(0, int(SR * 0.7))
    k = bp(noise(0.08), 300, 3000) * expdec(int(SR * 0.08), 50)
    cr[s:s + len(k)] += k * rng.uniform(0.3, 1.0)
cr += lp(noise(1.0), 300) * np.exp(-tt * 3) * 0.6
save("crumble", cr, 0.6)

tt = t(0.35)
save("orb_fire", np.sin(2 * np.pi * (900 - 1800 * tt) * tt) * np.exp(-tt * 9) + bp(noise(0.35), 2000, 6000) * np.exp(-tt * 20) * 0.4, 0.5)
tt = t(0.6)
save("orb_hit", lp(noise(0.6), 900) * np.exp(-tt * 9) + np.sin(2 * np.pi * 110 * tt) * np.exp(-tt * 10), 0.6)

tt = t(4.0)
th = lp(noise(4.0), 160, 3) * (np.exp(-tt * 1.0) + 0.5 * np.exp(-((tt - 0.6) ** 2) * 6)) * 2
th += hp(noise(4.0), 2000) * np.exp(-tt * 18) * 0.5
save("thunder", th, 0.9)

tt = t(1.6)
swirl = sum(bell(f, 1.6, 0.5) for f in (784, 988, 1175)) * 0.5 + 0.4 * np.sin(2 * np.pi * (300 + 300 * tt) * tt) * np.sin(np.pi * tt / 1.6)
save("sundial", reverbish(swirl, 0.5), 0.6)

ck = np.zeros(int(SR * 2.0))
for i, f in enumerate([392.0, 493.9, 587.3]):
    b = bell(f, 1.8, 0.5)
    s = int(SR * 0.06 * i)
    ck[s:s + len(b)] += b[:len(ck) - s]
save("checkpoint", reverbish(ck, 0.4), 0.55)

tt = t(1.2)
save("wisp_alert", np.sin(2 * np.pi * (220 + 30 * np.sin(2 * np.pi * 7 * tt)) * tt) * np.sin(np.pi * tt / 1.2) ** 2 * 0.6
     + bp(noise(1.2), 400, 1200) * np.sin(np.pi * tt / 1.2) * 0.3, 0.45)

# ---------------------------------------------------------------- music instruments (all rooted at C)
tt = t(7.0)
pad = sum(lp(saw(130.81 * d, tt), 900, 2) for d in (1.0, 1.003, 0.997, 2.002))
pad *= np.clip(tt / 1.8, 0, 1) ** 1.5 * np.clip((7.0 - tt) / 2.5, 0, 1)
save("mus_pad_c3", pad, 0.6)
save("mus_bell_c5", reverbish(bell(523.25, 3.5, 0.7), 0.4), 0.6)
save("mus_pluck_c4", pluck(261.63, 2.0), 0.6)
tt = t(10.0)
drone = lp(saw(65.41, tt) + saw(65.41 * 1.5, tt) * 0.5 + saw(65.41 * 1.006, tt), 300, 2)
drone *= np.clip(tt / 3.0, 0, 1) * np.clip((10.0 - tt) / 3.0, 0, 1)
save("mus_drone_c2", drone, 0.6)

# ---------------------------------------------------------------- added: bounce / bell / fragment / echo
tt = t(0.6)
save("bounce", np.sin(2 * np.pi * (180 + 520 * tt) * tt) * np.exp(-tt * 5) + 0.3 * lp(noise(0.6), 400) * np.exp(-tt * 20), 0.6)
save("bell_ring", reverbish(add(bell(392.0, 3.5, 1.2), 0.5 * bell(587.3, 3.0, 0.8)), 0.6), 0.75)
save("fragment", reverbish(add(bell(1567.98, 1.4, 0.5), 0.5 * bell(2093.0, 1.0, 0.3)), 0.4), 0.55)
tt = t(1.4)
save("echo", reverbish(sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * 2.5) * (0.5 + 0.5 * np.sin(2 * np.pi * 9 * tt)) for f in (880, 1108.7, 1318.5)), 0.6), 0.5)

# ---------------------------------------------------------------- added: island collapse / lore
tt = t(7.0)
ru = lp(noise(7.0), 90, 3) * 3 + lp(noise(7.0), 300, 2) * 0.4 * (0.5 + 0.5 * np.sin(2 * np.pi * 1.5 * tt))
ru *= 0.65 + 0.35 * np.sin(2 * np.pi * 0.5 * tt)
loop = ru[:SR * 6].copy()
ramp = np.linspace(0, 1, SR)
loop[:SR] = loop[:SR] * ramp + ru[SR * 6:SR * 7] * (1 - ramp)
save("rumble", loop, 0.8)
tt = t(1.6)
save("crack", lp(noise(1.6), 250, 2) * np.exp(-tt * 3) * 2 + hp(noise(1.6), 1500) * np.exp(-tt * 25), 0.8)
save("lore", reverbish(add(bell(659.25, 2.5, 0.4), 0.6 * bell(987.77, 2.2, 0.3), 0.4 * bell(1318.5, 1.8, 0.2)), 0.6), 0.5)
