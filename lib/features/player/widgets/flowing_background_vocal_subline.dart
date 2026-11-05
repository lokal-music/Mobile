import 'package:flutter/material.dart';
import 'package:flick/features/player/widgets/flowing_lyric_subline.dart';
import 'package:flick/services/lyrics_service.dart';

/// The lead and its independent supporting vocal are two rendered voices,
/// not a lead and an ordinary translation. The source's bg word windows are
/// retained exactly; only the placement changes.
LyricsLine? flowingBackgroundLine(LyricsLine lead) {
  final text = lead.backgroundText?.trim();
  if (text == null || text.isEmpty) return null;
  final words = lead.backgroundWords;
  return LyricsLine(
    timestamp: words?.isNotEmpty == true ? words!.first.start : lead.timestamp,
    text: text,
    words: words,
  );
}

/// A small second voice immediately below a lead in the full player.
/// It remains visible even before its own words start; those timestamps
/// control karaoke fill rather than visibility.
class FlowingBackgroundVocalSubline extends StatelessWidget {
  const FlowingBackgroundVocalSubline({
    super.key,
    required this.vocal,
    required this.position,
    required this.singing,
    required this.style,
    this.lightweight = false,
  });

  final LyricsLine vocal;
  final Duration position;
  final bool singing;
  final TextStyle style;
  final bool lightweight;

  @override
  Widget build(BuildContext context) => FlowingLyricSubline(
    text: vocal.text,
    timedLine: vocal,
    position: position,
    singing: singing,
    lightweight: lightweight,
    style: style,
  );
}
