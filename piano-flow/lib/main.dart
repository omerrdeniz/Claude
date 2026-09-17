import 'package:flutter/material.dart';

import 'app.dart';
import 'render/stage_shader.dart';

void main() {
  // Compiled once, at the start, rather than when the first song opens: it
  // takes a moment, and the moment a song opens is the worst one to spend.
  // Nothing waits on it — the playfield draws a plain gradient until it is
  // ready, and for good on any platform that will not have it.
  WidgetsFlutterBinding.ensureInitialized();
  StageShader.load();
  runApp(const PianoFlowApp());
}
