import struct, sys, collections

def varint(b, i):
    v = s = 0
    while True:
        x = b[i]; i += 1
        v |= (x & 0x7f) << s
        if not x & 0x80: return v, i
        s += 7

def fields(b, i=0):
    while i < len(b):
        key, i = varint(b, i)
        f, wt = key >> 3, key & 7
        if wt == 0:   v, i = varint(b, i)
        elif wt == 5: v, = struct.unpack('<f', b[i:i+4]); i += 4
        elif wt == 2:
            n, i = varint(b, i); v = b[i:i+n]; i += n
        else: raise ValueError(wt)
        yield f, wt, v

PITCH_OFFSET = -2       # the grid row that sounds as MIDI note n is n-2
UNITS_PER_QUARTER = 8   # a grid unit is a sixteenth
BPM = 150               # so a unit lasts 0.05 s, which is what the site plays
TPB = 480
SPLIT = 60              # middle C: below it is the left hand

raw = open(sys.argv[1], 'rb').read()
notes = []
for f, wt, v in fields(raw):
    if f == 2 and wt == 2:
        n = {ff: vv for ff, _, vv in fields(v)}
        if 2 not in n or 3 not in n: continue
        notes.append((n[2], n[1] + PITCH_OFFSET, n[3], n.get(5, 0.63)))
notes.sort()

def track(sel):
    events = []
    for start, pitch, length, vol in notes:
        if not sel(pitch): continue
        t0 = round(start / UNITS_PER_QUARTER * TPB)
        t1 = round((start + length) / UNITS_PER_QUARTER * TPB)
        v = max(1, min(127, round(vol * 127)))
        events.append((t0, 1, pitch, v))
        events.append((max(t1, t0 + 1), 0, pitch, 0))
    events.sort(key=lambda e: (e[0], e[1], e[2]))
    body, prev = bytearray(), 0
    for t, on, pitch, v in events:
        d = t - prev
        vlq = bytearray([d & 0x7f]); d >>= 7
        while d: vlq.insert(0, (d & 0x7f) | 0x80); d >>= 7
        body += vlq + bytes([0x90 if on else 0x80, pitch, v])
        prev = t
    return bytes(body) + b'\x00\xff\x2f\x00'

def chunk(tag, body):
    return tag + struct.pack('>I', len(body)) + body

us = round(60000000 / BPM)
tempo = (b'\x00\xff\x51\x03' + bytes([us >> 16 & 255, us >> 8 & 255, us & 255])
         + b'\x00\xff\x58\x04\x04\x02\x18\x08' + b'\x00\xff\x2f\x00')

out = (chunk(b'MThd', struct.pack('>HHH', 1, 3, TPB))
       + chunk(b'MTrk', tempo)
       + chunk(b'MTrk', track(lambda p: p >= SPLIT))
       + chunk(b'MTrk', track(lambda p: p < SPLIT)))
open(sys.argv[2], 'wb').write(out)

hi = sum(1 for _, p, _, _ in notes if p >= SPLIT)
print(f'{len(notes)} nota ({hi} sağ / {len(notes) - hi} sol), '
      f'perde {min(p for _, p, _, _ in notes)}..{max(p for _, p, _, _ in notes)}, '
      f'{max(s + l for s, _, l, _ in notes) / UNITS_PER_QUARTER / BPM * 60:.1f} saniye')
