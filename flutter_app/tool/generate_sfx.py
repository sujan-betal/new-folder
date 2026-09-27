"""Generate the Ludo Master sound suite as 16-bit mono 44.1 kHz WAV files.

Everything here is synthesised from scratch with the standard library only
(modal impacts, Karplus-Strong plucks, swept filtered noise, FM bells, a small
Schroeder reverb). No third-party assets, no third-party packages.

    python tool/generate_sfx.py
"""

import math
import os
import random
import struct
import wave

SR = 44100
OUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)),
                       "..", "assets", "sounds")


# --------------------------------------------------------------------------
# buffer helpers
# --------------------------------------------------------------------------
def new_buf(dur):
    return [0.0] * int(SR * dur)


def mix(dst, src, at=0.0, gain=1.0):
    start = int(at * SR)
    n = len(src)
    for i in range(n):
        j = start + i
        if 0 <= j < len(dst):
            dst[j] += src[i] * gain


def gain_env(dur, attack=0.002, curve=4.0, sustain=0.0, hold=0.0):
    """Percussive envelope: fast attack then exponential-ish decay."""
    n = int(SR * dur)
    a = max(1, int(SR * attack))
    out = [0.0] * n
    for i in range(n):
        if i < a:
            t = i / a
        else:
            t = 0.0
        tail = (i - a) / max(1.0, (n - a))
        env = (1.0 - tail) ** curve if i >= a else t
        if hold > 0.0 and i < a + int(SR * hold):
            env = max(env, sustain)
        out[i] = env
    return out


def decay_env(n, tau):
    return [math.exp(-(i / SR) / tau) for i in range(n)]


def sine(freq, dur, phase=0.0):
    n = int(SR * dur)
    w = 2.0 * math.pi * freq / SR
    return [math.sin(w * i + phase) for i in range(n)]


def saw(freq, dur, harmonics=18):
    """Additive saw with 1/n rolloff - warm, no aliasing crunch."""
    n = int(SR * dur)
    out = [0.0] * n
    for h in range(1, harmonics + 1):
        f = freq * h
        if f >= SR * 0.45:
            break
        w = 2.0 * math.pi * f / SR
        g = 1.0 / (h ** 1.15)
        for i in range(n):
            out[i] += math.sin(w * i) * g
    scale = 1.0 / sum(1.0 / (h ** 1.15)
                      for h in range(1, min(harmonics,
                                            int(SR * 0.45 / freq)) + 1))
    return [v * scale for v in out]


def noise(dur, seed=0):
    rng = random.Random(seed)
    return [rng.uniform(-1.0, 1.0) for _ in range(int(SR * dur))]


# --------------------------------------------------------------------------
# filters
# --------------------------------------------------------------------------
class SVF:
    """Chamberlin state-variable filter: stable, sweeps nicely."""

    def __init__(self, cutoff, q=1.0):
        self.set(cutoff, q)
        self.low = 0.0
        self.band = 0.0

    def set(self, cutoff, q=1.0):
        self.f = 2.0 * math.sin(math.pi * max(30.0, min(cutoff,
                                                         SR * 0.24)) / SR)
        self.q = 1.0 / max(0.5, q)

    def run(self, x):
        self.low += self.f * self.band
        high = x - self.low - self.q * self.band
        self.band += self.f * high
        return self.low, self.band, high


def band_noise(dur, seed, f_start, f_end, q=4.0, curve=2.0, attack=0.004):
    """Noise through a sweeping bandpass - whooshes, shakers, rattle air."""
    n = int(SR * dur)
    src = noise(dur, seed)
    f = SVF(f_start, q)
    out = [0.0] * n
    for i in range(n):
        t = i / n
        cutoff = f_start * ((f_end / f_start) ** t)
        f.set(cutoff, q)
        _, band, _ = f.run(src[i])
        env = (i / max(1.0, SR * attack)) ** 0.5 if i < SR * attack else 1.0
        out[i] = band * env * (1.0 - t) ** curve
    return out


def low_noise(dur, seed, cutoff, q=1.0, curve=2.0):
    n = int(SR * dur)
    src = noise(dur, seed)
    f = SVF(cutoff, q)
    out = [0.0] * n
    for i in range(n):
        low, _, _ = f.run(src[i])
        out[i] = low * (1.0 - i / n) ** curve
    return out


