import 'package:flutter/material.dart';

import 'screens/sound_check_screen.dart';
import 'theme/app_theme.dart';

/// Root widget. Kept deliberately thin: it wires the theme and the first
/// screen, nothing else, so navigation and state can be layered on later.
class PianoFlowApp extends StatelessWidget {
  const PianoFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Piano Flow',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      home: const SoundCheckScreen(),
    );
  }
}
