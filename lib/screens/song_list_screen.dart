import 'package:flutter/material.dart';

import '../audio/piano_audio.dart';
import '../data/song_library.dart';
import '../game/chart.dart';
import '../game/judgement.dart';
import '../game/play_settings.dart';
import '../theme/app_theme.dart';
import 'calibration_screen.dart';
import 'song_list/settings.dart';
import 'song_list/song_tile.dart';

/// Stamped in at build time, so a phone can say which version it is running.
///
/// The number is how many commits the branch has, which makes it comparable
/// at a glance — v51 is plainly newer than v50, where two commit hashes are
/// not. The hash is kept beside it because that is what actually identifies
/// the build. Both come from `tool/deploy.sh`.
const String appVersion =
    String.fromEnvironment('APP_VERSION', defaultValue: '');
const String buildId =
    String.fromEnvironment('BUILD_ID', defaultValue: 'geliştirme');

/// What the player reads at the top of the list, and quotes back when a fix
/// does not seem to have arrived.
String get versionLabel =>
    appVersion.isEmpty ? buildId : 'v$appVersion · $buildId';

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

  /// Everything the player has chosen, in one place.
  ///
  /// The defaults are [PlaySettings]'s own, and the reasoning for each of
  /// them lives there beside the value it explains.
  PlaySettings _settings = const PlaySettings();

  /// Speeds offered, as a fraction of the written tempo.
  static const List<double> _speeds = [0.4, 0.6, 0.8, 1.0];

  /// Steps of the calibration, and how far it goes either way.
  static const double _latencyStep = 10;
  static const double _latencyLimit = 300;

  void _set(PlaySettings settings) => setState(() => _settings = settings);

  void _setLatency(double value) => _set(_settings.copyWith(
      latencyOffsetMs: value.clamp(-_latencyLimit, _latencyLimit)));

  Future<void> _measureLatency() async {
    final measured = await Navigator.of(context).push<double>(
      MaterialPageRoute(builder: (_) => const CalibrationScreen()),
    );
    if (measured != null) _setLatency(measured);
  }

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
                // Which build this is. Without it there is no way to tell
                // a fix that did not work from a fix that never arrived —
                // and it has to be legible to do that job. It was set at
                // half the muted colour and the player could not find it.
                Text(
                  versionLabel,
                  style: const TextStyle(
                    color: AppTheme.accentSoft,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            ChoiceRow<Difficulty>(
              options: Difficulty.values,
              selected: _settings.difficulty,
              labelOf: (difficulty) => difficulty.label,
              caption: _settings.difficulty.description,
              onChanged: (value) => _set(_settings.copyWith(difficulty: value)),
            ),
            const SizedBox(height: 20),
            ChoiceRow<double>(
              options: _speeds,
              selected: _settings.speed,
              labelOf: (speed) =>
                  speed == 1.0 ? 'Tam hız' : '%${(speed * 100).round()}',
              caption: _settings.speed == 1.0
                  ? 'Şarkının kendi temposu'
                  : 'Yavaşlatılmış — notalar arasında daha çok zaman',
              onChanged: (value) => _set(_settings.copyWith(speed: value)),
            ),
            const SizedBox(height: 20),
            ChoiceRow<TimingTolerance>(
              options: TimingTolerance.values,
              selected: _settings.tolerance,
              labelOf: (tolerance) => tolerance.label,
              caption: 'Tolerans — '
                  '${_settings.tolerance.description.toLowerCase()}',
              onChanged: (value) => _set(_settings.copyWith(tolerance: value)),
            ),
            const SizedBox(height: 14),
            SettingSwitch(
              title: 'Notalar tam zamanında çalsın',
              subtitle: _settings.quantize
                  ? 'Erken basarsan nota vuruşu bekler'
                  : 'Nota parmağın değdiği anda çalar',
              value: _settings.quantize,
              onChanged: (value) => _set(_settings.copyWith(quantize: value)),
            ),
            const SizedBox(height: 14),
            SettingSwitch(
              title: 'Kaçırdıklarım da duyulsun',
              subtitle: _settings.fillMissed
                  ? 'Basmadığın her nota kısık çalar — hiç basmazsan '
                      'şarkı kendi çalar'
                  : 'Yalnız senin bastığın notalar duyulur',
              value: _settings.fillMissed,
              onChanged: (value) => _set(_settings.copyWith(fillMissed: value)),
            ),
            const SizedBox(height: 14),
            LatencyPicker(
              offsetMs: _settings.latencyOffsetMs,
              onChanged: _setLatency,
              step: _latencyStep,
              onMeasure: _measureLatency,
            ),
            const SizedBox(height: 24),
            for (final info in SongLibrary.all)
              SongTile(info: info, settings: _settings),
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
