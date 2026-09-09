import 'package:flutter/material.dart';

import '../audio/piano_audio.dart';
import '../data/song_library.dart';
import '../game/chart.dart';
import '../game/judgement.dart';
import '../music/song.dart';
import '../theme/app_theme.dart';
import 'play_screen.dart';

/// Stamped in at build time, so a phone can say which version it is running.
const String buildId =
    String.fromEnvironment('BUILD_ID', defaultValue: 'geliştirme');

/// The song browser.
///
/// Every song is open from the first launch. Nothing is locked, nothing costs
/// anything — which is the deliberate opposite of the game this one takes
/// after, whose players' loudest complaint is that they replay the same few
/// free songs forever.
class SongListScreen extends StatefulWidget {
  const SongListScreen({super.key});

  @override
  State<SongListScreen> createState() => _SongListScreenState();
}

class _SongListScreenState extends State<SongListScreen> {
  @override
  void initState() {
    super.initState();
    // Start pulling the recorded piano in while the player is still reading
    // the list, so the first song is already played on it.
    PianoAudio().loadSamples();
  }

  Difficulty _difficulty = Difficulty.normal;

  /// Speeds offered, as a fraction of the written tempo.
  static const List<double> _speeds = [0.4, 0.6, 0.8, 1.0];

  /// Full speed by default: the songs are written at the tempo they are
  /// actually played at and should sound that way on the first press. Slowing
  /// down is a practice tool, one tap away, for the pieces that outrun a hand
  /// — which at their real tempo, Chopin's and Beethoven's both do.
  double _speed = 1.0;

  /// The player's own timing calibration, in milliseconds, on top of whatever
  /// the device reports about its own audio delay.
  ///
  /// It has to be adjustable because no device tells the truth about this.
  /// A browser reports what it knows about; it cannot know about Bluetooth
  /// headphones, and it says nothing about the player's own hand, which
  /// reliably arrives a little after the eye says to move.
  double _latencyOffsetMs = 0;

  /// Steps of the calibration, and how far it goes either way.
  static const double _latencyStep = 10;
  static const double _latencyLimit = 300;

