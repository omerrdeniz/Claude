import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The ground the game is played on, coloured by the GPU.
///
/// Everything this game has wanted and not had — glow, bloom, a background
/// that moves, a different atmosphere for each piece — it has gone without
/// for one reason: drawn on the CPU, a single blur costs more per frame than
/// every note on screen put together. A fragment shader colours every pixel
/// at once and asks nothing of the frame budget.
///
/// **Loaded once and shared, and everything works without it.** Shaders are
/// the one part of this that a platform can simply refuse — the game is
/// played in a browser, and what a browser will compile is not ours to
/// decide. So this hands back null on any failure and the painter draws the
/// gradient it always drew. A missing shader must never be a missing game.
abstract final class StageShader {
  static ui.FragmentProgram? _program;
  static bool _tried = false;

  /// Whether the shader is compiled and ready.
  static bool get ready => _program != null;

  /// Whether the platform has been asked yet.
  static bool get tried => _tried;

  /// Compile it, once. Safe to call from anywhere, as often as you like.
  static Future<void> load() async {
    if (_tried) return;
    _tried = true;
    try {
      _program = await ui.FragmentProgram.fromAsset('shaders/stage.frag');
    } catch (_) {
      // Left null on purpose: the painter falls back and the game plays.
      _program = null;
    }
  }

  /// A shader for one frame, or null if there is none to be had.
  ///
  /// The uniforms go in the order the shader declares them, which is the only
  /// way they can be set — a vec2 takes two slots, a vec3 three. Getting this
  /// wrong shows up as colours that make no sense rather than as an error,
  /// so the order here and in `shaders/stage.frag` have to be read together.
  static ui.FragmentShader? forStage({
    required Size size,
    required double seconds,
    required double heat,
    required Color top,
    required Color bottom,
    required Color glow,
    required double hitLineFraction,
  }) {
    final program = _program;
    if (program == null) return null;

    final shader = program.fragmentShader();
    var at = 0;
    void number(double value) => shader.setFloat(at++, value);
    void colour(Color c) {
      number(c.r);
      number(c.g);
      number(c.b);
    }

    number(size.width);
    number(size.height);
    number(seconds);
    number(heat);
    colour(top);
    colour(bottom);
    colour(glow);
    number(hitLineFraction);
    return shader;
  }
}
