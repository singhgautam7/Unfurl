import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show PlatformException;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/settings/settings_controller.dart';
import 'platform/platform.dart';

/// Why the Files root shows its privacy card with an eyebrow.
enum AccessNote {
  none,

  /// Back from Android's page without turning it on: "ACCESS IS STILL OFF".
  stillOff,

  /// It was on and Android turned it off: "ACCESS WAS TURNED OFF".
  turnedOff,
}

@immutable
class FilesAccess {
  const FilesAccess({required this.granted, this.note = AccessNote.none, this.justGranted = false});

  final bool granted;
  final AccessNote note;

  /// Turned on since the last request: Files shows "All files access is on".
  final bool justGranted;

  @override
  bool operator ==(Object other) =>
      other is FilesAccess && other.granted == granted && other.note == note && other.justGranted == justGranted;

  @override
  int get hashCode => Object.hash(granted, note, justGranted);
}

/// All-files access, live. The last known state is cached so the first frame
/// is right; Android's answer arrives on every resume and after a request.
/// The app works fully without it (folders picked with the system picker).
class FilesAccessController extends Notifier<FilesAccess> {
  static const String kLastGranted = 'files.access.granted';

  bool _requested = false;
  StreamSubscription<bool>? _sub;

  SharedPreferences get _prefs => ref.read(prefsProvider);

  @override
  FilesAccess build() {
    _sub ??= Platform.allFilesAccessChanges.listen(_apply);
    ref.onDispose(() => _sub?.cancel());
    unawaited(Platform.hasAllFilesAccess().then(_apply));
    return FilesAccess(granted: _prefs.getBool(kLastGranted) ?? false);
  }

  void _apply(bool granted) {
    final bool was = state.granted || (_prefs.getBool(kLastGranted) ?? false);
    if (granted != (_prefs.getBool(kLastGranted) ?? false)) unawaited(_prefs.setBool(kLastGranted, granted));
    if (granted) {
      state = FilesAccess(granted: true, justGranted: state.justGranted || (_requested && !state.granted));
      _requested = false;
    } else if (_requested) {
      state = const FilesAccess(granted: false, note: AccessNote.stillOff);
    } else if (was) {
      state = const FilesAccess(granted: false, note: AccessNote.turnedOff);
    } else {
      state = FilesAccess(granted: false, note: state.note);
    }
    if (!granted) ExplorerSession.clear();
  }

  /// Opens Android's page; the result comes back on resume.
  Future<bool> request() {
    _requested = true;
    return Platform.requestAllFilesAccess();
  }

  /// The snackbar has been shown.
  void acknowledge() {
    if (state.justGranted) state = FilesAccess(granted: state.granted, note: state.note);
  }

  /// Re-reads Android's answer (on resume, from app.dart).
  Future<void> refresh() async => _apply(await Platform.hasAllFilesAccess());
}

final NotifierProvider<FilesAccessController, FilesAccess> filesAccessProvider =
    NotifierProvider<FilesAccessController, FilesAccess>(FilesAccessController.new);

/// One folder's listing as it streams in from the platform. Entries arrive in
/// display order (folders first, then the sort); [total] is known from the
/// head. Cancelled when no screen holds it any more.
class DirListing extends ChangeNotifier {
  DirListing(this.path, {required this.sort, required this.hidden}) {
    _sub = Platform.listDirectory(path, sort: sort, hidden: hidden).listen(
      _on,
      onError: (Object e) {
        problem = e is PlatformException
            ? DirProblem.values.asNameMap()[e.code] ?? DirProblem.unreadable
            : DirProblem.unreadable;
        done = true;
        notifyListeners();
      },
      onDone: () {
        done = true;
        notifyListeners();
      },
    );
  }

  final String path;
  final String sort;
  final bool hidden;

  /// Null until the head arrives.
  int? total;
  int dirs = 0;
  final List<DirEntry> entries = <DirEntry>[];
  bool done = false;
  DirProblem? problem;
  StreamSubscription<DirEvent>? _sub;

