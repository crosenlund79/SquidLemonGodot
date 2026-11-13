#!/usr/bin/env python3
"""Procedurally generates every sound in "Eight Arms Up".

    python3 tools/gen_audio.py            # writes assets/audio/*.wav

Needs only numpy. Everything here is synthesised from scratch, including
"Kastanienwalzer", an original Viennese waltz played through a 1937 radio.
"""
import os
import wave
import numpy as np

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(1937)


# ----------------------------------------------------------------------------- helpers

def t_axis(dur):
    return np.arange(int(dur * SR)) / SR


def write(name, x, peak=0.89, fade=True):
    x = np.asarray(x, dtype=np.float64).copy()
    if fade and len(x) > 400:
        k = int(0.006 * SR)
        x[:30] *= np.linspace(0, 1, 30)
        x[-k:] *= np.linspace(1, 0, k)
    m = np.max(np.abs(x)) if x.size else 1.0
    if m > 0:
        x = x / m * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    os.makedirs(OUT, exist_ok=True)
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"  {name:16s} {len(x) / SR:5.2f}s")


def midi(n):
    return 440.0 * 2.0 ** ((n - 69) / 12.0)


NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "D#": 3, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6,
        "G": 7, "G#": 8, "Ab": 8, "A": 9, "A#": 10, "Bb": 10, "B": 11}


def nn(s):
    """'F#4' -> midi number"""
    name, octv = s[:-1], int(s[-1])
    return 12 * (octv + 1) + NOTE[name]


def env_adsr(n, a=0.01, d=0.05, s=0.7, r=0.05):
    e = np.ones(n) * s
    na, nd, nr = int(a * SR), int(d * SR), int(r * SR)
    na = min(na, n)
    e[:na] = np.linspace(0, 1, na, endpoint=False) if na else e[:na]
    nd = min(nd, n - na)
    if nd > 0:
        e[na:na + nd] = np.linspace(1, s, nd, endpoint=False)
    nr = min(nr, n)
    if nr > 0:
        e[n - nr:] *= np.linspace(1, 0, nr)
    return e


def env_exp(n, decay, attack=0.003):
    t = np.arange(n) / SR
    e = np.exp(-t / decay)
    na = min(n, int(attack * SR))
    if na > 0:
        e[:na] *= np.linspace(0, 1, na)
    return e


def osc(freq, n, kind="sine", phase0=0.0):
    """freq can be a scalar or per-sample array."""
    f = np.broadcast_to(np.asarray(freq, dtype=np.float64), (n,))
    ph = phase0 + 2 * np.pi * np.cumsum(f) / SR
    if kind == "sine":
        return np.sin(ph)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(ph))
    if kind == "square":
        out = np.zeros(n)
        for k in range(1, 16, 2):
            mask = (f * k) < SR * 0.45
            out += np.where(mask, np.sin(ph * k) / k, 0)
        return out * 4 / np.pi
    if kind == "saw":
        out = np.zeros(n)
        for k in range(1, 24):
            mask = (f * k) < SR * 0.45
            out += np.where(mask, np.sin(ph * k) / k, 0)
        return out * 2 / np.pi
    raise ValueError(kind)


def noise(n):
    return rng.uniform(-1, 1, n)


def brown(n):
    x = np.cumsum(rng.normal(0, 1, n))
    x -= np.linspace(x[0], x[-1], n)  # make it loopable-ish
    x -= x.mean()
    return x / (np.max(np.abs(x)) + 1e-9)


def fft_filter(x, lo=None, hi=None, slope=2.0):
    """Zero-phase band filter via FFT with soft (Butterworth-like) slopes. Circular."""
    n = len(x)
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.ones_like(f)
    if lo:
        g *= 1 / np.sqrt(1 + (lo / np.maximum(f, 1e-3)) ** (2 * slope))
    if hi:
        g *= 1 / np.sqrt(1 + (f / hi) ** (2 * slope))
    return np.fft.irfft(X * g, n)


def onepole_lp(x, cutoff):
    """One-pole low-pass with per-sample cutoff (Python loop: short sounds only)."""
    c = np.broadcast_to(np.asarray(cutoff, dtype=np.float64), (len(x),))
    a = 1 - np.exp(-2 * np.pi * c / SR)
    y = np.zeros(len(x))
    z = 0.0
    for i in range(len(x)):
        z += a[i] * (x[i] - z)
        y[i] = z
    return y