def reverb(sig, mix_amt=0.22, decay=0.72, seed=3):
    """Cheap Schroeder reverb: 3 combs + 2 allpasses, tail wrapped for loops."""
    n = len(sig)
    out = list(sig)
    rng = random.Random(seed)
    for delay_ms, fb in ((29.7, decay), (37.1, decay * 0.96), (41.1, decay * 0.9)):
        d = int(SR * delay_ms / 1000.0)
        buf = [0.0] * d
        idx = 0
        for i in range(n):
            v = out[i] + buf[idx] * fb
            buf[idx] = v
            idx = (idx + 1) % d
            out[i] = v * 0.5
    for delay_ms in (5.0, 1.7):
        d = int(SR * delay_ms / 1000.0)
        buf = [0.0] * d
        idx = 0
        for i in range(n):
            v = out[i]
            out[i] = v + buf[idx] * 0.5
            buf[idx] = v
            idx = (idx + 1) % d
    for i in range(n):
        out[i] = out[i] * (1.0 - mix_amt) + sig[i] * mix_amt
    _ = rng
    return out


# --------------------------------------------------------------------------
# instruments
# --------------------------------------------------------------------------
def clack(dur, f0, amp=1.0, seed=0, brightness=1.0, body=True):
    """Modal impact: plastic / wooden 'tock'. The core of every cue."""
    n = int(SR * dur)
    out = [0.0] * n
    modes = [(1.00, 1.00, 1.00), (2.41, 0.52, 0.62), (4.05, 0.30, 0.42),
             (6.72, 0.17, 0.30), (9.40, 0.09, 0.22)]
    rng = random.Random(seed)
    for ratio, g, taus in modes:
        f = f0 * ratio * brightness
        if f > SR * 0.45:
            continue
        tau = min(dur * 0.9, (dur * 0.34) / (0.55 + ratio * 0.35))
        ph = rng.uniform(0, 2 * math.pi)
        w = 2.0 * math.pi * f / SR
        for i in range(n):
            out[i] += math.sin(w * i + ph) * math.exp(-(i / SR) / tau) * g
    # 2 ms noise transient so the attack has bite.
    tr = int(SR * 0.002)
    hi = SVF(min(9000.0, f0 * 3.2), 1.2)
    for i in range(min(tr, n)):
        _, band, _ = hi.run(rng.uniform(-1, 1))
        out[i] += band * (1.0 - i / tr) * 0.55
    if body:
        tau = min(dur * 0.8, 0.045 + 220.0 / f0)
        w = 2.0 * math.pi * (f0 * 0.42) / SR
        for i in range(n):
            out[i] += math.sin(w * i) * math.exp(-(i / SR) / tau) * 0.55
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * amp for v in out]


def pluck(freq, dur, amp=1.0, damp=0.996, seed=0, bright=0.5):
    """Karplus-Strong string - mallets, plucks, music voices."""
    n = int(SR * dur)
    N = max(2, int(SR / freq))
    rng = random.Random(seed)
    line = [rng.uniform(-1, 1) for _ in range(N)]
    # soften the excitation so it is not pure white noise
    prev = 0.0
    for i in range(N):
        cur = line[i]
        line[i] = (cur + prev) * (0.5 + bright * 0.4)
        prev = cur
    out = [0.0] * n
    idx = 0
    prev2 = 0.0
    for i in range(n):
        cur = line[idx]
        out[i] = cur
        nxt = (cur + prev2) * 0.5 * damp + cur * 0.0
        prev2 = cur
        line[idx] = nxt
        idx = (idx + 1) % N
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * amp for v in out]


def bell(freq, dur, amp=1.0, ratio=3.01, index=3.2, seed=0):
    """FM bell - bright, metallic sparkle for safe / home / reward."""
    n = int(SR * dur)
    out = [0.0] * n
    wc = 2.0 * math.pi * freq / SR
    wm = 2.0 * math.pi * freq * ratio / SR
    for i in range(n):
        t = i / SR
        e = math.exp(-t / (dur * 0.34))
        m = math.sin(wm * i) * index * math.exp(-t / (dur * 0.20))
        out[i] = math.sin(wc * i + m) * e
    # two quiet inharmonic partials for air
    for ratio2, g, taus in ((2.76, 0.22, 0.30), (5.4, 0.10, 0.18)):
        w = 2.0 * math.pi * freq * ratio2 / SR
        tau = dur * taus
        for i in range(n):
            out[i] += math.sin(w * i) * math.exp(-(i / SR) / tau) * g
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * amp for v in out]