  void _on(DirEvent e) {
    switch (e) {
      case DirHead(:final int total, :final int dirs):
        this.total = total;
        this.dirs = dirs;
      case DirPage(:final List<DirEntry> entries):
        this.entries.addAll(entries);
    }
    notifyListeners();
  }

  bool get loading => !done;

  @override
  void dispose() {
    unawaited(_sub?.cancel());
    super.dispose();
  }
}

/// Where the reader left each folder this session: scroll offset and how much
/// had loaded, so coming back is instant and in the same place.
@immutable
class FolderMemory {
  const FolderMemory({required this.offset, required this.loaded});

  final double offset;
  final int loaded;
}

abstract final class ExplorerSession {
  static final Map<String, FolderMemory> _memory = <String, FolderMemory>{};

  /// Listings recently left, kept warm for instant back navigation.
  static final Map<String, DirListing> _warm = <String, DirListing>{};
  static const int _warmCap = 6;

  static FolderMemory? memoryOf(String path) => _memory[path];

  static void remember(String path, FolderMemory m) => _memory[path] = m;

  /// A listing for [path], reusing a warm one with the same options.
  static DirListing open(String path, {required String sort, required bool hidden}) {
    final DirListing? warm = _warm.remove(path);
    if (warm != null && warm.sort == sort && warm.hidden == hidden && warm.problem == null) return warm;
    warm?.dispose();
    return DirListing(path, sort: sort, hidden: hidden);
  }

  /// A screen let go of [l]: keep it warm, evicting the oldest.
  static void release(DirListing l) {
    _warm.remove(l.path)?.dispose();
    _warm[l.path] = l;
    while (_warm.length > _warmCap) {
      _warm.remove(_warm.keys.first)!.dispose();
    }
  }

  /// Access changed: nothing cached can be trusted.
  static void clear() {
    for (final DirListing l in _warm.values) {
      l.dispose();
    }
    _warm.clear();
  }
}

/// Readable names for paths: "Internal storage › Download", "SD card › Comics".
abstract final class PathNames {
  /// Mounted volumes, refreshed when Files opens.
  static List<StorageVolume> volumes = const <StorageVolume>[];

  static const String internalRoot = '/storage/emulated/0';

  static StorageVolume? volumeOf(String path) {
    StorageVolume? best;
    for (final StorageVolume v in volumes) {
      if ((path == v.path || path.startsWith('${v.path}/')) && (best == null || v.path.length > best.path.length)) {
        best = v;
      }
    }
    return best;
  }

  static String rootName(StorageVolume? v, String path) {
    if (v == null) return path.startsWith(internalRoot) ? 'Internal storage' : 'Storage';
    return switch (v.kind) {
      'internal' => 'Internal storage',
      'usb' => 'USB drive',
      _ => 'SD card',
    };
  }

  /// The parts from the volume down: ["Internal storage", "Download", "Papers"].
  static List<String> parts(String path) {
    final StorageVolume? v = volumeOf(path);
    final String root = v?.path ?? (path.startsWith(internalRoot) ? internalRoot : '');
    final String rel = path.length > root.length ? path.substring(root.length + 1) : '';
    return <String>[rootName(v, path), if (rel.isNotEmpty) ...rel.split('/')];
  }

  static String readable(String path) => parts(path).join(' › ');

  /// The volume roots themselves can't be added as folders.
  static bool isRoot(String path) =>
      path == internalRoot || volumes.any((StorageVolume v) => v.path == path) || path.isEmpty;

  /// Android/data and Android/obb (and anything inside them).
  static bool isRestricted(String path) {
    final StorageVolume? v = volumeOf(path);
    final String root = v?.path ?? internalRoot;
    if (!path.startsWith('$root/')) return false;
    final String rel = path.substring(root.length + 1).toLowerCase();
    return rel == 'android/data' ||
        rel == 'android/obb' ||
        rel.startsWith('android/data/') ||
        rel.startsWith('android/obb/');
  }

  static String nameOf(String path) => path.isEmpty ? '' : path.substring(path.lastIndexOf('/') + 1);

  static String parentOf(String path) => path.contains('/') ? path.substring(0, path.lastIndexOf('/')) : '';
}
