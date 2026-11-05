import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flick/features/player/widgets/karaoke_lyric_line.dart';
import 'package:flick/features/player/widgets/synced_lyrics_view.dart';
import 'package:flick/providers/app_preferences_provider.dart';
import 'package:flick/services/app_preferences_service.dart';
import 'package:flick/services/lyrics_service.dart';
import 'package:flick/services/player_service.dart';

/// No audio engine is started: the screen is driven by an explicit clock.
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

class _StaticLyricsPreferences extends AppPreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences(karaokeEnabled: false);
}

class _KaraokeLyricsPreferences extends AppPreferencesNotifier {
  @override
  AppPreferences build() => const AppPreferences(karaokeEnabled: true);
}

const _realFileTimestamps = LyricsData(
  rawContent: '',
  source: 'embedded:vorbis',
  isSynchronized: true,
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
  Future<void> mount(
    WidgetTester tester,
    ValueNotifier<Duration> position, {
    required bool karaoke,
  }) async {
    final fake = _FakePlayer();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appPreferencesProvider.overrideWith(
            karaoke
                ? _KaraokeLyricsPreferences.new
                : _StaticLyricsPreferences.new,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(
              height: 610,
              child: SyncedLyricsView(
                playerService: fake,
                lyricsService: LyricsService(),
                lyrics: _realFileTimestamps,
                positionNotifier: position,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }

  testWidgets(
    'backing text is painted immediately beneath active 04:44 lead',
    (tester) async {
      final clock = ValueNotifier(const Duration(milliseconds: 284500));
      addTearDown(clock.dispose);
      await mount(tester, clock, karaoke: false);
      expect(find.text('Lead 04:44.418'), findsOneWidget);
      expect(find.text('Supporting vocal'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('supporting-vocal-subline-0')),
        findsOneWidget,
      );
      final leadOffset = tester.getTopLeft(find.text('Lead 04:44.418'));
      final backingOffset = tester.getTopLeft(find.text('Supporting vocal'));
      expect(backingOffset.dy, greaterThan(leadOffset.dy));

      clock.value = const Duration(milliseconds: 289000);
      await tester.pump();
      expect(find.text('Supporting vocal'), findsOneWidget);

      clock.value = const Duration(milliseconds: 292500);
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('Supporting vocal'), findsNothing);
    },
  );

  testWidgets(
    'karaoke subline exists at 04:49 with background voice timing',
    (tester) async {
      final clock = ValueNotifier(const Duration(milliseconds: 289000));
      addTearDown(clock.dispose);
      await mount(tester, clock, karaoke: true);
      final backing = tester.widgetList<KaraokeLyricLine>(
        find.byType(KaraokeLyricLine),
      ).where((line) => line.backgroundVoice).toList();
      expect(backing, hasLength(1));
      expect(backing.single.lineIndex, 0);
      expect(
        backing.single.lyrics.lines[0].backgroundWords!.single.start,
        const Duration(milliseconds: 286325),
      );
    },
  );
}
