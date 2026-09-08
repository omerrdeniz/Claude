import 'package:flutter/material.dart';

import '../audio/piano_audio.dart';
import '../theme/app_theme.dart';
import '../widgets/piano_keyboard.dart';

/// Temporary screen for hearing the synthesiser on a real device.
///
/// It is not the game — it exists so the audio path can be judged by ear
/// before any gameplay is built on top of it. The keyboard widget itself will
/// survive into the free-play mode.
class SoundCheckScreen extends StatefulWidget {
  const SoundCheckScreen({super.key});

  @override
  State<SoundCheckScreen> createState() => _SoundCheckScreenState();
}

class _SoundCheckScreenState extends State<SoundCheckScreen> {
  final PianoAudio _audio = PianoAudio();
  bool _audioReady = false;
  bool _checked = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    final ok = await _audio.start();
    if (!mounted) return;
    setState(() {
      _audioReady = ok;
      _checked = true;
    });
  }

  @override
  void dispose() {
    _audio.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Piano Flow',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.2,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _statusText,
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 13),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: PianoKeyboard(
                  lowestNote: 60,
                  octaves: 2,
                  onNoteOn: _audio.noteOn,
                  onNoteOff: _audio.noteOff,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String get _statusText {
    if (!_checked) return 'ses açılıyor…';
    if (!_audioReady) {
      return PianoAudio.isSupported
          ? 'ses açılamadı — cihaz sesi reddetti'
          : 'bu platformda ses yok (iOS, Android ve macOS destekleniyor)';
    }
    return 'ses testi — tuşlara dokun, aşağıya bastıkça daha sert çalar';
  }
}