def bandpass_res(x, freq, q):
    """State-variable band-pass with per-sample frequency (loop)."""
    fr = np.broadcast_to(np.asarray(freq, dtype=np.float64), (len(x),))
    y = np.zeros(len(x))
    low = band = 0.0
    damp = 1.0 / q
    for i in range(len(x)):
        f = 2 * np.sin(np.pi * min(fr[i], SR * 0.22) / SR)
        high = x[i] - low - damp * band
        band += f * high
        low += f * band
        y[i] = band
    return y


def place(buf, x, start):
    s = int(start)
    if s >= len(buf):
        return
    e = min(len(buf), s + len(x))
    buf[s:e] += x[: e - s]


def place_circ(buf, x, start):
    s = int(start) % len(buf)
    for i in range(0, len(x), len(buf)):
        chunk = x[i:i + len(buf)]
        e = s + len(chunk)
        if e <= len(buf):
            buf[s:e] += chunk
        else:
            k = len(buf) - s
            buf[s:] += chunk[:k]
            buf[: e - len(buf)] += chunk[k:]


def reverb_ir(dur, decay, lo=200, hi=5000):
    n = int(dur * SR)
    ir = noise(n) * np.exp(-np.arange(n) / SR / decay)
    ir = fft_filter(ir, lo, hi)
    ir[0] += 0.0
    return ir / np.sqrt(np.sum(ir ** 2) + 1e-9)


def conv_circ(x, ir):
    n = len(x)
    if len(ir) > n:
        ir = ir[:n]
    return np.fft.irfft(np.fft.rfft(x) * np.fft.rfft(ir, n), n)


def conv(x, ir):
    n = len(x) + len(ir)
    return np.fft.irfft(np.fft.rfft(x, n) * np.fft.rfft(ir, n), n)


def tone(freq, dur, kind="sine", decay=None, a=0.005, r=0.02):
    n = int(dur * SR)
    x = osc(freq, n, kind)
    if decay:
        return x * env_exp(n, decay, a)
    return x * env_adsr(n, a, 0.02, 0.9, r)


def chirp(f0, f1, dur, kind="sine", curve="exp"):
    n = int(dur * SR)
    if curve == "exp":
        f = f0 * (f1 / f0) ** np.linspace(0, 1, n)
    else:
        f = np.linspace(f0, f1, n)
    return osc(f, n, kind)


# ----------------------------------------------------------------------------- the waltz

BPM = 168.0
BEAT = 60.0 / BPM
BAR = 3 * BEAT

MEL_A = [
    [("A4", 2), ("F#4", 1)], [("D5", 3)], [("C#5", 2), ("B4", 1)], [("A4", 2), ("G4", 1)],
    [("E4", 1), ("G4", 1), ("C#5", 1)], [("E5", 2), ("D5", 1)], [("C#5", 1), ("D5", 1), ("F#5", 1)], [("A5", 3)],
    [("F#5", 2), ("E5", 1)], [("D5", 2), ("A4", 1)], [("B4", 2), ("D5", 1)], [("G5", 3)],
    [("F#5", 1), ("E5", 1), ("D5", 1)], [("E5", 2), ("C#5", 1)], [("D5", 3)], [("D5", 1), (None, 2)],
]
CH_A = ["D", "D", "A7", "A7", "A7", "A7", "D", "D", "D", "D", "G", "G", "D", "A7", "D", "D"]

MEL_B = [
    [("B4", 1), ("D5", 1), ("G5", 1)], [("B5", 2), ("A5", 1)], [("A5", 1), ("F#5", 1), ("D5", 1)], [("C5", 3)],
    [("C5", 1), ("D5", 1), ("F#5", 1)], [("A5", 2), ("G5", 1)], [("G5", 1), ("F#5", 1), ("G5", 1)], [("B5", 3)],
    [("E5", 1), ("G5", 1), ("C6", 1)], [("C6", 2), ("A5", 1)], [("G5", 2), ("D5", 1)], [("B4", 3)],
    [("F#5", 2), ("E5", 1)], [("D5", 2), ("C5", 1)], [("B4", 3)], [("A4", 2), ("C#5", 1)],
]
CH_B = ["G", "G", "D7", "D7", "D7", "D7", "G", "G", "C", "C", "G", "G", "D7", "D7", "G", "A7"]