  /// Forgiving by default, and the music kept in time by default: the game
  /// should flatter a beginner before it tests one.
  TimingTolerance _tolerance = TimingTolerance.wide;
  bool _quantize = true;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
          children: [
            Text(
              'Piano Flow',
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                // Flexible, not fixed: on a narrow phone the tagline has to
                // give way rather than push the build stamp off the screen.
                const Flexible(
                  child: Text(
                    'Işığa dokun, notayı çal',
                    style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                // Which build this is. Without it there is no way to tell a
                // fix that did not work from a fix that never arrived.
                Text(
                  buildId,
                  style: TextStyle(
                    color: AppTheme.textMuted.withValues(alpha: 0.5),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            _DifficultyPicker(
              selected: _difficulty,
              onChanged: (value) => setState(() => _difficulty = value),
            ),
            const SizedBox(height: 20),
            _SpeedPicker(
              speeds: _speeds,
              selected: _speed,
              onChanged: (value) => setState(() => _speed = value),
            ),
            const SizedBox(height: 20),
            _TolerancePicker(
              selected: _tolerance,
              onChanged: (value) => setState(() => _tolerance = value),
            ),
            const SizedBox(height: 14),
            _QuantizeSwitch(
              value: _quantize,
              onChanged: (value) => setState(() => _quantize = value),
            ),
            const SizedBox(height: 14),
            _LatencyPicker(
              offsetMs: _latencyOffsetMs,
              onChanged: (value) => setState(() => _latencyOffsetMs =
                  value.clamp(-_latencyLimit, _latencyLimit)),
              step: _latencyStep,
            ),
            const SizedBox(height: 24),
            for (final song in SongLibrary.all)
              _SongTile(
                song: song,
                difficulty: _difficulty,
                speed: _speed,
                tolerance: _tolerance,
                quantize: _quantize,
                latencyOffsetMs: _latencyOffsetMs,
              ),
            const SizedBox(height: 8),
            // The recorded piano is CC BY: the credit is a condition of using
            // it, not a courtesy, so it ships in the app and not only in the
            // repository.
            const Text(
              'Piyano sesleri: Salamander Grand Piano — Alexander Holm, '
              'CC BY 3.0',
              style: TextStyle(color: AppTheme.textMuted, fontSize: 11),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

/// Chooses how much of the song is the player's to play.
class _DifficultyPicker extends StatelessWidget {
  const _DifficultyPicker({required this.selected, required this.onChanged});

  final Difficulty selected;
  final ValueChanged<Difficulty> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final difficulty in Difficulty.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: difficulty.label,
                    selected: difficulty == selected,
                    onTap: () => onChanged(difficulty),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selected.description,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

/// Chooses how fast the song runs.
///
/// Slowing a piece down is how anyone learns one; the game should offer it
/// before a beginner concludes they simply cannot play.
class _SpeedPicker extends StatelessWidget {
  const _SpeedPicker({
    required this.speeds,
    required this.selected,
    required this.onChanged,
  });

  final List<double> speeds;
  final double selected;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final speed in speeds)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: speed == 1.0 ? 'Tam hız' : '%${(speed * 100).round()}',
                    selected: speed == selected,
                    onTap: () => onChanged(speed),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          selected == 1.0
              ? 'Şarkının kendi temposu'
              : 'Yavaşlatılmış — notalar arasında daha çok zaman',
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

/// Nudges when the game thinks a tap happened.
///
/// The device is asked how far behind its own audio is and that is used
/// automatically, but no device knows the whole answer: not what Bluetooth
/// adds, and not the player's own hand, which arrives a little after the eye
/// says to move. This is the part only the person playing can supply.
///
/// The sign is written out rather than left as a number, because "+40 ms" is
/// meaningless to anyone who has not built a rhythm game.
class _LatencyPicker extends StatelessWidget {
  const _LatencyPicker({
    required this.offsetMs,
    required this.onChanged,
    required this.step,
  });

  final double offsetMs;
  final ValueChanged<double> onChanged;
  final double step;

  @override
  Widget build(BuildContext context) {
    final rounded = offsetMs.round();
    final description = rounded == 0
        ? 'Cihazın bildirdiği gecikme kullanılıyor'
        : rounded > 0
            ? 'Dokunuşların $rounded ms erken sayılıyor'
            : 'Dokunuşların ${-rounded} ms geç sayılıyor';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Zamanlama ayarı',
                style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
              ),
            ),
            _StepButton(
              icon: Icons.remove,
              onTap: () => onChanged(offsetMs - step),
            ),
            SizedBox(
              width: 68,
              child: Text(
                '${rounded > 0 ? '+' : ''}$rounded ms',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppTheme.textPrimary, fontSize: 14),
              ),
            ),
            _StepButton(
              icon: Icons.add,
              onTap: () => onChanged(offsetMs + step),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          description,
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
        const SizedBox(height: 2),
        const Text(
          'Her şey geç sayılıyorsa artırın',
          style: TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(icon, size: 18, color: AppTheme.textPrimary),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? AppTheme.accent.withValues(alpha: 0.30)
          : AppTheme.surface.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected ? AppTheme.accentSoft : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppTheme.textPrimary : AppTheme.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Chooses how forgiving the judging is.
class _TolerancePicker extends StatelessWidget {
  const _TolerancePicker({required this.selected, required this.onChanged});

  final TimingTolerance selected;
  final ValueChanged<TimingTolerance> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final tolerance in TimingTolerance.values)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: tolerance.label,
                    selected: tolerance == selected,
                    onTap: () => onChanged(tolerance),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Tolerans — ${selected.description.toLowerCase()}',
          style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
        ),
      ],
    );
  }
}

/// Whether the music is kept in time regardless of the hand.
class _QuantizeSwitch extends StatelessWidget {
  const _QuantizeSwitch({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Notalar tam zamanında çalsın',
                style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
              ),
              const SizedBox(height: 2),
              Text(
                value
                    ? 'Erken basarsan nota vuruşu bekler'
                    : 'Nota parmağın değdiği anda çalar',
                style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
              ),
            ],
          ),
        ),
        Switch(
          value: value,
          activeThumbColor: AppTheme.accentSoft,
          onChanged: onChanged,
        ),
      ],
    );
  }
}

class _SongTile extends StatelessWidget {
  const _SongTile({
    required this.song,
    required this.difficulty,
    required this.speed,
    required this.tolerance,
    required this.quantize,
    required this.latencyOffsetMs,
  });

  final Song song;
  final Difficulty difficulty;
  final double speed;
  final TimingTolerance tolerance;
  final bool quantize;
  final double latencyOffsetMs;

  @override
  Widget build(BuildContext context) {
    final length = song.duration.inSeconds ~/ speed;
    final minutes = length ~/ 60;
    final seconds = length % 60;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppTheme.surface.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => PlayScreen(
                song: song,
                difficulty: difficulty,
                speed: speed,
                tolerance: tolerance,
                quantize: quantize,
                latencyOffsetMs: latencyOffsetMs,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        song.composer,
                        style: const TextStyle(
                            fontSize: 13, color: AppTheme.textMuted),
                      ),
                    ],
                  ),
                ),
                Text(
                  '$minutes:${seconds.toString().padLeft(2, '0')}',
                  style: const TextStyle(
                      fontSize: 13, color: AppTheme.textMuted),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.play_arrow_rounded,
                    color: AppTheme.accentSoft, size: 26),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
