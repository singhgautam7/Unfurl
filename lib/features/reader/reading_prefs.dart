import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme/reading_theme.dart';
import '../../core/theme/tokens.dart';
import '../settings/settings_controller.dart';

/// The four reading fonts (board 1, section 5), all bundled.
enum ReaderFont {
  literata('Literata', 'Literata', 'Serif. Default for books.'),
  instrument('Instrument', 'Instrument Sans', 'The house sans.'),
  atkinson('Atkinson', 'Atkinson Hyperlegible Next', 'Distinct letterforms for low vision.'),
  openDyslexic('OpenDyslexic', 'OpenDyslexic', 'Weighted baselines for dyslexic readers.');

  const ReaderFont(this.label, this.family, this.note);
  final String label;
  final String family;
  final String note;
}

/// Page-turn styles (v2 · V2-03), in picker order. Shown only when paged.
enum PageTurn {
  slide('Slide'),
  curl('Curl'),
  cover('Cover'),
  fade('Fade'),
  none('None');

  const PageTurn(this.label);
  final String label;

  /// Under reduced motion Curl and Cover become Fade, Slide becomes None.
  PageTurn effective({required bool reduced}) => !reduced
      ? this
      : switch (this) {
          PageTurn.curl || PageTurn.cover || PageTurn.fade => PageTurn.fade,
          PageTurn.slide || PageTurn.none => PageTurn.none,
        };
}

enum ReaderLayout { paged, scroll }

enum PdfLayout { continuous, paged }

/// Reading defaults: typography, page behaviour and the PDF page options.
/// Every change applies live, without reloading the document.
@immutable
class ReadingPrefs {
  const ReadingPrefs({
    this.theme,
    this.font = ReaderFont.literata,
    this.size = 18,
    this.lineHeight = 1.6,
    this.margin = 24,
    this.justify = true,
    this.hyphenate = true,
    this.layout = ReaderLayout.paged,
    this.pageTurn = PageTurn.slide,
    this.brightness,
    this.keepScreenOn = true,
    this.volumeKeys = false,
    this.volumeInvert = false,
    this.pdfOpensReader = false,
    this.pdfLayout = PdfLayout.continuous,
    this.pdfCrop = false,
    this.pdfRecolour = true,
    this.ttsRate = 1.0,
    this.ttsVoice,
  });

  /// Null follows the chrome: Light in light, Dark or AMOLED in dark.
  final ReadingThemeId? theme;
  final ReaderFont font;

  /// 14 to 28 in steps of 2.
  final double size;

  /// 1.3, 1.6 or 1.8.
  final double lineHeight;

  /// 16, 24 or 36.
  final double margin;
  final bool justify;
  final bool hyphenate;
  final ReaderLayout layout;
  final PageTurn pageTurn;

  /// 0..1, or null for the system's.
  final double? brightness;
  final bool keepScreenOn;
  final bool volumeKeys;

  /// "Invert direction": volume up goes forward (v3, Settings › Controls).
  final bool volumeInvert;

  /// "PDFs open in": Page (false) or Reader.
  final bool pdfOpensReader;
  final PdfLayout pdfLayout;
  final bool pdfCrop;
  final bool pdfRecolour;
  final double ttsRate;
  final String? ttsVoice;

  static const List<double> sizes = <double>[14, 16, 18, 20, 22, 24, 26, 28];
  static const List<double> lineHeights = <double>[1.3, 1.6, 1.8];
  static const List<double> margins = <double>[16, 24, 36];
  static const List<double> rates = <double>[0.8, 1.0, 1.25, 1.5, 2.0];

  ReadingThemeId themeFor({required bool darkChrome, required bool amoledChrome}) =>
      theme ?? (darkChrome ? (amoledChrome ? ReadingThemeId.amoled : ReadingThemeId.dark) : ReadingThemeId.light);

  ReadingPrefs copyWith({
    ReadingThemeId? theme,
    ReaderFont? font,
    double? size,
    double? lineHeight,
    double? margin,
    bool? justify,
    bool? hyphenate,
    ReaderLayout? layout,
    PageTurn? pageTurn,
    double? brightness,
    bool clearBrightness = false,
    bool? keepScreenOn,
    bool? volumeKeys,
    bool? volumeInvert,
    bool? pdfOpensReader,
    PdfLayout? pdfLayout,
    bool? pdfCrop,
    bool? pdfRecolour,
    double? ttsRate,
    String? ttsVoice,
  }) => ReadingPrefs(
    theme: theme ?? this.theme,
    font: font ?? this.font,
    size: size ?? this.size,
    lineHeight: lineHeight ?? this.lineHeight,
    margin: margin ?? this.margin,
    justify: justify ?? this.justify,
    hyphenate: hyphenate ?? this.hyphenate,
    layout: layout ?? this.layout,
    pageTurn: pageTurn ?? this.pageTurn,
    brightness: clearBrightness ? null : (brightness ?? this.brightness),
    keepScreenOn: keepScreenOn ?? this.keepScreenOn,
    volumeKeys: volumeKeys ?? this.volumeKeys,
    volumeInvert: volumeInvert ?? this.volumeInvert,
    pdfOpensReader: pdfOpensReader ?? this.pdfOpensReader,
    pdfLayout: pdfLayout ?? this.pdfLayout,
    pdfCrop: pdfCrop ?? this.pdfCrop,
    pdfRecolour: pdfRecolour ?? this.pdfRecolour,
    ttsRate: ttsRate ?? this.ttsRate,
    ttsVoice: ttsVoice ?? this.ttsVoice,
  );

