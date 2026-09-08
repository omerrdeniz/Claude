import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:piano_flow/game/judgement.dart';
import 'package:piano_flow/widgets/result_panel.dart';

void main() {
  Scoreboard boardWith({int perfect = 0, int great = 0, int miss = 0}) {
    final board = Scoreboard();
    for (var i = 0; i < perfect; i++) {
      board.register(Verdict.perfect);
    }
    for (var i = 0; i < great; i++) {
      board.register(Verdict.great);
    }
    for (var i = 0; i < miss; i++) {
      board.register(Verdict.miss);
    }
    return board;
  }

  Future<void> pumpPanel(WidgetTester tester, Scoreboard board) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResultPanel(
          scoreboard: board,
          songTitle: 'Für Elise',
          onReplay: () {},
          onBack: () {},
        ),
      ),
    ));
  }

  testWidgets('reports the grade, score and what went wrong', (tester) async {
    final board = boardWith(perfect: 8, great: 2);
    await pumpPanel(tester, board);

    expect(find.text('Für Elise'), findsOneWidget);
    expect(find.text(board.grade), findsOneWidget);
    expect(find.text('${board.score}'), findsOneWidget);
    expect(find.text('%${(board.accuracy * 100).round()}'), findsOneWidget);
    // Every verdict is listed, so the player can see what to work on.
    for (final verdict in Verdict.values) {
      expect(find.text(verdict.label), findsOneWidget);
    }
  });

  testWidgets('offers a replay and a way back', (tester) async {
    var replayed = false;
    var wentBack = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ResultPanel(
          scoreboard: boardWith(perfect: 3),
          songTitle: 'Test',
          onReplay: () => replayed = true,
          onBack: () => wentBack = true,
        ),
      ),
    ));

    await tester.tap(find.text('Tekrar çal'));
    expect(replayed, isTrue);
    await tester.tap(find.text('Şarkılar'));
    expect(wentBack, isTrue);
  });

  testWidgets('a performance with no notes played still renders', (tester) async {
    await pumpPanel(tester, Scoreboard());
    expect(find.text('-'), findsOneWidget, reason: 'no grade to give yet');
  });
}
