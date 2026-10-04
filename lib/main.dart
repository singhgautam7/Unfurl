import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:pdfrx/pdfrx.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/db/database.dart';
import 'core/library/enrich.dart';
import 'core/providers.dart';
import 'features/settings/settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Settings decide the theme, so they are read before the first frame: the
  // cached mode, true black, dynamic flag and last wallpaper seed build the
  // exact ThemeData the app will keep, and nothing flashes. The database
  // opens lazily on its own isolate; nothing waits on it here.
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  final AppDatabase db = AppDatabase();
  _registerLicences();

  runApp(
    ProviderScope(
      overrides: <Override>[prefsProvider.overrideWithValue(prefs), databaseProvider.overrideWithValue(db)],
      child: const UnfurlApp(),
    ),
  );
  // PDFium and the cover cache are needed only once a book is shown.
  await pdfrxFlutterInitialize();
  await Covers.dir();
}

/// Bundled fonts and PDFium carry their own licences; Dart packages add
/// theirs automatically.
void _registerLicences() {
  LicenseRegistry.addLicense(() async* {
    for (final (String name, String path) in <(String, String)>[
      ('Instrument Sans', 'assets/fonts/instrument_sans/OFL.txt'),
      ('Literata', 'assets/fonts/literata/OFL.txt'),
      ('Atkinson Hyperlegible Next', 'assets/fonts/atkinson/OFL.txt'),
      ('OpenDyslexic', 'assets/fonts/opendyslexic/OFL.txt'),
      ('Material Symbols', 'assets/fonts/material_symbols/LICENSE'),
      // Comic archives, read on the Kotlin side (v3).
      ('Apache Commons Compress', 'assets/licenses/APACHE-2.0.txt'),
      ('Apache Commons IO, Lang and Codec', 'assets/licenses/APACHE-2.0.txt'),
      ('Apache Commons notices', 'assets/licenses/APACHE-NOTICES.txt'),
      ('XZ for Java', 'assets/licenses/XZ-0BSD.txt'),
      ('junrar', 'assets/licenses/UNRAR.txt'),
      ('SLF4J', 'assets/licenses/SLF4J-MIT.txt'),
      ('foliate-js', 'assets/licenses/FOLIATE-MIT.txt'),
    ]) {
      yield LicenseEntryWithLineBreaks(<String>[name], await rootBundle.loadString(path));
    }
    yield const LicenseEntryWithLineBreaks(<String>['PDFium'], _pdfium);
  });
}

const String _pdfium = '''Copyright 2014 The PDFium Authors

Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

1. Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.
3. Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.''';
