import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show StreamProviderFamily;

import 'db/database.dart';
import 'library/enrich.dart';
import 'library/library.dart';
import 'platform/platform.dart';

/// Overridden in `main` with the database opened at bootstrap.
final Provider<AppDatabase> databaseProvider = Provider<AppDatabase>(
  (Ref ref) => throw UnimplementedError('databaseProvider must be overridden'),
);

final Provider<Library> libraryProvider = Provider<Library>((Ref ref) {
  final Library library = Library(ref.watch(databaseProvider));
  final Enricher enricher = Enricher(library);
  library.onScanned = enricher.run;
  return library;
});

final StreamProvider<List<Folder>> foldersProvider = StreamProvider<List<Folder>>(
  (Ref ref) => ref.watch(libraryProvider).watchFolders(),
);

final StreamProvider<List<BookItem>> booksProvider = StreamProvider<List<BookItem>>(
  (Ref ref) => ref.watch(libraryProvider).watchBooks(),
);

final StreamProvider<Map<int, int>> readableCountsProvider = StreamProvider<Map<int, int>>(
  (Ref ref) => ref.watch(libraryProvider).watchReadableCounts(),
);

final StreamProvider<List<Document>> openedDocumentsProvider = StreamProvider<List<Document>>(
  (Ref ref) => ref.watch(libraryProvider).watchOpened(),
);

final StreamProvider<List<Recent>> recentsProvider = StreamProvider<List<Recent>>(
  (Ref ref) => ref.watch(libraryProvider).watchRecents(),
);

final StreamProvider<List<(Annotation, Document?)>> allAnnotationsProvider =
    StreamProvider<List<(Annotation, Document?)>>((Ref ref) => ref.watch(libraryProvider).watchAllAnnotations());

final StreamProviderFamily<List<Annotation>, String> annotationsProvider = StreamProvider.autoDispose
    .family<List<Annotation>, String>(
      (Ref ref, String fingerprint) => ref.watch(libraryProvider).watchAnnotations(fingerprint),
    );

/// Checked each time it is read (Mull can be installed or removed between).
final FutureProvider<bool> mullInstalledProvider = FutureProvider<bool>((Ref ref) => Platform.isMullInstalled());

/// The installed version, from the package, never a string in Dart.
final FutureProvider<String?> appVersionProvider = FutureProvider<String?>((Ref ref) => Platform.appVersion());
