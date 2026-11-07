#!/usr/bin/env python3
"""程序合成音效与 BGM（无版权问题）。输出 22.05kHz 单声道 16bit WAV。"""
import math, random, struct, wave, os

SR = 22050
OUT = "assets/sfx"

def write(name, samples):
    data = b"".join(struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)

def env(i, n, a=0.01, d=3.0):
    t = i / n
    attack = min(1.0, t / a) if a > 0 else 1.0
    return attack * math.exp(-d * t)

def noise():
    return random.uniform(-1, 1)

def hit():
    n = int(SR * 0.22); out = []
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.002, 6.0)
        low = math.sin(2 * math.pi * (90 - 40 * t) * t)
        out.append((0.5 * noise() + 0.8 * low) * e * 0.7)
    return out

def block():
    n = int(SR * 0.2); out = []
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.001, 9.0)
        s = math.sin(2 * math.pi * 1180 * t) + 0.6 * math.sin(2 * math.pi * 1760 * t)
        out.append((0.45 * s + 0.15 * noise()) * e * 0.6)
    return out

def card():
    n = int(SR * 0.16); out = []
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.004, 7.0)
        f = 420 + 1500 * (t / 0.16)
        out.append(math.sin(2 * math.pi * f * t) * e * 0.25 + noise() * e * 0.06)
    return out

def draw():
    n = int(SR * 0.09); out = []
    for i in range(n):
        t = i / SR
        out.append(math.sin(2 * math.pi * 2100 * t) * env(i, n, 0.001, 20.0) * 0.18)
    return out

def heal():
    n = int(SR * 0.45); out = []
    for i in range(n):
        t = i / SR
        e = env(i, n, 0.02, 4.0)
        f = 523 + 523 * (t / 0.45)
        out.append((math.sin(2 * math.pi * f * t) * 0.4 + math.sin(2 * math.pi * f * 2 * t) * 0.15) * e * 0.5)
    return out

def arp(freqs, step, decay):
    n = int(SR * step * len(freqs)); out = []
    for i in range(n):
        t = i / SR
        k = min(len(freqs) - 1, int(t / step))
        lt = t - k * step
        e = math.exp(-decay * lt)
        out.append(math.sin(2 * math.pi * freqs[k] * t) * e * 0.3)
    return out

def bgm(seconds=24):
    n = int(SR * seconds); out = []
    random.seed(7)
    for i in range(n):
        t = i / SR
        lfo = 0.5 + 0.5 * math.sin(2 * math.pi * 0.05 * t)
        drone = math.sin(2 * math.pi * 55 * t) * 0.30 + math.sin(2 * math.pi * 82.5 * t) * 0.18
        pad = math.sin(2 * math.pi * 110 * t + 0.4 * math.sin(2 * math.pi * 0.08 * t)) * 0.12 * lfo
        bell = 0.0
        phase = t % 6.0
        if phase < 1.6:
            bell = math.sin(2 * math.pi * 440 * t) * math.exp(-3.0 * phase) * 0.10
        out.append((drone + pad + bell) * 0.5)
    return out

random.seed(11)
write("hit", hit())
write("block", block())
write("card", card())
write("draw", draw())
write("heal", heal())
write("win", arp([523.25, 659.25, 783.99, 1046.5], 0.14, 4.0))
write("lose", arp([392.0, 311.1, 233.1], 0.22, 2.5))
write("bgm", bgm())
print("sfx written:", sorted(os.listdir(OUT)))
