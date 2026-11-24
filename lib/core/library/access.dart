import 'package:flutter/foundation.dart';

import '../platform/platform.dart';

/// What Unfurl can say about a file it was asked to open again.
enum FileAccess {
  /// It opens.
  readable,

  /// Its exact location is known and Unfurl may not read it.
  noAccess,

  /// Android never said where it is: only the app that sent it can open it.
  unknown,

  /// Its exact location is known and it isn't there anymore.
  gone,
}

/// Sorts a file into its state. [exists] is null when Android can't tell;
/// then nothing is claimed to be gone.
FileAccess sortAccess({required bool readable, required String? docId, required bool? exists}) {
  if (readable) return FileAccess.readable;
  if (docId == null) return FileAccess.unknown;
  return exists == false ? FileAccess.gone : FileAccess.noAccess;
}

/// A location as the storage provider names it: `primary:Download/abc.pdf`.
extension type const DocId(String id) {
  String get volume => id.substring(0, id.indexOf(':'));
  String get path => id.substring(id.indexOf(':') + 1);

  /// The folder holding it (`primary:Download`; a volume's root is `primary:`).
  DocId get folder {
    final int slash = path.lastIndexOf('/');
    return DocId('$volume:${slash < 0 ? '' : path.substring(0, slash)}');
  }

  /// "Download › Reports", for people.
  String get label {
    if (path.isNotEmpty) return path.split('/').join(' › ');
    return volume == 'primary' ? 'Internal storage' : 'SD card';
  }

  /// Whether Android's folder picker gives this folder to apps. From Android
  /// 11 it refuses a volume's root, Download itself and Android, and hides
  /// Android/data and Android/obb (Android/media is fine; checked on API 30
  /// and 36, see specs/app-polish-2/decisions.md).
  bool grantable(int sdk) {
    if (sdk < 30) return true;
    final String p = path.toLowerCase();
    if (p.isEmpty || p == 'download' || p == 'android') return false;
    return !RegExp(r'^android/(data|obb)(/|$)').hasMatch(p);
  }
}

/// A file that can't be opened now, and what can be done about it.
@immutable
class AccessProblem {
  const AccessProblem({
    required this.state,
    required this.ref,
    this.docId,
    this.sender,
    this.exists,
    this.folderApp = false,
    this.sdk = 0,
  });

  final FileAccess state;
  final DocRef ref;

  /// The exact location, when Android gave one.
  final DocId? docId;

  /// The label of the app that sent it ("WhatsApp").
  final String? sender;

  /// Whether the file is still at [docId]; null when Android can't tell.
  final bool? exists;

  /// Some app on the phone shows folders.
  final bool folderApp;
  final int sdk;

  /// "Allow this folder" would work.
  bool get canAllow => state == FileAccess.noAccess && docId!.folder.grantable(sdk);

  /// "Open in file manager" would work (a file at its place, or its folder).
  bool get canShowFolder => state == FileAccess.noAccess && folderApp;
}