def brass(freq, dur, amp=1.0, attack=0.03, release=0.12, vib=0.0):
    n = int(SR * dur)
    raw = saw(freq, dur)
    out = [0.0] * n
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    lp = SVF(1200.0, 0.9)
    for i in range(n):
        t = i / SR
        det = math.sin(2 * math.pi * 5.0 * t) * vib if vib else 0.0
        if i < a:
            env = i / a
        elif i > n - r:
            env = (n - i) / r
        else:
            env = 1.0
        val = raw[i]
        if det:
            w = 2.0 * math.pi * (freq * (1.0 + det * 0.004)) / SR
            val = math.sin(w * i)
        low, _, _ = lp.run(val)
        out[i] = (low * 0.7 + val * 0.3) * env * (1.0 + 0.25 * math.sin(t * 6.2))
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * amp for v in out]


def flute(freq, dur, amp=1.0, attack=0.02, release=0.09):
    """Soft breathy sine - used for turn / attention cues."""
    n = int(SR * dur)
    out = [0.0] * n
    a = max(1, int(SR * attack))
    r = max(1, int(SR * release))
    w = 2.0 * math.pi * freq / SR
    for i in range(n):
        t = i / SR
        if i < a:
            env = (i / a) ** 1.6
        elif i > n - r:
            env = ((n - i) / r) ** 1.4
        else:
            env = 1.0
        vib = 1.0 + 0.0025 * math.sin(2 * math.pi * 5.4 * t)
        out[i] = math.sin(w * vib * i) * env
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * amp for v in out]


def kick(dur=0.22, amp=1.0, f_hi=165.0, f_lo=48.0):
    n = int(SR * dur)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        t = i / SR
        f = f_lo + (f_hi - f_lo) * math.exp(-t / 0.028)
        ph += 2.0 * math.pi * f / SR
        out[i] = math.sin(ph) * math.exp(-t / 0.085) * (1.0 - math.exp(-t / 0.002))
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * amp for v in out]


def shaker(dur=0.07, amp=1.0, seed=1, cutoff=6500.0):
    n = int(SR * dur)
    src = noise(dur, seed)
    hp = SVF(cutoff, 0.8)
    out = [0.0] * n
    for i in range(n):
        _, _, high = hp.run(src[i])
        out[i] = high * (1.0 - i / n) ** 2.2
    peak = max(abs(v) for v in out) or 1.0
    return [v / peak * amp for v in out]


def note_at(buf_, at, sig, amp=1.0):
    mix(buf_, sig, at, amp)


# --------------------------------------------------------------------------
# normalisation / output
# --------------------------------------------------------------------------
def soft_limit(sig, ceiling=0.92):
    peak = max(abs(v) for v in sig) or 1.0
    scale = ceiling / peak if peak > ceiling else 1.0
    return [math.tanh(v * scale * 1.02) for v in sig]


