import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/platform/platform.dart';
import '../../formats/reading_document.dart';

/// Read aloud with the system engine, one sentence at a time, so the
/// current sentence can be tinted and the page can follow it. Pauses when
/// another app takes audio focus.
class ReadAloud extends ChangeNotifier {
  ReadAloud(this.doc, {this.volume}) {
    _events = Platform.speechEvents.listen(_onEvent);
  }

  final ReadingDocument doc;

  /// The sleep timer's fade (1 until the last 10 s), applied per sentence.
  final double Function()? volume;
  late final StreamSubscription<(String, Object?)> _events;
  late final List<(int, int)> sentences = segment(doc.plainText);

  /// Shown at all (the mini player is docked).
  bool active = false;
  bool playing = false;
  int index = 0;
  double rate = 1.0;
  String? error;
  int _utterance = 0;

  (int, int)? get current => active && index < sentences.length ? sentences[index] : null;

  /// Sentence boundaries over the whole text: terminal punctuation (and any
  /// closing quotes) then space, or a block break. A full stop after a
  /// title ("Mr.") or an initial ("J.") doesn't end a sentence.
  @visibleForTesting
  static List<(int, int)> segment(String text) {
    final List<(int, int)> out = <(int, int)>[];
    final RegExp end = RegExp(r'[.!?…]+["”’)\]]*(?=\s)|\n');
    int start = 0;
    for (final RegExpMatch m in end.allMatches(text)) {
      // Blank lines: the skip past whitespace below can run beyond the next
      // newline match.
      if (m.end <= start) continue;
      if (m[0] == '.' && _abbreviation.hasMatch(text.substring(start, m.start))) continue;
      final int stop = m.end;
      if (text.substring(start, stop).trim().isNotEmpty) out.add((start, stop));
      start = stop;
      while (start < text.length && (text[start] == ' ' || text[start] == '\n')) {
        start++;
      }
    }
    if (start < text.length && text.substring(start).trim().isNotEmpty) out.add((start, text.length));
    return out;
  }

  static final RegExp _abbreviation = RegExp(
    r'(?:^|[\s(“"])(?:Mr|Mrs|Ms|Mx|Dr|St|Sr|Jr|Prof|Rev|Gen|Col|Capt|Lt|Sgt|Hon|vs|etc|No|Vol|pp?|fig|i\.e|e\.g|[A-Z])$',
  );

  int _sentenceAt(int global) {
    for (int i = 0; i < sentences.length; i++) {
      if (sentences[i].$2 > global) return i;
    }
    return sentences.isEmpty ? 0 : sentences.length - 1;
  }

  /// Starts at [global] ("Read aloud from here", or the top of the page).
  Future<void> start(int global, {double? speed}) async {
    if (sentences.isEmpty) return;
    if (speed != null) rate = speed;
    index = _sentenceAt(global);
    active = true;
    error = null;
    await Platform.speechRate(rate);
    await _speak();
  }

  Future<void> _speak() async {
    if (index >= sentences.length) return stop();
    playing = true;
    notifyListeners();
    final (int a, int b) = sentences[index];
    await Platform.speak(
      doc.plainText.substring(a, b).replaceAll('\n', ' '),
      'u${++_utterance}',
      volume: volume?.call() ?? 1,
    );
  }

  void _onEvent((String, Object?) e) {
    switch (e.$1) {
      case 'ttsDone':
        if (e.$2 == 'u$_utterance' && playing) {
          index++;
          unawaited(_speak());
        }
      case 'ttsFocusLost':
        playing = false;
        notifyListeners();
      case 'ttsError':
        if (e.$2 == 'unavailable') {
          error = 'No text-to-speech engine is set up on this phone.';
          playing = false;
          notifyListeners();
        }
    }
  }

  Future<void> toggle() async {
    if (playing) {
      playing = false;
      _utterance++;
      await Platform.stopSpeaking();
      notifyListeners();
    } else {
      await _speak();
    }
  }

  Future<void> skip(int delta) async {
    index = (index + delta).clamp(0, sentences.length - 1);
    _utterance++;
    if (playing) {
      await _speak();
    } else {
      notifyListeners();
    }
  }

  Future<void> setRate(double r) async {
    rate = r;
    await Platform.speechRate(r);
    if (playing) await _speak();
    notifyListeners();
  }

  Future<void> stop() async {
    active = false;
    playing = false;
    _utterance++;
    await Platform.stopSpeaking();
    notifyListeners();
  }

  @override
  void dispose() {
    unawaited(_events.cancel());
    unawaited(Platform.stopSpeaking());
    super.dispose();
  }
}
