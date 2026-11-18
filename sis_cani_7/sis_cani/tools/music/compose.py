# -*- coding: utf-8 -*-
"""SİS ÇANI açılış müzikleri (tamamen sentez, telifsiz).
python3 tools/music/compose.py  →  audio/music/studio.ogg, intro.ogg, menu.ogg
Tema: Re minör, gece ninnisi gibi bir piyano/müzik kutusu ezgisi, pad, çan."""
import os, subprocess, numpy as np
from scipy.signal import lfilter

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
OUT = os.path.join(ROOT, "audio", "music")
rng = np.random.default_rng(1977)

NOTE = {"C": -9, "C#": -8, "Db": -8, "D": -7, "D#": -6, "Eb": -6, "E": -5, "F": -4, "F#": -3,
        "Gb": -3, "G": -2, "G#": -1, "Ab": -1, "A": 0, "A#": 1, "Bb": 1, "B": 2}


def hz(n):
    name, octv = n[:-1], int(n[-1])
    return 440.0 * 2 ** ((NOTE[name] + 12 * (octv - 4)) / 12.0)


def buf(sec):
    return np.zeros((int(sec * SR), 2))


def place(b, sig, t, pan=0.0, gain=1.0):
    i = max(0, int(t * SR))
    if i >= len(b):
        return
    n = min(len(sig), len(b) - i)
    l = np.cos((pan + 1) * np.pi / 4) * gain
    r = np.sin((pan + 1) * np.pi / 4) * gain
    b[i:i + n, 0] += sig[:n] * l
    b[i:i + n, 1] += sig[:n] * r


def env_adsr(n, a, rel):
    e = np.ones(n)
    na, nr = int(a * SR), int(rel * SR)
    if na:
        e[:na] = np.linspace(0, 1, na) ** 1.5
    if nr:
        e[-nr:] *= np.linspace(1, 0, nr) ** 2
    return e


# ----------------------------------------------------------------- sesler
def piano(f, dur, vel=1.0, bright=1.0):
    """Yumuşak piyano: hafif inharmonik, kısmi seslere göre sönen."""
    tail = 2.6
    n = int((dur + tail) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    B = 0.00035
    for k in range(1, 10):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > 9000:
            break
        amp = (1.0 / k ** (1.45 - 0.25 * bright)) * (1.0 if k == 1 else 0.8)
        tau = 2.4 / (1 + 0.55 * k)
        s += amp * np.sin(2 * np.pi * fk * t + rng.uniform(0, 6.28)) * np.exp(-t / tau)
    # tuşu bırakma: süre sonunda yumuşak sönüm
    rel = np.ones(n)
    k0 = int(dur * SR)
    rel[k0:] = np.exp(-(t[k0:] - dur) / 0.35)
    att = np.minimum(1, t / 0.006)
    hammer = rng.normal(0, 1, n) * np.exp(-t / 0.012) * 0.04
    return (s * rel * att + hammer) * vel * 0.32


def musicbox(f, vel=1.0):
    n = int(3.0 * SR)
    t = np.arange(n) / SR
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t / 1.1)
         + 0.35 * np.sin(2 * np.pi * f * 3.01 * t) * np.exp(-t / 0.35)
         + 0.18 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t / 0.12))
    return s * np.minimum(1, t / 0.002) * vel * 0.16


