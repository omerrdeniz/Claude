import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/music/note.dart';
import 'package:piano_flow/render/hit_sparks.dart';

void main() {
  Spark hit({double across = 0.5}) =>
      Spark(places: [across], hand: Hand.right, voices: 1, quality: 1);

  test('a spark burns out on its own', () {
    final field = SparkField(lifeMs: 100);
    field.add(hit());
    field.advance(50);
    expect(field.sparks.single.age, closeTo(0.5, 1e-9));
    field.advance(60);
    expect(field.isEmpty, isTrue);
  });

  test('a dense passage cannot pile them up', () {
    // Chopin throws a dozen a second; an uncapped list is a way to make the
    // game stutter exactly where it should feel best.
    final field = SparkField(limit: 4);
    for (var i = 0; i < 40; i++) {
      field.add(hit(across: i / 40));
    }
    expect(field.sparks, hasLength(4));
    expect(field.sparks.first.places.single, closeTo(36 / 40, 1e-9),
        reason: 'the oldest go first');
  });

  test('advancing an empty field is harmless', () {
    final field = SparkField()..advance(16);
    expect(field.isEmpty, isTrue);
  });

  test('clearing takes everything', () {
    final field = SparkField()..add(hit());
    field.clear();
    expect(field.isEmpty, isTrue);
  });
}
