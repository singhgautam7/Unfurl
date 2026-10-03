import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A document as the system describes it: a content URI with its name, size,
/// type and modified time. Unfurl never sees a file path.
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

  static void _listen() {
    if (_listening) return;
    _listening = true;
    _channel.setMethodCallHandler((MethodCall call) async {
      switch (call.method) {
        case 'intent':
          _arrivals.add(DocRef.fromMap(call.arguments as Map<Object?, Object?>));
        case 'volumeKey':
          _volumeKeys.add(call.arguments as int);
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

  /// Streams a folder tree in batches; errors when access was lost.
  static Stream<List<ScannedEntry>> scan(String treeUri) => _scan
      .receiveBroadcastStream(<String, Object?>{'uri': treeUri})
      .map(
        (Object? batch) =>
            (batch! as List<Object?>).map((Object? e) => ScannedEntry.fromMap(e! as Map<Object?, Object?>)).toList(),
      );

  static Future<bool> openWith(String uri, String? mime) async =>
      await _call<bool>('openWith', <String, Object?>{'uri': uri, 'mime': mime}) ?? false;

  static Future<void> shareFile(String uri, String? mime) =>
      _call<bool>('shareFile', <String, Object?>{'uri': uri, 'mime': mime});

  static Future<void> shareText(String text, {String? subject}) =>
      _call<bool>('shareText', <String, Object?>{'text': text, 'subject': subject});

  static Future<String?> appVersion() => _call<String>('appVersion');

  static Future<bool> isMullInstalled() async =>
      await _call<bool>('isInstalled', <String, Object?>{'package': mullPackage}) ?? false;

  static Future<bool> defineInMull(String text) async =>
      await _call<bool>('defineInMull', <String, Object?>{'text': text}) ?? false;

  static Future<void> openApp(String package) => _call<bool>('openApp', <String, Object?>{'package': package});

  static Future<void> openStore(String package) => _call<bool>('openStore', <String, Object?>{'package': package});

  static Future<void> openUrl(String url) => _call<bool>('openUrl', <String, Object?>{'url': url});

  static Future<void> email(String to, String subject) =>
      _call<bool>('email', <String, Object?>{'to': to, 'subject': subject});

  static Future<void> keepScreenOn({required bool on}) => _call<void>('keepScreenOn', <String, Object?>{'on': on});

  /// 0..1, or null to hand brightness back to the system.
  static Future<void> setBrightness(double? value) =>
      _call<void>('brightness', <String, Object?>{'value': value ?? -1.0});

  static Future<void> volumeKeys({required bool on}) => _call<void>('volumeKeys', <String, Object?>{'on': on});

  static Future<void> speak(String text, String id) => _call<bool>('speak', <String, Object?>{'text': text, 'id': id});

  static Future<void> stopSpeaking() => _call<void>('stopSpeaking');

  static Future<void> speechRate(double rate) => _call<void>('speechRate', <String, Object?>{'rate': rate});

  static Future<List<Map<Object?, Object?>>> voices() async =>
      (await _call<List<Object?>>('voices'))?.cast<Map<Object?, Object?>>() ?? const <Map<Object?, Object?>>[];

  static Future<void> setVoice(String? name) => _call<bool>('setVoice', <String, Object?>{'name': name});

  static Future<void> previewVoice(String name, String text) =>
      _call<bool>('preview', <String, Object?>{'name': name, 'text': text});

  static Future<void> openTtsSettings() => _call<bool>('ttsSettings');
}