def pad(freqs, dur, a=1.8, rel=2.5, bright=0.6, vol=1.0):
    n = int((dur + rel) * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for f in freqs:
        for det in (-0.11, 0.0, 0.13):           # cent kaydırmalı üç ses (koro)
            fd = f * 2 ** (det / 12)
            ph = rng.uniform(0, 6.28)
            for k in range(1, 9):
                if f * k > 5000:
                    break
                s += np.sin(2 * np.pi * fd * k * t + ph * k) / k ** (2.2 - bright)
    trem = 1 + 0.08 * np.sin(2 * np.pi * 0.23 * t)
    e = env_adsr(n, a, rel)
    return s * e * trem * vol * 0.03 / max(1, len(freqs))


def cello(f, dur, vol=1.0):
    n = int((dur + 1.2) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.minimum(1, t / 0.8)
    ph = 2 * np.pi * f * np.cumsum(vib) / SR
    s = sum(np.sin(k * ph) / k ** 1.3 for k in range(1, 8))
    return s * env_adsr(n, 0.45, 1.2) * vol * 0.09


def bell(f, vol=1.0, length=7.0):
    """Kilise/fener çanı: minör üçlü 'hum' kısmi sesli."""
    n = int(length * SR)
    t = np.arange(n) / SR
    parts = [(0.5, 1.0, 4.5), (1.0, 0.8, 3.5), (1.19, 0.55, 2.8), (1.5, 0.35, 2.2), (2.0, 0.4, 1.8),
             (2.51, 0.25, 1.2), (2.66, 0.2, 1.0), (3.01, 0.15, 0.8), (4.1, 0.1, 0.5)]
    s = np.zeros(n)
    for r, a, tau in parts:
        beat = 1 + 0.15 * np.sin(2 * np.pi * (0.7 + r * 0.3) * t)   # çan titreşimi
        s += a * np.sin(2 * np.pi * f * r * t + rng.uniform(0, 6)) * np.exp(-t / tau) * beat
    strike = rng.normal(0, 1, n) * np.exp(-t / 0.008) * 0.3
    return (s + strike) * np.minimum(1, t / 0.002) * vol * 0.22


def boom(vol=1.0):
    n = int(3.5 * SR)
    t = np.arange(n) / SR
    f = 30 + 30 * np.exp(-t / 0.4)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 1.3)
    nz = lfilter([0.02], [1, -0.98], rng.normal(0, 1, n)) * np.exp(-t / 0.9)
    return (s * 0.9 + nz * 0.6) * np.minimum(1, t / 0.01) * vol * 0.5


def shimmer(dur=1.4, vol=1.0):
    """Işık şeridi geçerken yükselen parıltı (hızlı yüksek arpej)."""
    b = np.zeros(int((dur + 2.5) * SR))
    notes = ["D6", "F6", "A6", "C7", "D7", "F7", "A7"]
    for i, nn in enumerate(notes):
        sig = musicbox(hz(nn), 0.5)
        k = int(i * dur / len(notes) * SR)
        b[k:k + len(sig)] += sig[:len(b) - k]
    return b * vol


# ----------------------------------------------------------------- reverb
def reverb(x, size=1.0, damp=0.3, wet=0.35):
    out = np.zeros_like(x)
    for ch in range(2):
        sig = x[:, ch]
        acc = np.zeros(len(sig))
        for d, g in ((1557, 0.84), (1617, 0.83), (1491, 0.82), (1422, 0.81), (1277, 0.8), (1356, 0.82)):
            D = int(d * size) + ch * 23
            a = np.zeros(D + 1); a[0] = 1; a[D] = -g
            y = lfilter([1], a, sig)
            acc += lfilter([1 - damp], [1, -damp], y)
        acc /= 6
        for d, g in ((225, 0.5), (556, 0.5), (441, 0.5), (341, 0.5)):
            D = d + ch * 11
            bb = np.zeros(D + 1); bb[0] = -g; bb[D] = 1
            aa = np.zeros(D + 1); aa[0] = 1; aa[D] = -g
            acc = lfilter(bb, aa, acc)
        out[:, ch] = acc
    return x * (1 - wet * 0.5) + out * wet


def master(b, fade_in=0.0, fade_out=0.0, peak=0.8):
    if fade_in:
        k = int(fade_in * SR); b[:k] *= np.linspace(0, 1, k)[:, None]
    if fade_out:
        k = int(fade_out * SR); b[-k:] *= np.linspace(1, 0, k)[:, None] ** 2
    b = np.tanh(b * 1.2) / 1.2                          # yumuşak sınırlayıcı
    return b * (peak / max(1e-6, np.abs(b).max()))


def write(b, name):
    os.makedirs(OUT, exist_ok=True)
    wav = "/tmp/_%s.wav" % name
    import wave
    data = (np.clip(b, -1, 1) * 32767).astype("<i2")
    with wave.open(wav, "wb") as w:
        w.setnchannels(2); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data.tobytes())
    out = os.path.join(OUT, name + ".ogg")
    subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", out], check=True)
    print(out, "%.1fs" % (len(b) / SR))


# ----------------------------------------------------------------- tema
# (nota, vuruş) — 4/4, ninni gibi
THEME_A = [("A4", 1), ("D5", 1), ("E5", .5), ("F5", 1.5), ("E5", 1), ("D5", 1), ("C5", 1), ("A4", 1),
           ("Bb4", 1), ("A4", 1), ("G4", 1), ("F4", .5), ("G4", .5), ("A4", 3), (None, 1)]
THEME_B = [("A4", 1), ("D5", 1), ("E5", .5), ("F5", 1.5), ("G5", 1), ("F5", 1), ("E5", 1), ("D5", 1),
           ("C5", 1), ("Bb4", 1), ("A4", 1), ("E4", 1), ("D4", 3), (None, 1)]
CHORDS_A = [["D3", "A3", "F4"], ["C3", "G3", "E4"], ["Bb2", "F3", "D4"], ["A2", "E3", "C#4"]]
CHORDS_B = [["D3", "A3", "F4"], ["G2", "D3", "Bb3"], ["C3", "G3", "E4"], ["D3", "A3", "D4"]]


def melody(b, notes, t0, beat, inst="piano", vel=1.0, pan=0.15, octave=0):
    t = t0
    for nn, d in notes:
        if nn:
            f = hz(nn) * 2 ** octave
            hum = rng.uniform(-0.012, 0.012)                 # insan eli: hafif zaman oynaması
            v = vel * rng.uniform(0.85, 1.0)
            sig = piano(f, d * beat * 0.95, v) if inst == "piano" else musicbox(f, v)
            place(b, sig, t + hum, pan)
        t += d * beat
    return t


