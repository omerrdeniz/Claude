import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A multi-touch piano keyboard.
///
/// Two details make it feel like an instrument rather than a row of buttons:
/// several keys can be held at once, and how far down the key you press sets
/// the velocity, so the same key can be played softly or hard.
class PianoKeyboard extends StatefulWidget {
  const PianoKeyboard({
    super.key,
    required this.onNoteOn,
    required this.onNoteOff,
    this.lowestNote = 60,
    this.octaves = 2,
  });

  /// Called with a MIDI note number and a velocity in 0..1.
  final void Function(int midi, {double velocity}) onNoteOn;
  final void Function(int midi) onNoteOff;

  /// MIDI note the keyboard starts on. Must be a C for the layout to line up.
  final int lowestNote;
  final int octaves;

  @override
  State<PianoKeyboard> createState() => _PianoKeyboardState();
}

class _PianoKeyboardState extends State<PianoKeyboard> {
  /// Which note each active pointer is holding, so lifting one finger releases
  /// only its own key.
  final Map<int, int> _pointerNotes = {};

  static const List<int> _whiteOffsets = [0, 2, 4, 5, 7, 9, 11];
  static const List<int> _blackOffsets = [1, 3, 6, 8, 10];

  int get _whiteCount => widget.octaves * 7;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final whiteWidth = width / _whiteCount;
        final blackWidth = whiteWidth * 0.62;
        final blackHeight = height * 0.6;

        return Listener(
          onPointerDown: (e) => _press(e.pointer, e.localPosition, whiteWidth,
              blackWidth, blackHeight, height),
          onPointerMove: (e) => _slide(e.pointer, e.localPosition, whiteWidth,
              blackWidth, blackHeight, height),
          onPointerUp: (e) => _lift(e.pointer),
          onPointerCancel: (e) => _lift(e.pointer),
          child: Stack(
            children: [
              Row(
                children: [
                  for (var i = 0; i < _whiteCount; i++)
                    _Key(
                      width: whiteWidth,
                      height: height,
                      isBlack: false,
                      pressed: _isHeld(_whiteNote(i)),
                    ),
                ],
              ),
              for (final pos in _blackKeyPositions(whiteWidth))
                Positioned(
                  left: pos.$1 - blackWidth / 2,
                  top: 0,
                  child: _Key(
                    width: blackWidth,
                    height: blackHeight,
                    isBlack: true,
                    pressed: _isHeld(pos.$2),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  bool _isHeld(int midi) => _pointerNotes.containsValue(midi);

  int _whiteNote(int index) =>
      widget.lowestNote + (index ~/ 7) * 12 + _whiteOffsets[index % 7];

  /// Centre x and MIDI note of every black key.
  List<(double, int)> _blackKeyPositions(double whiteWidth) {
    final out = <(double, int)>[];
    for (var octave = 0; octave < widget.octaves; octave++) {
      for (final offset in _blackOffsets) {
        // A black key sits on the boundary between the two white keys it
        // divides; that boundary is the index of the white key below it, +1.
        final whiteBelow = _whiteOffsets.lastIndexWhere((w) => w < offset);
        final x = (octave * 7 + whiteBelow + 1) * whiteWidth;
        out.add((x, widget.lowestNote + octave * 12 + offset));
      }
    }
    return out;
  }

  int? _noteAt(Offset p, double whiteWidth, double blackWidth,
      double blackHeight, double height) {
    // Black keys sit on top, so they win wherever they overlap.
    if (p.dy <= blackHeight) {
      for (final (x, midi) in _blackKeyPositions(whiteWidth)) {
        if ((p.dx - x).abs() <= blackWidth / 2) return midi;
      }
    }
    final index = (p.dx / whiteWidth).floor();
    if (index < 0 || index >= _whiteCount) return null;
    return _whiteNote(index);
  }

  /// Pressing further down the key plays harder, like a real keybed.
  double _velocityFor(Offset p, double height) =>
      (0.35 + (p.dy / height) * 0.65).clamp(0.1, 1.0);

  void _press(int pointer, Offset p, double whiteWidth, double blackWidth,
      double blackHeight, double height) {
    final midi = _noteAt(p, whiteWidth, blackWidth, blackHeight, height);
    if (midi == null) return;
    setState(() => _pointerNotes[pointer] = midi);
    widget.onNoteOn(midi, velocity: _velocityFor(p, height));
  }

  /// Sliding a finger across the keys glissandos, releasing the old note.
  void _slide(int pointer, Offset p, double whiteWidth, double blackWidth,
      double blackHeight, double height) {
    if (!_pointerNotes.containsKey(pointer)) return;
    final midi = _noteAt(p, whiteWidth, blackWidth, blackHeight, height);
    if (midi == null || midi == _pointerNotes[pointer]) return;
    final previous = _pointerNotes[pointer]!;
    widget.onNoteOff(previous);
    setState(() => _pointerNotes[pointer] = midi);
    widget.onNoteOn(midi, velocity: _velocityFor(p, height));
  }

  void _lift(int pointer) {
    final midi = _pointerNotes.remove(pointer);
    if (midi == null) return;
    setState(() {});
    widget.onNoteOff(midi);
  }
}

class _Key extends StatelessWidget {
  const _Key({
    required this.width,
    required this.height,
    required this.isBlack,
    required this.pressed,
  });

  final double width;
  final double height;
  final bool isBlack;
  final bool pressed;

  @override
  Widget build(BuildContext context) {
    final Color base = isBlack ? const Color(0xFF14141F) : const Color(0xFFF4F4FA);
    return AnimatedContainer(
      duration: const Duration(milliseconds: 60),
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: pressed ? Color.lerp(base, AppTheme.accent, 0.55) : base,
        border: Border.all(color: AppTheme.background, width: 1),
        borderRadius: BorderRadius.vertical(
          bottom: Radius.circular(isBlack ? 5 : 7),
        ),
        boxShadow: pressed
            ? [BoxShadow(color: AppTheme.accent.withValues(alpha: 0.5), blurRadius: 14)]
            : null,
      ),
    );
  }
}