CHORDS = {  # bass root, bass fifth, upper voicing
    "D": ("D3", "A2", ["D4", "F#4", "A4"]),
    "A7": ("A2", "E3", ["C#4", "E4", "G4"]),
    "G": ("G2", "D3", ["D4", "G4", "B4"]),
    "C": ("C3", "G2", ["E4", "G4", "C5"]),
    "D7": ("D3", "A2", ["C4", "F#4", "A4"]),
}


def violin(freq, dur, vel=1.0):
    n = int((dur + 0.25) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.0055 * np.sin(2 * np.pi * 5.6 * t) * np.clip((t - 0.12) * 5, 0, 1)
    x = osc(freq * vib, n, "saw") * 0.6 + osc(freq * vib * 1.003, n, "saw") * 0.4
    x = fft_filter(x, 180, 3600, 1.5)
    e = env_adsr(n, 0.045, 0.08, 0.82, 0.22)
    e[int(dur * SR):] *= np.linspace(1, 0, n - int(dur * SR)) if n > int(dur * SR) else 1
    return x * e * vel


def flute(freq, dur, vel=1.0):
    n = int((dur + 0.15) * SR)
    t = np.arange(n) / SR
    vib = 1 + 0.004 * np.sin(2 * np.pi * 5.0 * t)
    x = osc(freq * vib, n) + 0.25 * osc(freq * 2 * vib, n) + 0.05 * noise(n)
    return x * env_adsr(n, 0.06, 0.1, 0.8, 0.15) * vel


def pluck_bass(freq, dur=0.5):
    n = int(dur * SR)
    x = osc(freq, n) + 0.5 * osc(freq * 2, n) + 0.2 * osc(freq * 3, n, "tri")
    return x * env_exp(n, 0.28, 0.004)


def pah(freqs, dur=0.22):
    n = int(dur * SR)
    x = np.zeros(n)
    for f in freqs:
        x += osc(f, n, "tri") + 0.3 * osc(f * 2, n)
    return x * env_exp(n, 0.09, 0.006) / len(freqs)


def celesta(freq, dur=0.9):
    n = int(dur * SR)
    x = osc(freq, n) + 0.35 * osc(freq * 4.0, n) * env_exp(n, 0.08)
    return x * env_exp(n, 0.35, 0.002)


def render_section(buf, start_bar, melody, chords, variant=0):
    for b in range(16):
        t0 = (start_bar + b) * BAR * SR
        ch = CHORDS[chords[b]]
        bass = ch[0] if b % 2 == 0 else ch[1]
        place(buf["bass"], pluck_bass(midi(nn(bass))) * 0.9, t0)
        up = [midi(nn(s)) for s in ch[2]]
        place(buf["pah"], pah(up) * 0.75, t0 + (BEAT - 0.028) * SR)   # Viennese early 2nd beat
        place(buf["pah"], pah(up) * 0.6, t0 + 2 * BEAT * SR)
        pos = 0.0
        for note, beats in melody[b]:
            if note:
                f = midi(nn(note))
                d = beats * BEAT * 0.95
                place(buf["mel"], violin(f, d, 0.9), t0 + pos * BEAT * SR)
                if variant == 1:
                    place(buf["sparkle"], celesta(f * 2, 0.8) * 0.5, t0 + pos * BEAT * SR)
                if variant == 2:
                    place(buf["flute"], flute(f * 2, d) * 0.35, t0 + pos * BEAT * SR)
            pos += beats


def make_waltz():
    bars = 48
    n = int(bars * BAR * SR)
    tracks = {k: np.zeros(n + SR * 2) for k in ["bass", "pah", "mel", "sparkle", "flute"]}
    render_section(tracks, 0, MEL_A, CH_A, 0)
    render_section(tracks, 16, MEL_B, CH_B, 1)
    render_section(tracks, 32, MEL_A, CH_A, 2)
    mix = (tracks["bass"] * 0.8 + tracks["pah"] * 0.5 + tracks["mel"] * 0.85 + tracks["sparkle"] * 0.35
           + tracks["flute"] * 0.5)
    # fold the tail back to the start so the loop is seamless
    loop = mix[:n].copy()
    loop[: len(mix) - n] += mix[n:]
    # a bit of hall
    loop = loop + 0.18 * conv_circ(loop, reverb_ir(1.6, 0.45))
    # --- the 1937 radio ---
    t = np.arange(n) / SR
    wow_f = 3.0 / (n / SR)  # three wobbles per loop -> seamless
    warp = t + 0.0018 * np.sin(2 * np.pi * wow_f * t) / (2 * np.pi * wow_f) * 2 * np.pi * wow_f
    loop = np.interp(warp % (n / SR), t, loop, period=n / SR)
    loop = fft_filter(loop, 170, 5200, 1.6)
    loop = np.tanh(loop / np.max(np.abs(loop)) * 1.5)
    hiss = fft_filter(noise(n), 800, 6000) * 0.012
    crackle = np.zeros(n)
    for _ in range(int(n / SR * 7)):
        p = rng.integers(0, n - 40)
        crackle[p:p + 3] += rng.uniform(-1, 1) * rng.uniform(0.05, 0.28)
    crackle = fft_filter(crackle, 500, 5000)
    out = loop * 0.9 + hiss + crackle
    write("waltz", out, 0.82, fade=False)


# ----------------------------------------------------------------------------- ambience

def make_amb_garage():
    dur = 24.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    hum = 0.06 * np.sin(2 * np.pi * 50 * t) + 0.03 * np.sin(2 * np.pi * 100 * t) + 0.012 * np.sin(2 * np.pi * 150 * t)
    vent = fft_filter(noise(n), 40, 420) * (0.7 + 0.3 * np.sin(2 * np.pi * t / dur * 2))
    vent = vent / np.max(np.abs(vent)) * 0.35
    rumble = brown(n) * 0.25
    ev = np.zeros(n)
    for k in range(9):
        s = rng.uniform(0, dur - 1) * SR
        f = rng.uniform(900, 1700)
        d = chirp(f, f * 0.6, 0.08) * env_exp(int(0.08 * SR), 0.02) * 0.4
        place_circ(ev, d, s)
    for k in range(3):  # distant clanks / car doors
        s = rng.uniform(0, dur - 1) * SR
        thud = (osc(rng.uniform(60, 90), int(0.25 * SR)) + 0.4 * noise(int(0.25 * SR))) * env_exp(int(0.25 * SR), 0.05)
        place_circ(ev, fft_filter(thud, 40, 700) * 0.6, s)
    ev = conv_circ(ev, reverb_ir(2.4, 0.7, 150, 3000)) * 2.0
    write("amb_garage", hum + vent + rumble + ev, 0.7, fade=False)


def make_amb_city():
    dur = 20.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    rain = fft_filter(noise(n), 1500, 8000) * 0.18
    drops = np.zeros(n)
    for _ in range(int(dur * 40)):
        s = rng.integers(0, n - 200)
        drops[s:s + 60] += noise(60) * env_exp(60, 0.0015) * rng.uniform(0.05, 0.3)
    drops = fft_filter(drops, 1200, 7000)
    traffic = fft_filter(noise(n), 30, 300)
    traffic = traffic / np.max(np.abs(traffic)) * (0.4 + 0.25 * np.sin(2 * np.pi * t / dur * 3))
    # a distant tram bell ("Bim-bim")
    bell = np.zeros(n)
    for k, s in enumerate([6.0, 6.32]):
        b = celesta(midi(nn("E6")), 1.2) * 0.25
        b[: int(0.6 * SR)] += celesta(midi(nn("E6")) * 2.76, 0.6) * 0.1
        place_circ(bell, b, s * SR)
    bell = conv_circ(bell, reverb_ir(1.5, 0.4))
    write("amb_city", rain + drops + traffic * 0.5 + bell * 0.6, 0.6, fade=False)


# ----------------------------------------------------------------------------- loops

def make_loops():
    # engine: 1.2 s
    n = int(1.2 * SR)
    t = np.arange(n) / SR
    f = 50 * 2.5  # 125 Hz-ish rumble, pitch-shifted in game
    x = osc(f / 2.5 * 2, n, "saw") * (0.6 + 0.4 * np.sin(2 * np.pi * 25 * t)) + 0.4 * fft_filter(noise(n), 60, 600)
    write("loop_engine", fft_filter(x, 40, 1200), 0.6, fade=False)
    # siren: Austrian two-tone, 0.6 s each
    seg = int(0.6 * SR)
    a = osc(midi(nn("A4")), seg, "square")
    d = osc(midi(nn("D5")), seg, "square")
    sir = np.concatenate([a, d, a, d])
    sir = fft_filter(sir, 300, 3000)
    write("loop_siren", sir, 0.6, fade=False)
    # jet fan
    n = int(1.0 * SR)
    t = np.arange(n) / SR
    fan = fft_filter(noise(n), 80, 1400) * (0.75 + 0.25 * np.sin(2 * np.pi * 24 * t)) + 0.2 * np.sin(2 * np.pi * 96 * t)
    write("loop_fan", fan, 0.55, fade=False)
    # hot vent
    n = int(2.0 * SR)
    t = np.arange(n) / SR
    vent = fft_filter(noise(n), 250, 2200) * (0.7 + 0.3 * np.sin(2 * np.pi * 1.0 * t))
    write("loop_vent", vent, 0.45, fade=False)
    # sprinkler hiss
    n = int(1.0 * SR)
    spr = fft_filter(noise(n), 2500, 9000)
    for _ in range(25):
        s = rng.integers(0, n - 300)
        place_circ(spr, chirp(rng.uniform(1500, 3000), 900, 0.012) * 0.6, s)
    write("loop_sprinkler", spr, 0.45, fade=False)
    # reversing beeper
    n = int(1.0 * SR)
    beep = np.zeros(n)
    place(beep, tone(1050, 0.42, "square") * 0.6, 0)
    write("loop_beep", fft_filter(beep, 400, 3000), 0.5, fade=False)


# ----------------------------------------------------------------------------- one-shots

def make_sfx():
    write("jump", chirp(260, 640, 0.13) * env_exp(int(0.13 * SR), 0.06) + 0.3 * chirp(520, 1280, 0.13) * env_exp(int(0.13 * SR), 0.03))
    n = int(0.16 * SR)
    land = chirp(110, 45, 0.16) * env_exp(n, 0.05) + 0.6 * fft_filter(noise(n), 200, 1500) * env_exp(n, 0.025)
    write("land", land)
    n = int(0.05 * SR)
    write("step", fft_filter(noise(n), 500, 2200) * env_exp(n, 0.012) + 0.4 * chirp(400, 250, 0.05) * env_exp(n, 0.015), 0.7)
    # splash
    n = int(0.7 * SR)
    sp = noise(n) * env_exp(n, 0.16, 0.004)
    sp = bandpass_res(sp, np.linspace(3500, 600, n), 0.9) * 1.5 + fft_filter(noise(n), 1500, 8000) * env_exp(n, 0.08) * 0.5
    for _ in range(9):
        b = chirp(rng.uniform(300, 600), rng.uniform(900, 1600), 0.05) * env_exp(int(0.05 * SR), 0.015) * 0.3
        place(sp, b, rng.uniform(0.05, 0.5) * SR)
    write("splash", sp)
    n = int(0.3 * SR)
    sw = fft_filter(noise(n), 150, 900) * env_adsr(n, 0.08, 0.05, 0.6, 0.15)
    place(sw, chirp(350, 900, 0.05) * env_exp(int(0.05 * SR), 0.015) * 0.4, 0.12 * SR)
    write("swim", sw, 0.6)
    n = int(0.14 * SR)
    shoot = bandpass_res(noise(n), np.linspace(5000, 900, n), 2.0) * env_exp(n, 0.05) + 0.4 * chirp(1400, 300, 0.14) * env_exp(n, 0.05)
    write("shoot", shoot)
    n = int(0.09 * SR)
    att = chirp(700, 160, 0.09) * env_exp(n, 0.03)
    att[:30] += noise(30) * 0.8
    write("attach", att)
    n = int(0.4 * SR)
    ink = noise(n) * env_adsr(n, 0.01, 0.1, 0.5, 0.2)
    ink = onepole_lp(ink, np.geomspace(4500, 350, n)) * (0.7 + 0.3 * np.sin(2 * np.pi * 38 * np.arange(n) / SR))
    write("ink", ink)
    k = np.zeros(int(0.5 * SR))
    place(k, celesta(midi(nn("E6")), 0.3), 0)
    place(k, celesta(midi(nn("B6")), 0.4), 0.08 * SR)
    write("kastanie", k)
    # checkpoint: slosh + bell
    n = int(1.2 * SR)
    cp = np.zeros(n)
    sl = noise(int(0.45 * SR)) * env_adsr(int(0.45 * SR), 0.12, 0.1, 0.5, 0.2)
    place(cp, bandpass_res(sl, 700, 1.2) * 0.6, 0)
    bell = sum(osc(880 * r, n) * env_exp(n, 0.5 / r) * a for r, a in [(1, 1), (2.76, 0.4), (5.4, 0.2)])
    place(cp, bell * 0.5, 0.12 * SR)
    write("checkpoint", cp)
    n = int(0.25 * SR)
    hurt = osc(np.geomspace(240, 100, n), n, "square") * env_exp(n, 0.07) * 0.6 + fft_filter(noise(n), 60, 600) * env_exp(n, 0.04)
    write("hurt", fft_filter(hurt, 60, 2500))
    # dried out: sad trombone
    d = np.zeros(int(2.0 * SR))
    for i, (note, dur) in enumerate([("G3", 0.32), ("F#3", 0.32), ("F3", 0.32), ("E3", 0.9)]):
        f = midi(nn(note))
        nn_ = int(dur * SR)
        tt = np.arange(nn_) / SR
        vib = 1 + (0.012 * np.sin(2 * np.pi * 6 * tt) if i == 3 else 0)
        x = osc(f * vib, nn_, "saw") * env_adsr(nn_, 0.03, 0.05, 0.8, 0.12)
        place(d, onepole_lp(x, 1200), sum([0.32] * i) * SR)
    write("dry", d)
    r = np.zeros(int(0.7 * SR))
    for i, note in enumerate(["C5", "E5", "G5", "C6"]):
        place(r, celesta(midi(nn(note)), 0.4), i * 0.07 * SR)
    for _ in range(6):
        place(r, chirp(rng.uniform(400, 700), rng.uniform(1000, 1800), 0.04) * 0.2, rng.uniform(0, 0.4) * SR)
    write("respawn", r)


def formant_noise(dur, formants, env):
    n = int(dur * SR)
    src = noise(n)
    y = np.zeros(n)
    for f, q, a in formants:
        y += bandpass_res(src, f, q) * a
    return y * env


def make_voice():
    # the giant squid's inhale "Ha..." (breathy, low)
    n = int(0.6 * SR)
    e = np.linspace(0, 1, n) ** 1.5 * env_adsr(n, 0.01, 0.01, 1.0, 0.08)
    ha = formant_noise(0.6, [(620, 6, 1.0), (1050, 6, 0.7), (2400, 8, 0.2)], e)
    tt = np.arange(n) / SR
    voiced = osc(95 * (1 + 0.25 * tt), n, "saw")
    voiced = bandpass_res(voiced, 650, 5) * 0.35 + bandpass_res(voiced, 1100, 6) * 0.2
    write("sneeze_ha", ha + voiced * e)
    # "TSCHI!!"
    n = int(0.9 * SR)
    out = np.zeros(n)
    click = noise(int(0.01 * SR)) * 1.5
    place(out, click, 0)
    sch = fft_filter(noise(int(0.18 * SR)), 1800, 7000) * env_adsr(int(0.18 * SR), 0.005, 0.05, 0.8, 0.05)
    place(out, sch * 1.2, 0.005 * SR)
    m = int(0.32 * SR)
    tt = np.arange(m) / SR
    pulse = osc(170 * (1 - 0.3 * tt), m, "saw")
    ee = bandpass_res(pulse, 300, 4) * 0.8 + bandpass_res(pulse, 2200, 9) * 0.5
    place(out, ee * env_adsr(m, 0.01, 0.06, 0.7, 0.18), 0.15 * SR)
    boom = chirp(90, 35, 0.6) * env_exp(int(0.6 * SR), 0.18)
    place(out, boom * 0.9, 0.12 * SR)
    spray = fft_filter(noise(int(0.6 * SR)), 300, 4000) * env_exp(int(0.6 * SR), 0.2) * 0.5
    place(out, spray, 0.18 * SR)
    write("sneeze_tschi", out)
    n = int(2.0 * SR)
    g = fft_filter(noise(n), 120, 2600) * env_adsr(n, 0.05, 0.2, 0.75, 0.9)
    g += fft_filter(noise(n), 2000, 7000) * env_adsr(n, 0.02, 0.2, 0.3, 0.8) * 0.4
    write("geyser", g)
    # pigeon
    fl = np.zeros(int(0.32 * SR))
    for i in range(4):
        b = fft_filter(noise(int(0.035 * SR)), 400, 2200) * env_exp(int(0.035 * SR), 0.01)
        place(fl, b, i * 0.07 * SR)
    write("flap", fl)
    n = int(0.7 * SR)
    tt = np.arange(n) / SR
    coo = osc(320 * (1 - 0.15 * tt), n) * (0.6 + 0.4 * np.sin(2 * np.pi * 28 * tt)) * env_adsr(n, 0.05, 0.1, 0.7, 0.3)
    write("coo", onepole_lp(coo, 900), 0.6)
    n = int(0.38 * SR)
    horn = (osc(midi(nn("A4")), n, "square") + osc(midi(nn("C#5")), n, "square")) * env_adsr(n, 0.01, 0.02, 0.9, 0.05)
    write("horn", fft_filter(horn, 300, 2800))
    n = int(0.09 * SR)
    write("drip", osc(np.geomspace(1700, 850, n), n) * env_exp(n, 0.025))
    lem = np.zeros(int(2.0 * SR))
    for i, note in enumerate(["C6", "E6", "G6", "B6", "D7", "G7"]):
        f = midi(nn(note))
        place(lem, celesta(f, 1.3) * 0.6 + celesta(f * 1.005, 1.3) * 0.4, i * 0.09 * SR)
    lem = lem + 0.4 * conv(lem, reverb_ir(1.2, 0.35))[: len(lem)]
    write("lemon", lem)
    n = int(0.07 * SR)
    tt = np.arange(n) / SR
    write("blip_squid", osc(150 * (1 + 0.3 * np.sin(2 * np.pi * 30 * tt)), n, "tri") * env_adsr(n, 0.005, 0.01, 0.8, 0.03), 0.7)
    write("blip_otto", chirp(600, 950, 0.05) * env_adsr(int(0.05 * SR), 0.003, 0.01, 0.8, 0.02), 0.6)
    n = int(0.05 * SR)
    write("blip_radio", fft_filter(osc(420, n, "square"), 400, 2500) * env_adsr(n, 0.003, 0.01, 0.8, 0.02), 0.6)
    n = int(0.035 * SR)
    write("ui_move", osc(1250, n) * env_exp(n, 0.01), 0.5)
    ok = np.zeros(int(0.3 * SR))
    place(ok, celesta(midi(nn("G5")), 0.2), 0)
    place(ok, celesta(midi(nn("D6")), 0.25), 0.07 * SR)
    write("ui_ok", ok, 0.6)
    n = int(0.06 * SR)
    write("climb", fft_filter(noise(n), 300, 1800) * env_exp(n, 0.012) + 0.5 * chirp(300, 180, 0.06) * env_exp(n, 0.02), 0.5)
    n = int(1.1 * SR)
    tt = np.arange(n) / SR
    tune = fft_filter(noise(n), 300, 4000) * 0.4 + 0.5 * osc(np.geomspace(2500, 600, n) + 200 * np.sin(2 * np.pi * 3 * tt), n)
    write("radio_tune", tune * env_adsr(n, 0.05, 0.1, 0.8, 0.3), 0.6)
    n = int(1.4 * SR)
    gust = noise(n) * env_adsr(n, 0.4, 0.2, 0.7, 0.6)
    gust = bandpass_res(gust, 500 + 600 * np.sin(np.linspace(0, np.pi, n)), 1.5)
    write("gust", gust, 0.6)
    g = np.zeros(int(0.6 * SR))
    for i in range(2):
        m = int(0.18 * SR)
        place(g, chirp(220, 110, 0.18) * env_adsr(m, 0.01, 0.03, 0.7, 0.06) + 0.3 * fft_filter(noise(m), 100, 800) * env_exp(m, 0.05), i * 0.22 * SR)
    write("gulp", onepole_lp(g, 1200))
    n = int(0.12 * SR)
    write("plop", chirp(450, 140, 0.12) * env_exp(n, 0.04))
    fan = np.zeros(int(2.0 * SR))
    for note, st, d in [("D5", 0.0, 0.18), ("F#5", 0.18, 0.18), ("A5", 0.36, 0.18), ("D6", 0.54, 1.1)]:
        f = midi(nn(note))
        m = int(d * SR)
        x = osc(f, m, "saw") * env_adsr(m, 0.02, 0.05, 0.85, 0.2)
        place(fan, fft_filter(x, 200, 4000), st * SR)
        place(fan, celesta(f * 2, 0.8) * 0.3, st * SR)
    write("fanfare", fan)


if __name__ == "__main__":
    print("Generating audio into", os.path.normpath(OUT))
    make_sfx()
    make_voice()
    make_loops()
    make_amb_garage()
    make_amb_city()
    make_waltz()
    print("done.")
