import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A document as the system describes it: a content URI (or, with all-files
/// access, a file:// URI from the Files tab) with its name, size, type and
/// modified time.
@immutable
class DocRef {
  const DocRef({required this.uri, required this.name, this.size = 0, this.modified = 0, this.mime});

  factory DocRef.fromMap(Map<Object?, Object?> m) => DocRef(
    uri: m['uri']! as String,
    name: (m['name'] as String?) ?? Uri.decodeComponent((m['uri']! as String).split('%2F').last.split('/').last),
    size: (m['size'] as int?) ?? 0,
    modified: (m['modified'] as int?) ?? 0,
    mime: m['mime'] as String?,
  );

  final String uri;
  final String name;
  final int size;
  final int modified;
  final String? mime;

  String get extension {
    final int dot = name.lastIndexOf('.');
    return dot < 0 ? '' : name.substring(dot + 1).toLowerCase();
  }

  @override
  bool operator ==(Object other) => other is DocRef && other.uri == uri;

  @override
  int get hashCode => uri.hashCode;
}

/// A granted folder tree.
@immutable
class PickedFolder {
  const PickedFolder({required this.uri, required this.name, required this.path});

  final String uri;
  final String name;

  /// "Documents › Papers".
  final String path;
}

/// One row of a folder scan.
@immutable
class ScannedEntry {
  const ScannedEntry({
    required this.docId,
    required this.uri,
    required this.parent,
    required this.name,
    required this.mime,
    required this.isDir,
    required this.size,
    required this.modified,
  });

  factory ScannedEntry.fromMap(Map<Object?, Object?> m) => ScannedEntry(
    docId: m['docId']! as String,
    uri: m['uri']! as String,
    parent: m['parent']! as String,
    name: m['name']! as String,
    mime: m['mime'] as String?,
    isDir: m['dir']! as bool,
    size: (m['size'] as int?) ?? 0,
    modified: (m['modified'] as int?) ?? 0,
  );

  final String docId;
  final String uri;

  /// Directory relative to the granted root, '' at the root, '/'-separated.
  final String parent;
  final String name;
  final String? mime;
  final bool isDir;
  final int size;
  final int modified;
}

/// A storage volume: internal storage, an SD card or a USB drive.
@immutable
class StorageVolume {
  const StorageVolume({
    required this.path,
    required this.kind,
    required this.label,
    required this.mounted,
    required this.readable,
    required this.total,
    required this.free,
  });

  factory StorageVolume.fromMap(Map<Object?, Object?> m) => StorageVolume(
    path: m['path']! as String,
    kind: m['kind']! as String,
    label: (m['label'] as String?) ?? '',
    mounted: m['mounted']! as bool,
    readable: m['readable']! as bool,
    total: (m['total'] as int?) ?? 0,
    free: (m['free'] as int?) ?? 0,
  );

  final String path;

  /// internal, sd or usb.
  final String kind;

  /// The system's description ("SanDisk USB drive").
  final String label;
  final bool mounted;
  final bool readable;
  final int total;
  final int free;

  double get used => total <= 0 ? 0 : (total - free) / total;
}

/// A quick-access location that exists on this phone.
@immutable
class QuickPlace {
  const QuickPlace({required this.id, required this.path, required this.count});

  factory QuickPlace.fromMap(Map<Object?, Object?> m) =>
      QuickPlace(id: m['id']! as String, path: m['path']! as String, count: (m['count'] as int?) ?? 0);

  /// downloads, documents, whatsapp, telegram, bluetooth, screenshots.
  final String id;
  final String path;

  /// Visible entries directly inside.
  final int count;
}

/// One entry of a folder listing.
@immutable
class DirEntry {
  const DirEntry({required this.name, required this.isDir, required this.size, required this.modified});

  final String name;
  final bool isDir;
  final int size;
  final int modified;

  bool get hidden => name.startsWith('.');

  String get extension {
    final int dot = name.lastIndexOf('.');
    return isDir || dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
  }
}

/// Why a folder can't be listed: Android/data or obb, access off, the volume
/// was removed, the folder is gone, or it can't be read.
enum DirProblem { restricted, denied, removed, missing, unreadable }

/// A folder listing as it streams in: a head (counts) then pages.
sealed class DirEvent {}

class DirHead extends DirEvent {
  DirHead(this.total, this.dirs);
  final int total;
  final int dirs;
}

class DirPage extends DirEvent {
  DirPage(this.from, this.entries);
  final int from;
  final List<DirEntry> entries;
}

/// The one door to Android: the Storage Access Framework, intents, text to
/// speech, Mull and window flags (`MainActivity.kt`, `Storage.kt`,
/// `Scanner.kt`, `Speech.kt`). No network anywhere behind it.
abstract final class Platform {
  static const MethodChannel _channel = MethodChannel('unfurl/platform');
  static const EventChannel _scan = EventChannel('unfurl/scan');
  static const String mullPackage = 'com.grs.dictionary';

  static final StreamController<DocRef> _arrivals = StreamController<DocRef>.broadcast();
  static final StreamController<int> _volumeKeys = StreamController<int>.broadcast();
  static final StreamController<(String, Object?)> _speech = StreamController<(String, Object?)>.broadcast();
  static final StreamController<bool> _access = StreamController<bool>.broadcast();
  static const EventChannel _list = EventChannel('unfurl/list');
  static bool _listening = false;

  /// Files sent from other apps ("Open with", share) while Unfurl runs.
  static Stream<DocRef> get arrivals {
    _listen();
    return _arrivals.stream;
  }

  /// +1 next page (volume down), -1 previous, while [volumeKeys] is on.
  static Stream<int> get volumeKeyPresses {
    _listen();
    return _volumeKeys.stream;
  }

  /// ttsStart / ttsDone / ttsError / ttsFocusLost with the utterance id.
  static Stream<(String, Object?)> get speechEvents {
    _listen();
    return _speech.stream;
  }

  /// All-files access as Android reports it on every resume and after a
  /// permission request.
  static Stream<bool> get allFilesAccessChanges {
    _listen();
    return _access.stream;
  }

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'intent':
          _arrivals.add(DocRef.fromMap(call.arguments as Map<Object?, Object?>));
        case 'volumeKey':
          _volumeKeys.add(call.arguments as int);
        case 'allFilesAccess':
          _access.add(call.arguments as bool);
        default:
          if (call.method.startsWith('tts')) _speech.add((call.method, call.arguments));
      }
    });
  }

  static Future<T?> _call<T>(String method, [Map<String, Object?>? args]) async {
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on MissingPluginException {
      return null; // Widget tests run without the platform side.
    } on PlatformException {
      return null;
    }
  }

  static Future<DocRef?> pickFile(List<String> mimes) async {
    final Map<Object?, Object?>? m = await _call<Map<Object?, Object?>>('pickFile', <String, Object?>{'mimes': mimes});
    return m == null ? null : DocRef.fromMap(m);
  }

  static Future<PickedFolder?> pickFolder() async {
    final Map<Object?, Object?>? m = await _call<Map<Object?, Object?>>('pickFolder');
    return m == null
        ? null
        : PickedFolder(uri: m['uri']! as String, name: m['name']! as String, path: (m['path'] as String?) ?? '');
  }

  static Future<void> releaseFolder(String uri) => _call<bool>('releaseFolder', <String, Object?>{'uri': uri});

  static Future<List<String>> persistedFolders() async =>
      (await _call<List<Object?>>('persistedFolders'))?.cast<String>() ?? const <String>[];

  /// Null when the document is gone or no longer readable.
  static Future<DocRef?> stat(String uri) async {
    final Map<Object?, Object?>? m = await _call<Map<Object?, Object?>>('stat', <String, Object?>{'uri': uri});
    return m == null ? null : DocRef.fromMap(m);
  }

  /// A readable path (`/proc/self/fd/N`) for the document; close it with
  /// [closeFd]. Null when access is gone.
  static Future<int?> openFd(String uri) => _call<int>('openFd', <String, Object?>{'uri': uri});

  static Future<void> closeFd(int fd) => _call<bool>('closeFd', <String, Object?>{'fd': fd});

  /// The file Unfurl was launched with, once.
  static Future<DocRef?> takeLaunchIntent() async {
    final Map<Object?, Object?>? m = await _call<Map<Object?, Object?>>('takeIntent');
    return m == null ? null : DocRef.fromMap(m);
  }

  /// Streams a folder tree in batches; errors when access was lost. Device
  /// discovery (`device://all`) looks only for [exts].
  static Stream<List<ScannedEntry>> scan(String treeUri, {List<String> exts = const <String>[]}) => _scan
      .receiveBroadcastStream(<String, Object?>{'uri': treeUri, 'exts': exts})
      .map(
        (Object? batch) =>
            (batch! as List<Object?>).map((Object? e) => ScannedEntry.fromMap(e! as Map<Object?, Object?>)).toList(),
      );

  static Future<bool> openWith(String uri, String? mime) async =>
      await _call<bool>('openWith', <String, Object?>{'uri': uri, 'mime': mime}) ?? false;

  static Future<void> shareFile(String uri, String? mime) =>
      _call<bool>('shareFile', <String, Object?>{'uri': uri, 'mime': mime});

  /// Saves a new PNG to Pictures/Unfurl; the MediaStore URI, or null (before
  /// Android 10, or on failure).
  static Future<String?> saveImage(Uint8List bytes, String name) =>
      _call<String>('saveImage', <String, Object?>{'bytes': bytes, 'name': name});

  /// Shares an image in the app's cache (`cache/cards/`) through FileProvider.
  static Future<void> shareImage(String path) => _call<bool>('shareImage', <String, Object?>{'path': path});

  static Future<void> shareText(String text, {String? subject}) =>
      _call<bool>('shareText', <String, Object?>{'text': text, 'subject': subject});

  static Future<String?> appVersion() => _call<String>('appVersion');

  static Future<bool> isMullInstalled() async =>
      await _call<bool>('isInstalled', <String, Object?>{'package': mullPackage}) ?? false;

  static Future<bool> defineInMull(String text) async =>
      await _call<bool>('defineInMull', <String, Object?>{'text': text}) ?? false;

  static Future<void> openApp(String package) => _call<bool>('openApp', <String, Object?>{'package': package});

  // ------------------------------------------------------------ all files

  /// The app's heap budget in MB (`ActivityManager.memoryClass`), which sizes
  /// the decoded-image cache; 256 when unknown.
  static Future<int> memoryClass() async => await _call<int>('memoryClass') ?? 256;

  /// MediaStore's change counter (-1 before Android 11).
  static Future<int> mediaGeneration() async => await _call<int>('mediaGeneration') ?? -1;

  static Future<bool> hasAllFilesAccess() async => await _call<bool>('hasAllFilesAccess') ?? false;

  /// Opens Android's All files access page (or, on Android 10 and below,
  /// asks for the read permission). The outcome arrives on resume.
  static Future<bool> requestAllFilesAccess() async => await _call<bool>('requestAllFilesAccess') ?? false;

  static Future<List<StorageVolume>> volumes() async => <StorageVolume>[
    for (final Object? m in await _call<List<Object?>>('volumes') ?? const <Object?>[])
      StorageVolume.fromMap(m! as Map<Object?, Object?>),
  ];

  static Future<List<QuickPlace>> quickAccess() async => <QuickPlace>[
    for (final Object? m in await _call<List<Object?>>('quickAccess') ?? const <Object?>[])
      QuickPlace.fromMap(m! as Map<Object?, Object?>),
  ];

  /// Direct children of a folder: (files, readable, folders; hidden ones not
  /// counted), or null if it can't be read.
  static Future<(int, int, int)?> folderSummary(String path, Iterable<String> readable) async {
    final Map<Object?, Object?>? m = await _call<Map<Object?, Object?>>('folderSummary', <String, Object?>{
      'path': path,
      'readable': readable.toList(),
    });
    return m == null ? null : (m['files']! as int, m['readable']! as int, m['folders']! as int);
  }

  static int _nextList = 0;
  static final Map<int, StreamController<DirEvent>> _lists = <int, StreamController<DirEvent>>{};
  // Lives as long as the app: one EventChannel carries every listing.
  // ignore: cancel_subscriptions
  static StreamSubscription<Object?>? _listEvents;

  /// A folder's entries, folders first, sorted natively: a head, then the first
  /// page fast and the rest in larger pages. Cancelling the subscription stops
  /// the walk. Errors are [PlatformException]s whose code names a [DirProblem].
  static Stream<DirEvent> listDirectory(String path, {String sort = 'name', bool hidden = false}) {
    // One event stream serves every listing, each event tagged with its id.
    _listEvents ??= _list.receiveBroadcastStream().listen((Object? e) {
      final Map<Object?, Object?> m = e! as Map<Object?, Object?>;
      final StreamController<DirEvent>? c = _lists[m['id']];
      if (c == null) return;
      switch (m['kind']) {
        case 'head':
          c.add(DirHead(m['total']! as int, m['dirs']! as int));
        case 'page':
          c.add(
            DirPage(m['from']! as int, <DirEntry>[
              for (final Object? r in m['rows']! as List<Object?>)
                if (r case <Object?>[final String n, final bool d, final int sz, final int t])
                  DirEntry(name: n, isDir: d, size: sz, modified: t),
            ]),
          );
        case 'error':
          c.addError(PlatformException(code: m['code']! as String));
          unawaited(c.close());
        case 'done':
          unawaited(c.close());
      }
    });
    final int id = _nextList++;
    // Closed by its 'done' or 'error' event, or dropped when cancelled.
    // ignore: close_sinks
    final StreamController<DirEvent> c = StreamController<DirEvent>();
    c
      ..onListen = (() =>
          _call<void>('listStart', <String, Object?>{'id': id, 'path': path, 'sort': sort, 'hidden': hidden}))
      ..onCancel = () {
        _lists.remove(id);
        return _call<void>('listCancel', <String, Object?>{'id': id});
      };
    _lists[id] = c;
    return c.stream;
  }

  static Future<void> openStore(String package) => _call<bool>('openStore', <String, Object?>{'package': package});

  static Future<void> openUrl(String url) => _call<bool>('openUrl', <String, Object?>{'url': url});

  static Future<void> email(String to, String subject) =>
      _call<bool>('email', <String, Object?>{'to': to, 'subject': subject});

  static Future<void> keepScreenOn({required bool on}) => _call<void>('keepScreenOn', <String, Object?>{'on': on});

  /// 0..1, or null to hand brightness back to the system.
  static Future<void> setBrightness(double? value) =>
      _call<void>('brightness', <String, Object?>{'value': value ?? -1.0});

  static Future<void> volumeKeys({required bool on}) => _call<void>('volumeKeys', <String, Object?>{'on': on});

  /// [volume] 0..1 for this sentence (the sleep timer's fade).
  static Future<void> speak(String text, String id, {double volume = 1}) =>
      _call<bool>('speak', <String, Object?>{'text': text, 'id': id, 'volume': volume});

  static Future<void> stopSpeaking() => _call<void>('stopSpeaking');

  static Future<void> speechRate(double rate) => _call<void>('speechRate', <String, Object?>{'rate': rate});

  static Future<List<Map<Object?, Object?>>> voices() async =>
      (await _call<List<Object?>>('voices'))?.cast<Map<Object?, Object?>>() ?? const <Map<Object?, Object?>>[];

  static Future<void> setVoice(String? name) => _call<bool>('setVoice', <String, Object?>{'name': name});

  static Future<void> previewVoice(String name, String text) =>
      _call<bool>('preview', <String, Object?>{'name': name, 'text': text});

  static Future<void> openTtsSettings() => _call<bool>('ttsSettings');
}