def fade_edges(sig, ms=3.0):
    n = int(SR * ms / 1000.0)
    n = min(n, len(sig) // 2)
    for i in range(n):
        k = i / max(1, n)
        sig[i] *= k
        sig[-1 - i] *= k
    return sig


def write_wav(name, sig, target_rms=0.15, ceiling=0.89, tail_ms=6.0):
    """Loudness-normalise, then peak-limit with a soft knee.

    RMS (not peak) is what the ear tracks, so cues are balanced by RMS and
    only then clamped, which keeps the whole suite sitting at one level.
    """
    rms = math.sqrt(sum(v * v for v in sig) / len(sig)) or 1.0
    sig = [v * (target_rms / rms) for v in sig]
    peak = max(abs(v) for v in sig) or 1.0
    if peak > ceiling:
        sig = soft_limit(sig, ceiling)
    sig = fade_edges(sig, tail_ms)
    path = os.path.normpath(os.path.join(OUT_DIR, name + ".wav"))
    frames = bytearray()
    for v in sig:
        s = int(max(-1.0, min(1.0, v)) * 32767)
        frames += struct.pack("<h", s)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(bytes(frames))
    print("  %-14s %5.2fs  %6.1f KB" % (name, len(sig) / SR,
                                        os.path.getsize(path) / 1024.0))


# --------------------------------------------------------------------------
# the cues
# --------------------------------------------------------------------------
def sfx_dice_throw():
    """Hand shake before the throw: three quick knocks in a cup."""
    out = new_buf(0.34)
    for i, (at, amp, f) in enumerate(((0.0, 0.55, 2300.0),
                                      (0.055, 0.75, 2050.0),
                                      (0.112, 0.62, 2550.0))):
        mix(out, clack(0.09, f, amp, seed=11 + i, brightness=1.0), at)
    mix(out, band_noise(0.26, 21, 900, 3400, q=2.0, curve=1.4), 0.0, 0.35)
    return out


def sfx_dice_roll():
    """The signature sound: rattle in hand, tumble on the board, settle."""
    out = new_buf(0.95)
    rng = random.Random(77)

    # 1. agitation in hand - fast irregular knocks
    t = 0.0
    for i in range(7):
        t += 0.018 + rng.random() * 0.016
        mix(out, clack(0.07, 2500 - i * 90, 0.34 + rng.random() * 0.16,
                       seed=100 + i, brightness=1.05), t, 1.0)

    # 2. released - air whoosh as it leaves the hand
    mix(out, band_noise(0.16, 33, 700, 3000, q=2.2, curve=1.6), 0.115, 0.30)

    # 3. bouncing on the board: impacts get further apart and lower
    t = 0.235
    gap = 0.031
    f = 2150.0
    for i in range(11):
        t += gap * (0.85 + rng.random() * 0.5)
        gap *= 1.13
        f *= 0.905
        amp = 0.85 * (1.0 - i / 13.0) + 0.12
        mix(out, clack(0.10, max(430.0, f), amp, seed=200 + i,
                       brightness=0.95), t)

    # 4. the final two heavy clacks
    mix(out, clack(0.16, 780.0, 0.95, seed=301, brightness=0.9), 0.735)
    mix(out, clack(0.13, 520.0, 0.55, seed=302, brightness=0.9), 0.822)
    # low body thump under the landing
    mix(out, kick(0.20, 0.32, 120.0, 46.0), 0.735)
    return out


def sfx_move():
    """Per-hop token tock. Short, soft, round - safe to repeat fast."""
    return clack(0.085, 1560.0, 0.85, seed=41, brightness=0.95)


def sfx_release():
    """Token leaves the yard: scoop + confident landing on the track."""
    out = new_buf(0.40)
    mix(out, band_noise(0.16, 55, 500, 2600, q=2.4, curve=1.2), 0.0, 0.42)
    mix(out, clack(0.15, 1180.0, 0.95, seed=61), 0.115)
    mix(out, bell(1180.0, 0.20, 0.22), 0.115)
    return out


def sfx_capture():
    """Kill: descending swoop, heavy impact, crunch."""
    out = new_buf(0.70)
    mix(out, band_noise(0.34, 71, 4200, 380, q=2.0, curve=1.0), 0.0, 0.75)
    mix(out, low_noise(0.30, 72, 900, 0.8, curve=1.0), 0.0, 0.55)
    mix(out, kick(0.36, 1.0, 190.0, 44.0), 0.055)
    mix(out, clack(0.18, 640.0, 0.80, seed=91, brightness=0.8), 0.06)
    mix(out, low_noise(0.22, 73, 3200, 1.4, curve=1.6), 0.055, 0.40)
    return out


def sfx_safe():
    """Safe square: soft sparkle - reassuring, not alarming."""
    out = new_buf(0.55)
    for i, f in enumerate((1318.5, 1760.0, 2637.0)):
        mix(out, bell(f, 0.42, 0.55 - i * 0.11, ratio=2.4, index=2.1,
                      seed=120 + i), i * 0.045)
    mix(out, band_noise(0.30, 81, 6000, 9500, q=1.6, curve=1.8), 0.0, 0.16)
    return reverb(out, 0.16, 0.55)


def sfx_home():
    """Token finishes: bright rising chime + sparkle tail."""
    out = new_buf(0.75)
    for i, f in enumerate((523.25, 659.25, 783.99, 1046.5)):
        mix(out, bell(f, 0.55, 0.62 - i * 0.08, ratio=2.0, index=2.4,
                      seed=140 + i), i * 0.062)
    mix(out, band_noise(0.40, 91, 5000, 10000, q=1.5, curve=1.7), 0.10, 0.20)
    return reverb(out, 0.22, 0.66)


def sfx_six():
    """Rolling a six: a special happy 'yes!' flourish."""
    out = new_buf(0.70)
    for i, f in enumerate((659.25, 830.61, 987.77)):
        mix(out, brass(f, 0.30, 0.55, attack=0.012, release=0.10), i * 0.085)
        mix(out, bell(f * 2, 0.34, 0.20, ratio=2.0, index=2.6,
                      seed=160 + i), i * 0.085)
    mix(out, shaker(0.10, 0.22, 22, 8000.0), 0.0)
    mix(out, shaker(0.10, 0.18, 23, 8000.0), 0.11)
    return reverb(out, 0.18, 0.6)


def sfx_turn():
    """Turn handover: gentle two-note attention blip."""
    out = new_buf(0.42)
    mix(out, flute(659.25, 0.16, 0.85, attack=0.014, release=0.07), 0.0)
    mix(out, flute(880.00, 0.24, 0.80, attack=0.014, release=0.12), 0.115)
    mix(out, bell(1760.0, 0.18, 0.14), 0.115)
    return reverb(out, 0.14, 0.5)


def sfx_invalid():
    """Illegal tap: short muted 'nope'."""
    out = new_buf(0.24)
    mix(out, flute(196.0, 0.10, 0.7, attack=0.004, release=0.05), 0.0)
    mix(out, flute(164.81, 0.16, 0.7, attack=0.004, release=0.09), 0.055)
    mix(out, low_noise(0.12, 31, 700, 1.2, curve=1.4), 0.0, 0.20)
    return out


def sfx_win():
    """Victory: short brass fanfare, final chord, sparkle and a cheer swell."""
    out = new_buf(2.20)
    melody = ((523.25, 0.00), (659.25, 0.11), (783.99, 0.22), (1046.50, 0.33))
    for f, at in melody:
        mix(out, brass(f, 0.42, 0.60, attack=0.010, release=0.14, vib=0.5), at)
        mix(out, bell(f * 2, 0.40, 0.16, ratio=2.0, index=2.8), at)
    chord = (523.25, 659.25, 783.99, 1046.50)
    for j, f in enumerate(chord):
        mix(out, brass(f, 1.45, 0.42, attack=0.02, release=0.55, vib=0.4),
            0.46 + j * 0.012)
        mix(out, bell(f, 1.50, 0.14, ratio=2.0, index=2.0), 0.46)
    # sparkle shower
    rng = random.Random(303)
    for i in range(16):
        at = 0.50 + rng.random() * 0.95
        f = rng.choice((1567.98, 2093.00, 2637.02, 3135.96))
        mix(out, bell(f, 0.42, 0.10, ratio=2.4, index=3.0, seed=400 + i), at)
    # crowd cheer swell
    mix(out, band_noise(1.30, 404, 700, 3200, q=1.1, curve=0.0), 0.46, 0.16)
    mix(out, low_noise(1.20, 405, 1400, 0.7, curve=0.0), 0.52, 0.14)
    mix(out, kick(0.30, 0.35, 150.0, 55.0), 0.46)
    return reverb(out, 0.26, 0.80)


def sfx_lose():
    """Losing: muted descending phrase - sympathetic, not punishing."""
    out = new_buf(1.30)
    for i, f in enumerate((523.25, 440.00, 349.23, 261.63)):
        mix(out, flute(f, 0.46, 0.68, attack=0.02, release=0.24), i * 0.19)
    mix(out, low_noise(0.60, 55, 500, 0.8, curve=0.6), 0.55, 0.16)
    return reverb(out, 0.20, 0.68)


def sfx_tap():
    """UI click: tiny, soft, unobtrusive."""
    return clack(0.045, 2400.0, 0.60, seed=71, brightness=1.1, body=False)


def sfx_coin():
    """Reward pickup: the classic two-note blip."""
    out = new_buf(0.42)
    mix(out, bell(987.77, 0.10, 0.85, ratio=2.0, index=1.6), 0.0)
    mix(out, bell(1318.51, 0.32, 0.85, ratio=2.0, index=1.6), 0.075)
    mix(out, bell(1975.53, 0.28, 0.20, ratio=2.0, index=2.4), 0.075)
    return out


def sfx_countdown():
    """Online turn timer: a soft tick."""
    return clack(0.07, 1180.0, 0.55, seed=81, brightness=0.9, body=False)


# --------------------------------------------------------------------------
# music loop
# --------------------------------------------------------------------------
NOTE = {"C3": 130.81, "D3": 146.83, "E3": 164.81, "G3": 196.00, "A3": 220.00,
        "C4": 261.63, "D4": 293.66, "E4": 329.63, "G4": 392.00, "A4": 440.00,
        "B4": 493.88, "C5": 523.25, "D5": 587.33, "E5": 659.25,
        "G5": 783.99, "A5": 880.00, "C6": 1046.50}


def sfx_music():
    """Four-bar, 100 BPM, seamless background loop (C major pentatonic)."""
    beat = 0.60
    bars = 4
    total = beat * 4 * bars
    out = new_buf(total)

    # lead: 8th-note pentatonic figure, rest on the last eighth of bar 4
    lead = ("C5", "E5", "G5", "E5", "D5", "E5", "C5", None,
            "D5", "F#5", "A5", "G5", "E5", "G5", "D5", None)
    lead = list(lead) * 1
    figure = (("C5", 0.5), ("E5", 0.5), ("G5", 0.5), ("E5", 0.5),
              ("D5", 1.0), ("C5", 0.5), (None, 1.0))
    lead = []
    for _ in range(bars):
        lead += figure

    bass_line = (("C3", 1.5), ("G3", 0.5), ("A3", 1.0), ("E3", 1.0))
    bass = bass_line * bars

    for bar in range(bars):
        bar_t = bar * beat * 4
        for i, (name, beats) in enumerate(lead[bar * 7:(bar + 1) * 7]):
            if name is None:
                continue
            at = bar_t + sum(b for _, b in lead[bar * 7:bar * 7 + i]) * beat
            dur = beats * beat
            mix(out, pluck(NOTE[name], dur * 0.9 + 0.10, 0.30, damp=0.9955,
                           seed=bar * 31 + i, bright=0.62), at)
            mix(out, bell(NOTE[name] * 2, dur * 0.5, 0.045, ratio=2.0,
                          index=2.0), at)
        for i, (name, beats) in enumerate(bass[bar * 4:(bar + 1) * 4]):
            at = bar_t + sum(b for _, b in bass[bar * 4:bar * 4 + i]) * beat
            mix(out, brass(NOTE[name], beats * beat * 0.8 + 0.12, 0.20,
                           attack=0.02, release=0.16), at)
        for eighth in range(8):
            at = bar_t + eighth * beat * 0.5
            amp = 0.085 if eighth % 2 else 0.045
            mix(out, shaker(0.055, amp, seed=200 + bar * 8 + eighth,
                            cutoff=7200.0), at)
        for b in (0, 2):
            mix(out, kick(0.20, 0.16, 140.0, 52.0), bar_t + b * beat)

    out = reverb(out, 0.20, 0.70, seed=9)

    # wrap the reverb tail back to the top of the loop for a seamless join
    tail_n = int(SR * 0.35)
    tail = out[-tail_n:]
    out = out[:-tail_n]
    for i, v in enumerate(tail):
        out[i % len(out)] += v
    return out


REGISTRY = (
    # name, generator, target RMS
    ("dice_throw", sfx_dice_throw, 0.130),
    ("dice_roll", sfx_dice_roll, 0.160),
    ("move", sfx_move, 0.075),
    ("release", sfx_release, 0.150),
    ("capture", sfx_capture, 0.185),
    ("safe", sfx_safe, 0.120),
    ("home", sfx_home, 0.140),
    ("six", sfx_six, 0.150),
    ("turn", sfx_turn, 0.110),
    ("invalid", sfx_invalid, 0.130),
    ("win", sfx_win, 0.170),
    ("lose", sfx_lose, 0.140),
    ("tap", sfx_tap, 0.050),
    ("coin", sfx_coin, 0.150),
    ("countdown", sfx_countdown, 0.060),
    ("music_loop", sfx_music, 0.075),
)


def main():
    os.makedirs(OUT_DIR, exist_ok=True)
    print("Generating %d files into %s" % (len(REGISTRY), os.path.normpath(OUT_DIR)))
    for name, fn, rms in REGISTRY:
        write_wav(name, fn(), rms, tail_ms=4.0 if name == "music_loop" else 6.0)
    print("Done.")


if __name__ == "__main__":
    main()