  static T _enum<T extends Enum>(List<T> values, String? name, T fallback) =>
      values.where((T v) => v.name == name).firstOrNull ?? fallback;

  static ReadingPrefs read(SharedPreferences p) => ReadingPrefs(
    theme: ReadingThemeId.values.where((ReadingThemeId r) => r.name == p.getString('reading.theme')).firstOrNull,
    font: _enum(ReaderFont.values, p.getString('reading.font'), ReaderFont.literata),
    size: p.getDouble('reading.size') ?? 18,
    lineHeight: p.getDouble('reading.lineHeight') ?? 1.6,
    margin: p.getDouble('reading.margin') ?? 24,
    justify: p.getBool('reading.justify') ?? true,
    hyphenate: p.getBool('reading.hyphenate') ?? true,
    layout: _enum(ReaderLayout.values, p.getString('reading.layout'), ReaderLayout.paged),
    pageTurn: _enum(PageTurn.values, p.getString('reading.pageTurn'), PageTurn.slide),
    brightness: p.getDouble('reading.brightness'),
    keepScreenOn: p.getBool('reading.keepScreenOn') ?? true,
    volumeKeys: p.getBool('reading.volumeKeys') ?? false,
    volumeInvert: p.getBool('reading.volumeInvert') ?? false,
    pdfOpensReader: p.getBool('pdf.opensReader') ?? false,
    pdfLayout: _enum(PdfLayout.values, p.getString('pdf.layout'), PdfLayout.continuous),
    pdfCrop: p.getBool('pdf.crop') ?? false,
    pdfRecolour: p.getBool('pdf.recolour') ?? true,
    ttsRate: p.getDouble('tts.rate') ?? 1.0,
    ttsVoice: p.getString('tts.voice'),
  );

  Future<void> write(SharedPreferences p) async {
    theme == null ? await p.remove('reading.theme') : await p.setString('reading.theme', theme!.name);
    await p.setString('reading.font', font.name);
    await p.setDouble('reading.size', size);
    await p.setDouble('reading.lineHeight', lineHeight);
    await p.setDouble('reading.margin', margin);
    await p.setBool('reading.justify', justify);
    await p.setBool('reading.hyphenate', hyphenate);
    await p.setString('reading.layout', layout.name);
    await p.setString('reading.pageTurn', pageTurn.name);
    brightness == null ? await p.remove('reading.brightness') : await p.setDouble('reading.brightness', brightness!);
    await p.setBool('reading.keepScreenOn', keepScreenOn);
    await p.setBool('reading.volumeKeys', volumeKeys);
    await p.setBool('reading.volumeInvert', volumeInvert);
    await p.setBool('pdf.opensReader', pdfOpensReader);
    await p.setString('pdf.layout', pdfLayout.name);
    await p.setBool('pdf.crop', pdfCrop);
    await p.setBool('pdf.recolour', pdfRecolour);
    await p.setDouble('tts.rate', ttsRate);
    if (ttsVoice != null) await p.setString('tts.voice', ttsVoice!);
  }
}

class ReadingPrefsController extends Notifier<ReadingPrefs> {
  @override
  ReadingPrefs build() => ReadingPrefs.read(ref.watch(prefsProvider));

  /// Applies at once (the page re-lays out within a frame) and persists.
  void update(ReadingPrefs Function(ReadingPrefs p) change) {
    state = change(state);
    state.write(ref.read(prefsProvider));
  }

  void reset() {
    const ReadingPrefs d = ReadingPrefs();
    update(
      (ReadingPrefs p) => d.copyWith(
        theme: p.theme,
        keepScreenOn: p.keepScreenOn,
        volumeKeys: p.volumeKeys,
        volumeInvert: p.volumeInvert,
        pdfOpensReader: p.pdfOpensReader,
        pageTurn: p.pageTurn,
        ttsRate: p.ttsRate,
        ttsVoice: p.ttsVoice,
        clearBrightness: true,
      ),
    );
  }
}

final NotifierProvider<ReadingPrefsController, ReadingPrefs> readingPrefsProvider =
    NotifierProvider<ReadingPrefsController, ReadingPrefs>(ReadingPrefsController.new);

/// Auto-scroll's speed level, remembered per mode ('reader', 'pdf',
/// 'webtoon'), and auto page turn's interval (v3 · V3-COMFORT).
abstract final class ComfortPrefs {
  static int level(SharedPreferences p, String mode) => p.getInt('autoscroll.$mode') ?? ComfortSpec.defaultLevel;
  static Future<void> setLevel(SharedPreferences p, String mode, int level) => p.setInt('autoscroll.$mode', level);
  static int seconds(SharedPreferences p) => p.getInt('autoturn.seconds') ?? ComfortSpec.defaultTurn;
  static Future<void> setSeconds(SharedPreferences p, int s) => p.setInt('autoturn.seconds', s);
}
