# Turns an Online Sequencer sequence into a Standard MIDI file.
#
#     curl -o seq.bin 'https://onlinesequencer.net/app/api/get_proto.php?v=2&id=<ID>&r=2'
#     python3 tool/onlinesequencer_to_midi.py seq.bin out.mid
#
# Some music reaches us as a sequence rather than as an engraving — somebody
# typed it in rather than a publisher setting it. The site holds it as
# protobuf; this reads that and writes the notes out as MIDI, so the song
# takes the same road into the library as everything else.
#
# What the format turned out to be, worked out by hand from the bytes:
#
#   field 1        settings; its own field 1 is the tempo in quarters
#   field 2        one per note
#     field 1      grid row
#     field 2      onset, in grid units
#     field 3      length, in grid units
#     field 5      volume, 0..1
#
# Two things are not written down anywhere and had to be measured:
#
#   - A grid row sounds two semitones below the MIDI note of the same number.
#     Found by trying every offset against the key: one of them put 99% of
#     the notes in G minor and the rest nowhere.
#   - A grid unit is a sixteenth. Found by checking the total against the
#     duration the page reports for itself; nothing else lands on it.
import struct, sys

PITCH_OFFSET = -2
UNITS_PER_QUARTER = 4
TICKS_PER_BEAT = 480
HAND_SPLIT = 60  # middle C: below it is the left hand


def _varint(b, i):
    v = s = 0
    while True:
        x = b[i]; i += 1
        v |= (x & 0x7f) << s
        if not x & 0x80:
            return v, i
        s += 7


def _fields(b):
    i = 0
    while i < len(b):
        key, i = _varint(b, i)
        f, wt = key >> 3, key & 7
        if wt == 0:
            v, i = _varint(b, i)
        elif wt == 5:
            v, = struct.unpack('<f', b[i:i + 4]); i += 4
        elif wt == 2:
            n, i = _varint(b, i); v = b[i:i + n]; i += n
        else:
            raise ValueError(f'unknown wiretype {wt}')
        yield f, wt, v


def read(raw):
    """(bpm, [(onset, midi, length, volume)]) — times in grid units."""
    bpm, notes = 120.0, []
    for f, wt, v in _fields(raw):
        if f == 1 and wt == 2:
            for sf, swt, sv in _fields(v):
                if sf == 1 and swt == 0:
                    bpm = float(sv)
        elif f == 2 and wt == 2:
            n = {sf: sv for sf, _, sv in _fields(v)}
            if 2 in n and 3 in n:
                notes.append((n[2], n[1] + PITCH_OFFSET, n[3], n.get(5, 0.63)))
    notes.sort()
    return bpm, notes


def _vlq(n):
    out = bytearray([n & 0x7f]); n >>= 7
    while n:
        out.insert(0, (n & 0x7f) | 0x80); n >>= 7
    return out


def _track(notes, keep):
    events = []
    for onset, pitch, length, volume in notes:
        if not keep(pitch):
            continue
        start = round(onset / UNITS_PER_QUARTER * TICKS_PER_BEAT)
        end = round((onset + length) / UNITS_PER_QUARTER * TICKS_PER_BEAT)
        v = max(1, min(127, round(volume * 127)))
        events.append((start, 1, pitch, v))
        events.append((max(end, start + 1), 0, pitch, 0))
    events.sort(key=lambda e: (e[0], e[1], e[2]))

    body, previous = bytearray(), 0
    for tick, on, pitch, v in events:
        body += _vlq(tick - previous) + bytes([0x90 if on else 0x80, pitch, v])
        previous = tick
    return bytes(body) + b'\x00\xff\x2f\x00'


def _chunk(tag, body):
    return tag + struct.pack('>I', len(body)) + body


def to_midi(bpm, notes):
    us = round(60000000 / bpm)
    tempo = (b'\x00\xff\x51\x03'
             + bytes([us >> 16 & 255, us >> 8 & 255, us & 255])
             + b'\x00\xff\x58\x04\x04\x02\x18\x08'
             + b'\x00\xff\x2f\x00')
    # Two note tracks, because that is how the reader tells the hands apart.
    return (_chunk(b'MThd', struct.pack('>HHH', 1, 3, TICKS_PER_BEAT))
            + _chunk(b'MTrk', tempo)
            + _chunk(b'MTrk', _track(notes, lambda p: p >= HAND_SPLIT))
            + _chunk(b'MTrk', _track(notes, lambda p: p < HAND_SPLIT)))


if __name__ == '__main__':
    bpm, notes = read(open(sys.argv[1], 'rb').read())
    open(sys.argv[2], 'wb').write(to_midi(bpm, notes))
    seconds = max(o + l for o, _, l, _ in notes) / UNITS_PER_QUARTER / bpm * 60
    right = sum(1 for _, p, _, _ in notes if p >= HAND_SPLIT)
    print(f'{len(notes)} nota ({right} sağ / {len(notes) - right} sol), '
          f'{bpm:g} bpm, {seconds:.1f} saniye')
