import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/player/screens/full_player_screen.dart';
import 'package:flick/features/player/widgets/flowing_background_vocal_subline.dart';
import 'package:flick/features/player/widgets/lyric_motion_line.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_service.dart';

/// Render the real full-player widget with a clock, without starting audio.
class _FakePlayer implements PlayerService {
  @override
  final positionNotifier = ValueNotifier<Duration>(Duration.zero);
  @override
  final isPlayingNotifier = ValueNotifier<bool>(false);
  @override
  final playbackSpeedNotifier = ValueNotifier<double>(1.0);
  @override
  Future<void> seek(Duration position) async {
    positionNotifier.value = position;
  }
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

/// Copyright-free text; timestamp positions are copied from the real FLAC.
const _flacLyrics = LyricsData(
  isSynchronized: true,
  rawContent: '',
  source: 'embedded:vorbis',
  lines: [
    LyricsLine(
      timestamp: Duration(milliseconds: 284418),
      text: 'Lead 04:44.418',
      backgroundText: 'Supporting vocal',
      backgroundWords: [
        LyricsWord(
          start: Duration(milliseconds: 286325),
          end: Duration(milliseconds: 291269),
          text: 'Supporting vocal',
        ),
      ],
    ),
    LyricsLine(
      timestamp: Duration(milliseconds: 292122),
      text: 'Next lead 04:52.122',
    ),
  ],
);

void main() {
  Future<_FakePlayer> render(
    WidgetTester tester, Duration position,
  ) async {
    final player = _FakePlayer()..positionNotifier.value = position;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 610,
            child: flowingLyricsRendererForTest(
              player: player,
              lyrics: _flacLyrics,
            ),
          ),
        ),
      ),
    );
    // _FlowingLyrics positions its stack using an actual frame ticker.
    await tester.pump(const Duration(milliseconds: 90));
    return player;
  }

  testWidgets('real full player paints 04:49 backing vocal below lead',
      (tester) async {
    await render(tester, const Duration(milliseconds: 289000));
    final backing = find.byKey(const ValueKey('full-player-bg-0'));
    expect(backing, findsOneWidget);
    final widget = tester.widget<FlowingBackgroundVocalSubline>(backing);
    expect(widget.vocal.text, 'Supporting vocal');
    expect(widget.vocal.words!.single.start,
        const Duration(milliseconds: 286325));
    expect(widget.vocal.words!.single.end,
        const Duration(milliseconds: 291269));
    expect(widget.singing, isTrue);

    // The actual full-player component paints the supporting vocal at
    // 18 px, beneath the 31 px highlighted lead, not as another lead row.
    final leadGlyph = find.byWidgetPredicate((w) =>
        w is LyricMotionLine && w.line.text == 'Lead 04:44.418');
    final bgGlyph = find.byWidgetPredicate((w) =>
        w is LyricMotionLine && w.line.text == 'Supporting vocal');
    expect(leadGlyph, findsOneWidget);
    expect(bgGlyph, findsOneWidget);
    final lead = tester.widget<LyricMotionLine>(leadGlyph);
    final bg = tester.widget<LyricMotionLine>(bgGlyph);
    expect(lead.style.fontSize, 31);
    expect(bg.style.fontSize, 18);
    expect(tester.getTopLeft(bgGlyph).dy,
        greaterThan(tester.getTopLeft(leadGlyph).dy));
    expect(tester.takeException(), isNull);
  });

  testWidgets('full player draws bg subline before its words begin',
      (tester) async {
    await render(tester, const Duration(milliseconds: 284500));
    expect(find.byKey(const ValueKey('full-player-bg-0')), findsOneWidget);
    final voice = tester.widget<FlowingBackgroundVocalSubline>(
      find.byKey(const ValueKey('full-player-bg-0')),
    );
    expect(voice.vocal.text, 'Supporting vocal');
    expect(voice.singing, isTrue);
    expect(tester.takeException(), isNull);
  });
}