def chords(b, prog, t0, beat, vol=1.0, bass=True):
    for i, ch in enumerate(prog):
        t = t0 + i * 4 * beat
        place(b, pad([hz(n) for n in ch], 4 * beat, 1.2, 1.8, vol=vol), t, 0.0)
        if bass:
            place(b, cello(hz(ch[0]), 4 * beat * 0.98, 0.9 * vol), t, -0.25)


def studio():
    """NexDrive Game Studio logosu (5.5 sn): pad kabarır, logo belirirken çan arpeji, şeritle parıltı."""
    b = buf(8.0)
    place(b, pad([hz("D3"), hz("A3"), hz("D4"), hz("F4")], 4.6, 1.2, 2.2, bright=0.8, vol=1.2), 0.0)
    place(b, cello(hz("D2"), 4.4, 1.0), 0.2, -0.2)
    for i, nn in enumerate(["D5", "F5", "A5", "D6"]):
        place(b, musicbox(hz(nn), 1.2 - i * 0.1), 0.55 + i * 0.16, -0.3 + i * 0.2)
    place(b, bell(hz("D4"), 0.35, 6.0), 0.55, 0.0)
    place(b, shimmer(1.0, 0.9), 1.85, 0.25)
    b = reverb(b, 1.2, 0.35, 0.5)
    return master(b[: int(6.6 * SR)], 0.0, 1.4, 0.75)


def intro():
    """Başlık introsu (~12.5 sn), sahneyle eşli:
    0.0 sisli pad · 2.2 şimşek vuruşu · 3.4 fener yanar + büyük çan · 4.2 başlık · tema · 11.2 kararma."""
    beat = 0.75
    b = buf(16.0)
    place(b, pad([hz("D3"), hz("A3"), hz("C4")], 3.6, 2.2, 1.0, bright=0.4, vol=0.9), 0.0)
    place(b, cello(hz("D2"), 3.2, 0.8), 0.3, -0.2)
    place(b, boom(1.0), 2.2)
    place(b, bell(hz("D3"), 1.0, 9.0), 3.4, 0.0)
    place(b, bell(hz("D4"), 0.3, 6.0), 3.42, 0.3)
    t0 = 3.4 + beat
    chords(b, CHORDS_A[:2], t0, beat, 1.0)
    melody(b, THEME_A[:8], t0, beat, "piano", 1.0)
    t1 = t0 + 8 * beat
    # çözülme: Re minör tutulur, müzik kutusu yankısı
    place(b, pad([hz("D3"), hz("A3"), hz("D4"), hz("F4")], 3.2, 0.8, 2.6, vol=1.0), t1)
    place(b, cello(hz("D2"), 3.0, 0.9), t1, -0.2)
    place(b, piano(hz("D5"), 2.6, 0.9), t1, 0.15)
    place(b, piano(hz("A4"), 2.6, 0.5), t1 + 0.02, -0.1)
    for i, nn in enumerate(["F5", "A5", "D6"]):
        place(b, musicbox(hz(nn), 0.6), t1 + 0.4 + i * 0.25, 0.3)
    b = reverb(b, 1.25, 0.3, 0.55)
    return master(b[: int(13.6 * SR)], 0.0, 2.0, 0.8)


def menu():
    """Ana menü döngüsü: 16 ölçü (53 sn), kesintisiz döner."""
    beat = 0.833
    bar = 4 * beat
    L = 16 * bar
    b = buf(L + 8.0)
    # 1-8: müzik kutusu + pad
    chords(b, CHORDS_A + CHORDS_B, 0.0, beat, 0.85)
    melody(b, THEME_A, 0.0, beat, "musicbox", 1.0, 0.25)
    melody(b, THEME_B, 4 * bar, beat, "musicbox", 1.0, 0.25)
    # 9-16: piyano ezgiyi alır, müzik kutusu bir oktav yukarıda yankılar
    chords(b, CHORDS_A + CHORDS_B, 8 * bar, beat, 1.0)
    melody(b, THEME_A, 8 * bar, beat, "piano", 0.95, 0.1)
    melody(b, THEME_B, 12 * bar, beat, "piano", 0.95, 0.1)
    melody(b, THEME_B, 12 * bar + beat * 0.5, beat, "musicbox", 0.45, 0.4, 1)
    # uzaktan fener çanı: döngünün başında ve ortasında
    place(b, bell(hz("D3"), 0.35, 8.0), 0.0, -0.4)
    place(b, bell(hz("D3"), 0.3, 8.0), 8 * bar, 0.4)
    b = reverb(b, 1.3, 0.35, 0.6)
    # dikişsiz döngü: döngü sonrası kuyruğu başa ekle
    loop = b[: int(L * SR)].copy()
    tail = b[int(L * SR):]
    loop[: len(tail)] += tail
    return master(loop, 0.0, 0.0, 0.7)


if __name__ == "__main__":
    write(studio(), "studio")
    write(intro(), "intro")
    write(menu(), "menu")
