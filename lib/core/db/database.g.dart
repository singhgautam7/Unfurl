// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $FoldersTable extends Folders with TableInfo<$FoldersTable, Folder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scannedAtMeta = const VerificationMeta('scannedAt');
  @override
  late final GeneratedColumn<DateTime> scannedAt = GeneratedColumn<DateTime>(
    'scanned_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessLostMeta = const VerificationMeta('accessLost');
  @override
  late final GeneratedColumn<bool> accessLost = GeneratedColumn<bool>(
    'access_lost',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("access_lost" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, uri, name, path, addedAt, scannedAt, accessLost];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'folders';
  @override
  VerificationContext validateIntegrity(Insertable<Folder> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uri')) {
      context.handle(_uriMeta, uri.isAcceptableOrUnknown(data['uri']!, _uriMeta));
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('path')) {
      context.handle(_pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta, addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('scanned_at')) {
      context.handle(_scannedAtMeta, scannedAt.isAcceptableOrUnknown(data['scanned_at']!, _scannedAtMeta));
    }
    if (data.containsKey('access_lost')) {
      context.handle(_accessLostMeta, accessLost.isAcceptableOrUnknown(data['access_lost']!, _accessLostMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Folder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Folder(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      uri: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}uri'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      path: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      addedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
      scannedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}scanned_at']),
      accessLost: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}access_lost'])!,
    );
  }

  @override
  $FoldersTable createAlias(String alias) {
    return $FoldersTable(attachedDatabase, alias);
  }
}

class Folder extends DataClass implements Insertable<Folder> {
  final int id;
  final String uri;
  final String name;

  /// "Download › Darwin".
  final String path;
  final DateTime addedAt;
  final DateTime? scannedAt;
  final bool accessLost;
  const Folder({
    required this.id,
    required this.uri,
    required this.name,
    required this.path,
    required this.addedAt,
    this.scannedAt,
    required this.accessLost,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uri'] = Variable<String>(uri);
    map['name'] = Variable<String>(name);
    map['path'] = Variable<String>(path);
    map['added_at'] = Variable<DateTime>(addedAt);
    if (!nullToAbsent || scannedAt != null) {
      map['scanned_at'] = Variable<DateTime>(scannedAt);
    }
    map['access_lost'] = Variable<bool>(accessLost);
    return map;
  }

  FoldersCompanion toCompanion(bool nullToAbsent) {
    return FoldersCompanion(
      id: Value(id),
      uri: Value(uri),
      name: Value(name),
      path: Value(path),
      addedAt: Value(addedAt),
      scannedAt: scannedAt == null && nullToAbsent ? const Value.absent() : Value(scannedAt),
      accessLost: Value(accessLost),
    );
  }

  factory Folder.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Folder(
      id: serializer.fromJson<int>(json['id']),
      uri: serializer.fromJson<String>(json['uri']),
      name: serializer.fromJson<String>(json['name']),
      path: serializer.fromJson<String>(json['path']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      scannedAt: serializer.fromJson<DateTime?>(json['scannedAt']),
      accessLost: serializer.fromJson<bool>(json['accessLost']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uri': serializer.toJson<String>(uri),
      'name': serializer.toJson<String>(name),
      'path': serializer.toJson<String>(path),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'scannedAt': serializer.toJson<DateTime?>(scannedAt),
      'accessLost': serializer.toJson<bool>(accessLost),
    };
  }

  Folder copyWith({
    int? id,
    String? uri,
    String? name,
    String? path,
    DateTime? addedAt,
    Value<DateTime?> scannedAt = const Value.absent(),
    bool? accessLost,
  }) => Folder(
    id: id ?? this.id,
    uri: uri ?? this.uri,
    name: name ?? this.name,
    path: path ?? this.path,
    addedAt: addedAt ?? this.addedAt,
    scannedAt: scannedAt.present ? scannedAt.value : this.scannedAt,
    accessLost: accessLost ?? this.accessLost,
  );
  Folder copyWithCompanion(FoldersCompanion data) {
    return Folder(
      id: data.id.present ? data.id.value : this.id,
      uri: data.uri.present ? data.uri.value : this.uri,
      name: data.name.present ? data.name.value : this.name,
      path: data.path.present ? data.path.value : this.path,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      scannedAt: data.scannedAt.present ? data.scannedAt.value : this.scannedAt,
      accessLost: data.accessLost.present ? data.accessLost.value : this.accessLost,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Folder(')
          ..write('id: $id, ')
          ..write('uri: $uri, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('accessLost: $accessLost')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uri, name, path, addedAt, scannedAt, accessLost);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Folder &&
          other.id == this.id &&
          other.uri == this.uri &&
          other.name == this.name &&
          other.path == this.path &&
          other.addedAt == this.addedAt &&
          other.scannedAt == this.scannedAt &&
          other.accessLost == this.accessLost);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<int> id;
  final Value<String> uri;
  final Value<String> name;
  final Value<String> path;
  final Value<DateTime> addedAt;
  final Value<DateTime?> scannedAt;
  final Value<bool> accessLost;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.uri = const Value.absent(),
    this.name = const Value.absent(),
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.accessLost = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required String uri,
    required String name,
    this.path = const Value.absent(),
    required DateTime addedAt,
    this.scannedAt = const Value.absent(),
    this.accessLost = const Value.absent(),
  }) : uri = Value(uri),
       name = Value(name),
       addedAt = Value(addedAt);
  static Insertable<Folder> custom({
    Expression<int>? id,
    Expression<String>? uri,
    Expression<String>? name,
    Expression<String>? path,
    Expression<DateTime>? addedAt,
    Expression<DateTime>? scannedAt,
    Expression<bool>? accessLost,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uri != null) 'uri': uri,
      if (name != null) 'name': name,
      if (path != null) 'path': path,
      if (addedAt != null) 'added_at': addedAt,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (accessLost != null) 'access_lost': accessLost,
    });
  }

  FoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? uri,
    Value<String>? name,
    Value<String>? path,
    Value<DateTime>? addedAt,
    Value<DateTime?>? scannedAt,
    Value<bool>? accessLost,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      name: name ?? this.name,
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
      scannedAt: scannedAt ?? this.scannedAt,
      accessLost: accessLost ?? this.accessLost,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (scannedAt.present) {
      map['scanned_at'] = Variable<DateTime>(scannedAt.value);
    }
    if (accessLost.present) {
      map['access_lost'] = Variable<bool>(accessLost.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoldersCompanion(')
          ..write('id: $id, ')
          ..write('uri: $uri, ')
          ..write('name: $name, ')
          ..write('path: $path, ')
          ..write('addedAt: $addedAt, ')
          ..write('scannedAt: $scannedAt, ')
          ..write('accessLost: $accessLost')
          ..write(')'))
        .toString();
  }
}

class $EntriesTable extends Entries with TableInfo<$EntriesTable, Entry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $EntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta('folderId');
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('REFERENCES folders (id) ON DELETE CASCADE'),
  );
  static const VerificationMeta _docIdMeta = const VerificationMeta('docId');
  @override
  late final GeneratedColumn<String> docId = GeneratedColumn<String>(
    'doc_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _parentMeta = const VerificationMeta('parent');
  @override
  late final GeneratedColumn<String> parent = GeneratedColumn<String>(
    'parent',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _extMeta = const VerificationMeta('ext');
  @override
  late final GeneratedColumn<String> ext = GeneratedColumn<String>(
    'ext',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDirMeta = const VerificationMeta('isDir');
  @override
  late final GeneratedColumn<bool> isDir = GeneratedColumn<bool>(
    'is_dir',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("is_dir" IN (0, 1))'),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modifiedMeta = const VerificationMeta('modified');
  @override
  late final GeneratedColumn<int> modified = GeneratedColumn<int>(
    'modified',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta('fingerprint');
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<int> units = GeneratedColumn<int>(
    'units',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _enrichedMeta = const VerificationMeta('enriched');
  @override
  late final GeneratedColumn<int> enriched = GeneratedColumn<int>(
    'enriched',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _hiddenMeta = const VerificationMeta('hidden');
  @override
  late final GeneratedColumn<bool> hidden = GeneratedColumn<bool>(
    'hidden',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("hidden" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folderId,
    docId,
    uri,
    parent,
    name,
    ext,
    mime,
    isDir,
    size,
    modified,
    fingerprint,
    title,
    author,
    units,
    enriched,
    hidden,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'entries';
  @override
  VerificationContext validateIntegrity(Insertable<Entry> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('folder_id')) {
      context.handle(_folderIdMeta, folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta));
    } else if (isInserting) {
      context.missing(_folderIdMeta);
    }
    if (data.containsKey('doc_id')) {
      context.handle(_docIdMeta, docId.isAcceptableOrUnknown(data['doc_id']!, _docIdMeta));
    } else if (isInserting) {
      context.missing(_docIdMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(_uriMeta, uri.isAcceptableOrUnknown(data['uri']!, _uriMeta));
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('parent')) {
      context.handle(_parentMeta, parent.isAcceptableOrUnknown(data['parent']!, _parentMeta));
    } else if (isInserting) {
      context.missing(_parentMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('ext')) {
      context.handle(_extMeta, ext.isAcceptableOrUnknown(data['ext']!, _extMeta));
    } else if (isInserting) {
      context.missing(_extMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(_mimeMeta, mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta));
    }
    if (data.containsKey('is_dir')) {
      context.handle(_isDirMeta, isDir.isAcceptableOrUnknown(data['is_dir']!, _isDirMeta));
    } else if (isInserting) {
      context.missing(_isDirMeta);
    }
    if (data.containsKey('size')) {
      context.handle(_sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('modified')) {
      context.handle(_modifiedMeta, modified.isAcceptableOrUnknown(data['modified']!, _modifiedMeta));
    }
    if (data.containsKey('fingerprint')) {
      context.handle(_fingerprintMeta, fingerprint.isAcceptableOrUnknown(data['fingerprint']!, _fingerprintMeta));
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta, author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    }
    if (data.containsKey('units')) {
      context.handle(_unitsMeta, units.isAcceptableOrUnknown(data['units']!, _unitsMeta));
    }
    if (data.containsKey('enriched')) {
      context.handle(_enrichedMeta, enriched.isAcceptableOrUnknown(data['enriched']!, _enrichedMeta));
    }
    if (data.containsKey('hidden')) {
      context.handle(_hiddenMeta, hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {folderId, docId},
  ];
  @override
  Entry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Entry(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      folderId: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}folder_id'])!,
      docId: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}doc_id'])!,
      uri: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}uri'])!,
      parent: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}parent'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      ext: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}ext'])!,
      mime: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mime']),
      isDir: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}is_dir'])!,
      size: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}size'])!,
      modified: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}modified'])!,
      fingerprint: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fingerprint']),
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title']),
      author: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}author']),
      units: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}units']),
      enriched: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}enriched'])!,
      hidden: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}hidden'])!,
    );
  }

  @override
  $EntriesTable createAlias(String alias) {
    return $EntriesTable(attachedDatabase, alias);
  }
}

class Entry extends DataClass implements Insertable<Entry> {
  final int id;
  final int folderId;
  final String docId;
  final String uri;

  /// Directory relative to the folder root, '' at the root.
  final String parent;
  final String name;
  final String ext;
  final String? mime;
  final bool isDir;
  final int size;
  final int modified;

  /// Filled when the file is first read (opened or enriched).
  final String? fingerprint;
  final String? title;
  final String? author;

  /// Pages (PDF) or chapters (EPUB).
  final int? units;

  /// 0 never read, 1 metadata read, -1 unreadable.
  final int enriched;

  /// "Remove from library": hidden here; the file stays on the phone.
  final bool hidden;
  const Entry({
    required this.id,
    required this.folderId,
    required this.docId,
    required this.uri,
    required this.parent,
    required this.name,
    required this.ext,
    this.mime,
    required this.isDir,
    required this.size,
    required this.modified,
    this.fingerprint,
    this.title,
    this.author,
    this.units,
    required this.enriched,
    required this.hidden,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['folder_id'] = Variable<int>(folderId);
    map['doc_id'] = Variable<String>(docId);
    map['uri'] = Variable<String>(uri);
    map['parent'] = Variable<String>(parent);
    map['name'] = Variable<String>(name);
    map['ext'] = Variable<String>(ext);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    map['is_dir'] = Variable<bool>(isDir);
    map['size'] = Variable<int>(size);
    map['modified'] = Variable<int>(modified);
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || units != null) {
      map['units'] = Variable<int>(units);
    }
    map['enriched'] = Variable<int>(enriched);
    map['hidden'] = Variable<bool>(hidden);
    return map;
  }

  EntriesCompanion toCompanion(bool nullToAbsent) {
    return EntriesCompanion(
      id: Value(id),
      folderId: Value(folderId),
      docId: Value(docId),
      uri: Value(uri),
      parent: Value(parent),
      name: Value(name),
      ext: Value(ext),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      isDir: Value(isDir),
      size: Value(size),
      modified: Value(modified),
      fingerprint: fingerprint == null && nullToAbsent ? const Value.absent() : Value(fingerprint),
      title: title == null && nullToAbsent ? const Value.absent() : Value(title),
      author: author == null && nullToAbsent ? const Value.absent() : Value(author),
      units: units == null && nullToAbsent ? const Value.absent() : Value(units),
      enriched: Value(enriched),
      hidden: Value(hidden),
    );
  }

  factory Entry.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Entry(
      id: serializer.fromJson<int>(json['id']),
      folderId: serializer.fromJson<int>(json['folderId']),
      docId: serializer.fromJson<String>(json['docId']),
      uri: serializer.fromJson<String>(json['uri']),
      parent: serializer.fromJson<String>(json['parent']),
      name: serializer.fromJson<String>(json['name']),
      ext: serializer.fromJson<String>(json['ext']),
      mime: serializer.fromJson<String?>(json['mime']),
      isDir: serializer.fromJson<bool>(json['isDir']),
      size: serializer.fromJson<int>(json['size']),
      modified: serializer.fromJson<int>(json['modified']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      title: serializer.fromJson<String?>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      units: serializer.fromJson<int?>(json['units']),
      enriched: serializer.fromJson<int>(json['enriched']),
      hidden: serializer.fromJson<bool>(json['hidden']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'folderId': serializer.toJson<int>(folderId),
      'docId': serializer.toJson<String>(docId),
      'uri': serializer.toJson<String>(uri),
      'parent': serializer.toJson<String>(parent),
      'name': serializer.toJson<String>(name),
      'ext': serializer.toJson<String>(ext),
      'mime': serializer.toJson<String?>(mime),
      'isDir': serializer.toJson<bool>(isDir),
      'size': serializer.toJson<int>(size),
      'modified': serializer.toJson<int>(modified),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'title': serializer.toJson<String?>(title),
      'author': serializer.toJson<String?>(author),
      'units': serializer.toJson<int?>(units),
      'enriched': serializer.toJson<int>(enriched),
      'hidden': serializer.toJson<bool>(hidden),
    };
  }

  Entry copyWith({
    int? id,
    int? folderId,
    String? docId,
    String? uri,
    String? parent,
    String? name,
    String? ext,
    Value<String?> mime = const Value.absent(),
    bool? isDir,
    int? size,
    int? modified,
    Value<String?> fingerprint = const Value.absent(),
    Value<String?> title = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<int?> units = const Value.absent(),
    int? enriched,
    bool? hidden,
  }) => Entry(
    id: id ?? this.id,
    folderId: folderId ?? this.folderId,
    docId: docId ?? this.docId,
    uri: uri ?? this.uri,
    parent: parent ?? this.parent,
    name: name ?? this.name,
    ext: ext ?? this.ext,
    mime: mime.present ? mime.value : this.mime,
    isDir: isDir ?? this.isDir,
    size: size ?? this.size,
    modified: modified ?? this.modified,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    title: title.present ? title.value : this.title,
    author: author.present ? author.value : this.author,
    units: units.present ? units.value : this.units,
    enriched: enriched ?? this.enriched,
    hidden: hidden ?? this.hidden,
  );
  Entry copyWithCompanion(EntriesCompanion data) {
    return Entry(
      id: data.id.present ? data.id.value : this.id,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      docId: data.docId.present ? data.docId.value : this.docId,
      uri: data.uri.present ? data.uri.value : this.uri,
      parent: data.parent.present ? data.parent.value : this.parent,
      name: data.name.present ? data.name.value : this.name,
      ext: data.ext.present ? data.ext.value : this.ext,
      mime: data.mime.present ? data.mime.value : this.mime,
      isDir: data.isDir.present ? data.isDir.value : this.isDir,
      size: data.size.present ? data.size.value : this.size,
      modified: data.modified.present ? data.modified.value : this.modified,
      fingerprint: data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      units: data.units.present ? data.units.value : this.units,
      enriched: data.enriched.present ? data.enriched.value : this.enriched,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Entry(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('docId: $docId, ')
          ..write('uri: $uri, ')
          ..write('parent: $parent, ')
          ..write('name: $name, ')
          ..write('ext: $ext, ')
          ..write('mime: $mime, ')
          ..write('isDir: $isDir, ')
          ..write('size: $size, ')
          ..write('modified: $modified, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('units: $units, ')
          ..write('enriched: $enriched, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    folderId,
    docId,
    uri,
    parent,
    name,
    ext,
    mime,
    isDir,
    size,
    modified,
    fingerprint,
    title,
    author,
    units,
    enriched,
    hidden,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Entry &&
          other.id == this.id &&
          other.folderId == this.folderId &&
          other.docId == this.docId &&
          other.uri == this.uri &&
          other.parent == this.parent &&
          other.name == this.name &&
          other.ext == this.ext &&
          other.mime == this.mime &&
          other.isDir == this.isDir &&
          other.size == this.size &&
          other.modified == this.modified &&
          other.fingerprint == this.fingerprint &&
          other.title == this.title &&
          other.author == this.author &&
          other.units == this.units &&
          other.enriched == this.enriched &&
          other.hidden == this.hidden);
}

class EntriesCompanion extends UpdateCompanion<Entry> {
  final Value<int> id;
  final Value<int> folderId;
  final Value<String> docId;
  final Value<String> uri;
  final Value<String> parent;
  final Value<String> name;
  final Value<String> ext;
  final Value<String?> mime;
  final Value<bool> isDir;
  final Value<int> size;
  final Value<int> modified;
  final Value<String?> fingerprint;
  final Value<String?> title;
  final Value<String?> author;
  final Value<int?> units;
  final Value<int> enriched;
  final Value<bool> hidden;
  const EntriesCompanion({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    this.docId = const Value.absent(),
    this.uri = const Value.absent(),
    this.parent = const Value.absent(),
    this.name = const Value.absent(),
    this.ext = const Value.absent(),
    this.mime = const Value.absent(),
    this.isDir = const Value.absent(),
    this.size = const Value.absent(),
    this.modified = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.units = const Value.absent(),
    this.enriched = const Value.absent(),
    this.hidden = const Value.absent(),
  });
  EntriesCompanion.insert({
    this.id = const Value.absent(),
    required int folderId,
    required String docId,
    required String uri,
    required String parent,
    required String name,
    required String ext,
    this.mime = const Value.absent(),
    required bool isDir,
    this.size = const Value.absent(),
    this.modified = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.units = const Value.absent(),
    this.enriched = const Value.absent(),
    this.hidden = const Value.absent(),
  }) : folderId = Value(folderId),
       docId = Value(docId),
       uri = Value(uri),
       parent = Value(parent),
       name = Value(name),
       ext = Value(ext),
       isDir = Value(isDir);
  static Insertable<Entry> custom({
    Expression<int>? id,
    Expression<int>? folderId,
    Expression<String>? docId,
    Expression<String>? uri,
    Expression<String>? parent,
    Expression<String>? name,
    Expression<String>? ext,
    Expression<String>? mime,
    Expression<bool>? isDir,
    Expression<int>? size,
    Expression<int>? modified,
    Expression<String>? fingerprint,
    Expression<String>? title,
    Expression<String>? author,
    Expression<int>? units,
    Expression<int>? enriched,
    Expression<bool>? hidden,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderId != null) 'folder_id': folderId,
      if (docId != null) 'doc_id': docId,
      if (uri != null) 'uri': uri,
      if (parent != null) 'parent': parent,
      if (name != null) 'name': name,
      if (ext != null) 'ext': ext,
      if (mime != null) 'mime': mime,
      if (isDir != null) 'is_dir': isDir,
      if (size != null) 'size': size,
      if (modified != null) 'modified': modified,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (units != null) 'units': units,
      if (enriched != null) 'enriched': enriched,
      if (hidden != null) 'hidden': hidden,
    });
  }

  EntriesCompanion copyWith({
    Value<int>? id,
    Value<int>? folderId,
    Value<String>? docId,
    Value<String>? uri,
    Value<String>? parent,
    Value<String>? name,
    Value<String>? ext,
    Value<String?>? mime,
    Value<bool>? isDir,
    Value<int>? size,
    Value<int>? modified,
    Value<String?>? fingerprint,
    Value<String?>? title,
    Value<String?>? author,
    Value<int?>? units,
    Value<int>? enriched,
    Value<bool>? hidden,
  }) {
    return EntriesCompanion(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      docId: docId ?? this.docId,
      uri: uri ?? this.uri,
      parent: parent ?? this.parent,
      name: name ?? this.name,
      ext: ext ?? this.ext,
      mime: mime ?? this.mime,
      isDir: isDir ?? this.isDir,
      size: size ?? this.size,
      modified: modified ?? this.modified,
      fingerprint: fingerprint ?? this.fingerprint,
      title: title ?? this.title,
      author: author ?? this.author,
      units: units ?? this.units,
      enriched: enriched ?? this.enriched,
      hidden: hidden ?? this.hidden,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (docId.present) {
      map['doc_id'] = Variable<String>(docId.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (parent.present) {
      map['parent'] = Variable<String>(parent.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (ext.present) {
      map['ext'] = Variable<String>(ext.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (isDir.present) {
      map['is_dir'] = Variable<bool>(isDir.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (modified.present) {
      map['modified'] = Variable<int>(modified.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (units.present) {
      map['units'] = Variable<int>(units.value);
    }
    if (enriched.present) {
      map['enriched'] = Variable<int>(enriched.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('EntriesCompanion(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('docId: $docId, ')
          ..write('uri: $uri, ')
          ..write('parent: $parent, ')
          ..write('name: $name, ')
          ..write('ext: $ext, ')
          ..write('mime: $mime, ')
          ..write('isDir: $isDir, ')
          ..write('size: $size, ')
          ..write('modified: $modified, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('units: $units, ')
          ..write('enriched: $enriched, ')
          ..write('hidden: $hidden')
          ..write(')'))
        .toString();
  }
}

class $DocumentsTable extends Documents with TableInfo<$DocumentsTable, Document> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DocumentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fingerprintMeta = const VerificationMeta('fingerprint');
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _authorMeta = const VerificationMeta('author');
  @override
  late final GeneratedColumn<String> author = GeneratedColumn<String>(
    'author',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _positionMeta = const VerificationMeta('position');
  @override
  late final GeneratedColumn<String> position = GeneratedColumn<String>(
    'position',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _progressMeta = const VerificationMeta('progress');
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedMeta = const VerificationMeta('finished');
  @override
  late final GeneratedColumn<bool> finished = GeneratedColumn<bool>(
    'finished',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("finished" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _unitsMeta = const VerificationMeta('units');
  @override
  late final GeneratedColumn<int> units = GeneratedColumn<int>(
    'units',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _whereMeta = const VerificationMeta('where');
  @override
  late final GeneratedColumn<String> where = GeneratedColumn<String>(
    'where',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta('openedAt');
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readMsMeta = const VerificationMeta('readMs');
  @override
  late final GeneratedColumn<int> readMs = GeneratedColumn<int>(
    'read_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readWordsMeta = const VerificationMeta('readWords');
  @override
  late final GeneratedColumn<int> readWords = GeneratedColumn<int>(
    'read_words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    fingerprint,
    uri,
    name,
    format,
    title,
    author,
    position,
    progress,
    mode,
    finished,
    units,
    where,
    openedAt,
    addedAt,
    readMs,
    readWords,
    size,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'documents';
  @override
  VerificationContext validateIntegrity(Insertable<Document> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fingerprint')) {
      context.handle(_fingerprintMeta, fingerprint.isAcceptableOrUnknown(data['fingerprint']!, _fingerprintMeta));
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('uri')) {
      context.handle(_uriMeta, uri.isAcceptableOrUnknown(data['uri']!, _uriMeta));
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('format')) {
      context.handle(_formatMeta, format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('title')) {
      context.handle(_titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    }
    if (data.containsKey('author')) {
      context.handle(_authorMeta, author.isAcceptableOrUnknown(data['author']!, _authorMeta));
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta, position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta, progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(_modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    }
    if (data.containsKey('finished')) {
      context.handle(_finishedMeta, finished.isAcceptableOrUnknown(data['finished']!, _finishedMeta));
    }
    if (data.containsKey('units')) {
      context.handle(_unitsMeta, units.isAcceptableOrUnknown(data['units']!, _unitsMeta));
    }
    if (data.containsKey('where')) {
      context.handle(_whereMeta, where.isAcceptableOrUnknown(data['where']!, _whereMeta));
    }
    if (data.containsKey('opened_at')) {
      context.handle(_openedAtMeta, openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta));
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta, addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    if (data.containsKey('read_ms')) {
      context.handle(_readMsMeta, readMs.isAcceptableOrUnknown(data['read_ms']!, _readMsMeta));
    }
    if (data.containsKey('read_words')) {
      context.handle(_readWordsMeta, readWords.isAcceptableOrUnknown(data['read_words']!, _readWordsMeta));
    }
    if (data.containsKey('size')) {
      context.handle(_sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fingerprint};
  @override
  Document map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Document(
      fingerprint: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fingerprint'])!,
      uri: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}uri'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      format: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      title: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}title']),
      author: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}author']),
      position: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}position']),
      progress: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}progress'])!,
      mode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mode']),
      finished: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}finished'])!,
      units: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}units']),
      where: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}where']),
      openedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}opened_at']),
      addedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
      readMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}read_ms'])!,
      readWords: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}read_words'])!,
      size: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}size'])!,
    );
  }

  @override
  $DocumentsTable createAlias(String alias) {
    return $DocumentsTable(attachedDatabase, alias);
  }
}

class Document extends DataClass implements Insertable<Document> {
  final String fingerprint;

  /// Where it was last seen.
  final String uri;
  final String name;
  final String format;
  final String? title;
  final String? author;

  /// The reading position, a `Locator` (data rule 3).
  final String? position;
  final double progress;

  /// 'page' or 'reader': resume reopens in the mode last used.
  final String? mode;
  final bool finished;
  final int? units;

  /// Where the position sits, for display: "Chapter 34", "Page 207 of 502".
  final String? where;
  final DateTime? openedAt;
  final DateTime addedAt;

  /// Reading pace, for "6 min left in chapter".
  final int readMs;
  final int readWords;
  final int size;
  const Document({
    required this.fingerprint,
    required this.uri,
    required this.name,
    required this.format,
    this.title,
    this.author,
    this.position,
    required this.progress,
    this.mode,
    required this.finished,
    this.units,
    this.where,
    this.openedAt,
    required this.addedAt,
    required this.readMs,
    required this.readWords,
    required this.size,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fingerprint'] = Variable<String>(fingerprint);
    map['uri'] = Variable<String>(uri);
    map['name'] = Variable<String>(name);
    map['format'] = Variable<String>(format);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    if (!nullToAbsent || author != null) {
      map['author'] = Variable<String>(author);
    }
    if (!nullToAbsent || position != null) {
      map['position'] = Variable<String>(position);
    }
    map['progress'] = Variable<double>(progress);
    if (!nullToAbsent || mode != null) {
      map['mode'] = Variable<String>(mode);
    }
    map['finished'] = Variable<bool>(finished);
    if (!nullToAbsent || units != null) {
      map['units'] = Variable<int>(units);
    }
    if (!nullToAbsent || where != null) {
      map['where'] = Variable<String>(where);
    }
    if (!nullToAbsent || openedAt != null) {
      map['opened_at'] = Variable<DateTime>(openedAt);
    }
    map['added_at'] = Variable<DateTime>(addedAt);
    map['read_ms'] = Variable<int>(readMs);
    map['read_words'] = Variable<int>(readWords);
    map['size'] = Variable<int>(size);
    return map;
  }

  DocumentsCompanion toCompanion(bool nullToAbsent) {
    return DocumentsCompanion(
      fingerprint: Value(fingerprint),
      uri: Value(uri),
      name: Value(name),
      format: Value(format),
      title: title == null && nullToAbsent ? const Value.absent() : Value(title),
      author: author == null && nullToAbsent ? const Value.absent() : Value(author),
      position: position == null && nullToAbsent ? const Value.absent() : Value(position),
      progress: Value(progress),
      mode: mode == null && nullToAbsent ? const Value.absent() : Value(mode),
      finished: Value(finished),
      units: units == null && nullToAbsent ? const Value.absent() : Value(units),
      where: where == null && nullToAbsent ? const Value.absent() : Value(where),
      openedAt: openedAt == null && nullToAbsent ? const Value.absent() : Value(openedAt),
      addedAt: Value(addedAt),
      readMs: Value(readMs),
      readWords: Value(readWords),
      size: Value(size),
    );
  }

  factory Document.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Document(
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      uri: serializer.fromJson<String>(json['uri']),
      name: serializer.fromJson<String>(json['name']),
      format: serializer.fromJson<String>(json['format']),
      title: serializer.fromJson<String?>(json['title']),
      author: serializer.fromJson<String?>(json['author']),
      position: serializer.fromJson<String?>(json['position']),
      progress: serializer.fromJson<double>(json['progress']),
      mode: serializer.fromJson<String?>(json['mode']),
      finished: serializer.fromJson<bool>(json['finished']),
      units: serializer.fromJson<int?>(json['units']),
      where: serializer.fromJson<String?>(json['where']),
      openedAt: serializer.fromJson<DateTime?>(json['openedAt']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
      readMs: serializer.fromJson<int>(json['readMs']),
      readWords: serializer.fromJson<int>(json['readWords']),
      size: serializer.fromJson<int>(json['size']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fingerprint': serializer.toJson<String>(fingerprint),
      'uri': serializer.toJson<String>(uri),
      'name': serializer.toJson<String>(name),
      'format': serializer.toJson<String>(format),
      'title': serializer.toJson<String?>(title),
      'author': serializer.toJson<String?>(author),
      'position': serializer.toJson<String?>(position),
      'progress': serializer.toJson<double>(progress),
      'mode': serializer.toJson<String?>(mode),
      'finished': serializer.toJson<bool>(finished),
      'units': serializer.toJson<int?>(units),
      'where': serializer.toJson<String?>(where),
      'openedAt': serializer.toJson<DateTime?>(openedAt),
      'addedAt': serializer.toJson<DateTime>(addedAt),
      'readMs': serializer.toJson<int>(readMs),
      'readWords': serializer.toJson<int>(readWords),
      'size': serializer.toJson<int>(size),
    };
  }

  Document copyWith({
    String? fingerprint,
    String? uri,
    String? name,
    String? format,
    Value<String?> title = const Value.absent(),
    Value<String?> author = const Value.absent(),
    Value<String?> position = const Value.absent(),
    double? progress,
    Value<String?> mode = const Value.absent(),
    bool? finished,
    Value<int?> units = const Value.absent(),
    Value<String?> where = const Value.absent(),
    Value<DateTime?> openedAt = const Value.absent(),
    DateTime? addedAt,
    int? readMs,
    int? readWords,
    int? size,
  }) => Document(
    fingerprint: fingerprint ?? this.fingerprint,
    uri: uri ?? this.uri,
    name: name ?? this.name,
    format: format ?? this.format,
    title: title.present ? title.value : this.title,
    author: author.present ? author.value : this.author,
    position: position.present ? position.value : this.position,
    progress: progress ?? this.progress,
    mode: mode.present ? mode.value : this.mode,
    finished: finished ?? this.finished,
    units: units.present ? units.value : this.units,
    where: where.present ? where.value : this.where,
    openedAt: openedAt.present ? openedAt.value : this.openedAt,
    addedAt: addedAt ?? this.addedAt,
    readMs: readMs ?? this.readMs,
    readWords: readWords ?? this.readWords,
    size: size ?? this.size,
  );
  Document copyWithCompanion(DocumentsCompanion data) {
    return Document(
      fingerprint: data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
      uri: data.uri.present ? data.uri.value : this.uri,
      name: data.name.present ? data.name.value : this.name,
      format: data.format.present ? data.format.value : this.format,
      title: data.title.present ? data.title.value : this.title,
      author: data.author.present ? data.author.value : this.author,
      position: data.position.present ? data.position.value : this.position,
      progress: data.progress.present ? data.progress.value : this.progress,
      mode: data.mode.present ? data.mode.value : this.mode,
      finished: data.finished.present ? data.finished.value : this.finished,
      units: data.units.present ? data.units.value : this.units,
      where: data.where.present ? data.where.value : this.where,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
      readMs: data.readMs.present ? data.readMs.value : this.readMs,
      readWords: data.readWords.present ? data.readWords.value : this.readWords,
      size: data.size.present ? data.size.value : this.size,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Document(')
          ..write('fingerprint: $fingerprint, ')
          ..write('uri: $uri, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('position: $position, ')
          ..write('progress: $progress, ')
          ..write('mode: $mode, ')
          ..write('finished: $finished, ')
          ..write('units: $units, ')
          ..write('where: $where, ')
          ..write('openedAt: $openedAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('readMs: $readMs, ')
          ..write('readWords: $readWords, ')
          ..write('size: $size')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fingerprint,
    uri,
    name,
    format,
    title,
    author,
    position,
    progress,
    mode,
    finished,
    units,
    where,
    openedAt,
    addedAt,
    readMs,
    readWords,
    size,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Document &&
          other.fingerprint == this.fingerprint &&
          other.uri == this.uri &&
          other.name == this.name &&
          other.format == this.format &&
          other.title == this.title &&
          other.author == this.author &&
          other.position == this.position &&
          other.progress == this.progress &&
          other.mode == this.mode &&
          other.finished == this.finished &&
          other.units == this.units &&
          other.where == this.where &&
          other.openedAt == this.openedAt &&
          other.addedAt == this.addedAt &&
          other.readMs == this.readMs &&
          other.readWords == this.readWords &&
          other.size == this.size);
}

class DocumentsCompanion extends UpdateCompanion<Document> {
  final Value<String> fingerprint;
  final Value<String> uri;
  final Value<String> name;
  final Value<String> format;
  final Value<String?> title;
  final Value<String?> author;
  final Value<String?> position;
  final Value<double> progress;
  final Value<String?> mode;
  final Value<bool> finished;
  final Value<int?> units;
  final Value<String?> where;
  final Value<DateTime?> openedAt;
  final Value<DateTime> addedAt;
  final Value<int> readMs;
  final Value<int> readWords;
  final Value<int> size;
  final Value<int> rowid;
  const DocumentsCompanion({
    this.fingerprint = const Value.absent(),
    this.uri = const Value.absent(),
    this.name = const Value.absent(),
    this.format = const Value.absent(),
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.position = const Value.absent(),
    this.progress = const Value.absent(),
    this.mode = const Value.absent(),
    this.finished = const Value.absent(),
    this.units = const Value.absent(),
    this.where = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.readMs = const Value.absent(),
    this.readWords = const Value.absent(),
    this.size = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DocumentsCompanion.insert({
    required String fingerprint,
    required String uri,
    required String name,
    required String format,
    this.title = const Value.absent(),
    this.author = const Value.absent(),
    this.position = const Value.absent(),
    this.progress = const Value.absent(),
    this.mode = const Value.absent(),
    this.finished = const Value.absent(),
    this.units = const Value.absent(),
    this.where = const Value.absent(),
    this.openedAt = const Value.absent(),
    required DateTime addedAt,
    this.readMs = const Value.absent(),
    this.readWords = const Value.absent(),
    this.size = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fingerprint = Value(fingerprint),
       uri = Value(uri),
       name = Value(name),
       format = Value(format),
       addedAt = Value(addedAt);
  static Insertable<Document> custom({
    Expression<String>? fingerprint,
    Expression<String>? uri,
    Expression<String>? name,
    Expression<String>? format,
    Expression<String>? title,
    Expression<String>? author,
    Expression<String>? position,
    Expression<double>? progress,
    Expression<String>? mode,
    Expression<bool>? finished,
    Expression<int>? units,
    Expression<String>? where,
    Expression<DateTime>? openedAt,
    Expression<DateTime>? addedAt,
    Expression<int>? readMs,
    Expression<int>? readWords,
    Expression<int>? size,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (uri != null) 'uri': uri,
      if (name != null) 'name': name,
      if (format != null) 'format': format,
      if (title != null) 'title': title,
      if (author != null) 'author': author,
      if (position != null) 'position': position,
      if (progress != null) 'progress': progress,
      if (mode != null) 'mode': mode,
      if (finished != null) 'finished': finished,
      if (units != null) 'units': units,
      if (where != null) 'where': where,
      if (openedAt != null) 'opened_at': openedAt,
      if (addedAt != null) 'added_at': addedAt,
      if (readMs != null) 'read_ms': readMs,
      if (readWords != null) 'read_words': readWords,
      if (size != null) 'size': size,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DocumentsCompanion copyWith({
    Value<String>? fingerprint,
    Value<String>? uri,
    Value<String>? name,
    Value<String>? format,
    Value<String?>? title,
    Value<String?>? author,
    Value<String?>? position,
    Value<double>? progress,
    Value<String?>? mode,
    Value<bool>? finished,
    Value<int?>? units,
    Value<String?>? where,
    Value<DateTime?>? openedAt,
    Value<DateTime>? addedAt,
    Value<int>? readMs,
    Value<int>? readWords,
    Value<int>? size,
    Value<int>? rowid,
  }) {
    return DocumentsCompanion(
      fingerprint: fingerprint ?? this.fingerprint,
      uri: uri ?? this.uri,
      name: name ?? this.name,
      format: format ?? this.format,
      title: title ?? this.title,
      author: author ?? this.author,
      position: position ?? this.position,
      progress: progress ?? this.progress,
      mode: mode ?? this.mode,
      finished: finished ?? this.finished,
      units: units ?? this.units,
      where: where ?? this.where,
      openedAt: openedAt ?? this.openedAt,
      addedAt: addedAt ?? this.addedAt,
      readMs: readMs ?? this.readMs,
      readWords: readWords ?? this.readWords,
      size: size ?? this.size,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (author.present) {
      map['author'] = Variable<String>(author.value);
    }
    if (position.present) {
      map['position'] = Variable<String>(position.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (finished.present) {
      map['finished'] = Variable<bool>(finished.value);
    }
    if (units.present) {
      map['units'] = Variable<int>(units.value);
    }
    if (where.present) {
      map['where'] = Variable<String>(where.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (readMs.present) {
      map['read_ms'] = Variable<int>(readMs.value);
    }
    if (readWords.present) {
      map['read_words'] = Variable<int>(readWords.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DocumentsCompanion(')
          ..write('fingerprint: $fingerprint, ')
          ..write('uri: $uri, ')
          ..write('name: $name, ')
          ..write('format: $format, ')
          ..write('title: $title, ')
          ..write('author: $author, ')
          ..write('position: $position, ')
          ..write('progress: $progress, ')
          ..write('mode: $mode, ')
          ..write('finished: $finished, ')
          ..write('units: $units, ')
          ..write('where: $where, ')
          ..write('openedAt: $openedAt, ')
          ..write('addedAt: $addedAt, ')
          ..write('readMs: $readMs, ')
          ..write('readWords: $readWords, ')
          ..write('size: $size, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AnnotationsTable extends Annotations with TableInfo<$AnnotationsTable, Annotation> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AnnotationsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'),
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta('fingerprint');
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorMeta = const VerificationMeta('color');
  @override
  late final GeneratedColumn<int> color = GeneratedColumn<int>(
    'color',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _locatorMeta = const VerificationMeta('locator');
  @override
  late final GeneratedColumn<String> locator = GeneratedColumn<String>(
    'locator',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _quoteMeta = const VerificationMeta('quote');
  @override
  late final GeneratedColumn<String> quote = GeneratedColumn<String>(
    'quote',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _progressMeta = const VerificationMeta('progress');
  @override
  late final GeneratedColumn<double> progress = GeneratedColumn<double>(
    'progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('reader'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fingerprint,
    kind,
    color,
    locator,
    quote,
    note,
    label,
    progress,
    mode,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'annotations';
  @override
  VerificationContext validateIntegrity(Insertable<Annotation> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('fingerprint')) {
      context.handle(_fingerprintMeta, fingerprint.isAcceptableOrUnknown(data['fingerprint']!, _fingerprintMeta));
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(_kindMeta, kind.isAcceptableOrUnknown(data['kind']!, _kindMeta));
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('color')) {
      context.handle(_colorMeta, color.isAcceptableOrUnknown(data['color']!, _colorMeta));
    }
    if (data.containsKey('locator')) {
      context.handle(_locatorMeta, locator.isAcceptableOrUnknown(data['locator']!, _locatorMeta));
    } else if (isInserting) {
      context.missing(_locatorMeta);
    }
    if (data.containsKey('quote')) {
      context.handle(_quoteMeta, quote.isAcceptableOrUnknown(data['quote']!, _quoteMeta));
    }
    if (data.containsKey('note')) {
      context.handle(_noteMeta, note.isAcceptableOrUnknown(data['note']!, _noteMeta));
    }
    if (data.containsKey('label')) {
      context.handle(_labelMeta, label.isAcceptableOrUnknown(data['label']!, _labelMeta));
    }
    if (data.containsKey('progress')) {
      context.handle(_progressMeta, progress.isAcceptableOrUnknown(data['progress']!, _progressMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(_modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta, createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Annotation map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Annotation(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      fingerprint: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fingerprint'])!,
      kind: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}kind'])!,
      color: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}color']),
      locator: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}locator'])!,
      quote: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}quote'])!,
      note: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}note']),
      label: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}label'])!,
      progress: attachedDatabase.typeMapping.read(DriftSqlType.double, data['${effectivePrefix}progress'])!,
      mode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      createdAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $AnnotationsTable createAlias(String alias) {
    return $AnnotationsTable(attachedDatabase, alias);
  }
}

class Annotation extends DataClass implements Insertable<Annotation> {
  final int id;
  final String fingerprint;

  /// 'highlight' or 'bookmark'. A highlight with [note] is a note.
  final String kind;

  /// `HighlightColor` index.
  final int? color;
  final String locator;
  final String quote;
  final String? note;

  /// "Ch. 34 · 62%", "p. 62".
  final String label;
  final double progress;

  /// The mode it was made in, so a tap reopens there.
  final String mode;
  final DateTime createdAt;
  const Annotation({
    required this.id,
    required this.fingerprint,
    required this.kind,
    this.color,
    required this.locator,
    required this.quote,
    this.note,
    required this.label,
    required this.progress,
    required this.mode,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['kind'] = Variable<String>(kind);
    if (!nullToAbsent || color != null) {
      map['color'] = Variable<int>(color);
    }
    map['locator'] = Variable<String>(locator);
    map['quote'] = Variable<String>(quote);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['label'] = Variable<String>(label);
    map['progress'] = Variable<double>(progress);
    map['mode'] = Variable<String>(mode);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  AnnotationsCompanion toCompanion(bool nullToAbsent) {
    return AnnotationsCompanion(
      id: Value(id),
      fingerprint: Value(fingerprint),
      kind: Value(kind),
      color: color == null && nullToAbsent ? const Value.absent() : Value(color),
      locator: Value(locator),
      quote: Value(quote),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      label: Value(label),
      progress: Value(progress),
      mode: Value(mode),
      createdAt: Value(createdAt),
    );
  }

  factory Annotation.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Annotation(
      id: serializer.fromJson<int>(json['id']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      kind: serializer.fromJson<String>(json['kind']),
      color: serializer.fromJson<int?>(json['color']),
      locator: serializer.fromJson<String>(json['locator']),
      quote: serializer.fromJson<String>(json['quote']),
      note: serializer.fromJson<String?>(json['note']),
      label: serializer.fromJson<String>(json['label']),
      progress: serializer.fromJson<double>(json['progress']),
      mode: serializer.fromJson<String>(json['mode']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'kind': serializer.toJson<String>(kind),
      'color': serializer.toJson<int?>(color),
      'locator': serializer.toJson<String>(locator),
      'quote': serializer.toJson<String>(quote),
      'note': serializer.toJson<String?>(note),
      'label': serializer.toJson<String>(label),
      'progress': serializer.toJson<double>(progress),
      'mode': serializer.toJson<String>(mode),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Annotation copyWith({
    int? id,
    String? fingerprint,
    String? kind,
    Value<int?> color = const Value.absent(),
    String? locator,
    String? quote,
    Value<String?> note = const Value.absent(),
    String? label,
    double? progress,
    String? mode,
    DateTime? createdAt,
  }) => Annotation(
    id: id ?? this.id,
    fingerprint: fingerprint ?? this.fingerprint,
    kind: kind ?? this.kind,
    color: color.present ? color.value : this.color,
    locator: locator ?? this.locator,
    quote: quote ?? this.quote,
    note: note.present ? note.value : this.note,
    label: label ?? this.label,
    progress: progress ?? this.progress,
    mode: mode ?? this.mode,
    createdAt: createdAt ?? this.createdAt,
  );
  Annotation copyWithCompanion(AnnotationsCompanion data) {
    return Annotation(
      id: data.id.present ? data.id.value : this.id,
      fingerprint: data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
      kind: data.kind.present ? data.kind.value : this.kind,
      color: data.color.present ? data.color.value : this.color,
      locator: data.locator.present ? data.locator.value : this.locator,
      quote: data.quote.present ? data.quote.value : this.quote,
      note: data.note.present ? data.note.value : this.note,
      label: data.label.present ? data.label.value : this.label,
      progress: data.progress.present ? data.progress.value : this.progress,
      mode: data.mode.present ? data.mode.value : this.mode,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Annotation(')
          ..write('id: $id, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('kind: $kind, ')
          ..write('color: $color, ')
          ..write('locator: $locator, ')
          ..write('quote: $quote, ')
          ..write('note: $note, ')
          ..write('label: $label, ')
          ..write('progress: $progress, ')
          ..write('mode: $mode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, fingerprint, kind, color, locator, quote, note, label, progress, mode, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Annotation &&
          other.id == this.id &&
          other.fingerprint == this.fingerprint &&
          other.kind == this.kind &&
          other.color == this.color &&
          other.locator == this.locator &&
          other.quote == this.quote &&
          other.note == this.note &&
          other.label == this.label &&
          other.progress == this.progress &&
          other.mode == this.mode &&
          other.createdAt == this.createdAt);
}

class AnnotationsCompanion extends UpdateCompanion<Annotation> {
  final Value<int> id;
  final Value<String> fingerprint;
  final Value<String> kind;
  final Value<int?> color;
  final Value<String> locator;
  final Value<String> quote;
  final Value<String?> note;
  final Value<String> label;
  final Value<double> progress;
  final Value<String> mode;
  final Value<DateTime> createdAt;
  const AnnotationsCompanion({
    this.id = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.kind = const Value.absent(),
    this.color = const Value.absent(),
    this.locator = const Value.absent(),
    this.quote = const Value.absent(),
    this.note = const Value.absent(),
    this.label = const Value.absent(),
    this.progress = const Value.absent(),
    this.mode = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  AnnotationsCompanion.insert({
    this.id = const Value.absent(),
    required String fingerprint,
    required String kind,
    this.color = const Value.absent(),
    required String locator,
    this.quote = const Value.absent(),
    this.note = const Value.absent(),
    this.label = const Value.absent(),
    this.progress = const Value.absent(),
    this.mode = const Value.absent(),
    required DateTime createdAt,
  }) : fingerprint = Value(fingerprint),
       kind = Value(kind),
       locator = Value(locator),
       createdAt = Value(createdAt);
  static Insertable<Annotation> custom({
    Expression<int>? id,
    Expression<String>? fingerprint,
    Expression<String>? kind,
    Expression<int>? color,
    Expression<String>? locator,
    Expression<String>? quote,
    Expression<String>? note,
    Expression<String>? label,
    Expression<double>? progress,
    Expression<String>? mode,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (kind != null) 'kind': kind,
      if (color != null) 'color': color,
      if (locator != null) 'locator': locator,
      if (quote != null) 'quote': quote,
      if (note != null) 'note': note,
      if (label != null) 'label': label,
      if (progress != null) 'progress': progress,
      if (mode != null) 'mode': mode,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  AnnotationsCompanion copyWith({
    Value<int>? id,
    Value<String>? fingerprint,
    Value<String>? kind,
    Value<int?>? color,
    Value<String>? locator,
    Value<String>? quote,
    Value<String?>? note,
    Value<String>? label,
    Value<double>? progress,
    Value<String>? mode,
    Value<DateTime>? createdAt,
  }) {
    return AnnotationsCompanion(
      id: id ?? this.id,
      fingerprint: fingerprint ?? this.fingerprint,
      kind: kind ?? this.kind,
      color: color ?? this.color,
      locator: locator ?? this.locator,
      quote: quote ?? this.quote,
      note: note ?? this.note,
      label: label ?? this.label,
      progress: progress ?? this.progress,
      mode: mode ?? this.mode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (color.present) {
      map['color'] = Variable<int>(color.value);
    }
    if (locator.present) {
      map['locator'] = Variable<String>(locator.value);
    }
    if (quote.present) {
      map['quote'] = Variable<String>(quote.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (progress.present) {
      map['progress'] = Variable<double>(progress.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AnnotationsCompanion(')
          ..write('id: $id, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('kind: $kind, ')
          ..write('color: $color, ')
          ..write('locator: $locator, ')
          ..write('quote: $quote, ')
          ..write('note: $note, ')
          ..write('label: $label, ')
          ..write('progress: $progress, ')
          ..write('mode: $mode, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RecentsTable extends Recents with TableInfo<$RecentsTable, Recent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _uriMeta = const VerificationMeta('uri');
  @override
  late final GeneratedColumn<String> uri = GeneratedColumn<String>(
    'uri',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fingerprintMeta = const VerificationMeta('fingerprint');
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _mimeMeta = const VerificationMeta('mime');
  @override
  late final GeneratedColumn<String> mime = GeneratedColumn<String>(
    'mime',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _openedAtMeta = const VerificationMeta('openedAt');
  @override
  late final GeneratedColumn<DateTime> openedAt = GeneratedColumn<DateTime>(
    'opened_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [uri, fingerprint, name, mime, size, openedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recents';
  @override
  VerificationContext validateIntegrity(Insertable<Recent> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('uri')) {
      context.handle(_uriMeta, uri.isAcceptableOrUnknown(data['uri']!, _uriMeta));
    } else if (isInserting) {
      context.missing(_uriMeta);
    }
    if (data.containsKey('fingerprint')) {
      context.handle(_fingerprintMeta, fingerprint.isAcceptableOrUnknown(data['fingerprint']!, _fingerprintMeta));
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('mime')) {
      context.handle(_mimeMeta, mime.isAcceptableOrUnknown(data['mime']!, _mimeMeta));
    }
    if (data.containsKey('size')) {
      context.handle(_sizeMeta, size.isAcceptableOrUnknown(data['size']!, _sizeMeta));
    }
    if (data.containsKey('opened_at')) {
      context.handle(_openedAtMeta, openedAt.isAcceptableOrUnknown(data['opened_at']!, _openedAtMeta));
    } else if (isInserting) {
      context.missing(_openedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {uri};
  @override
  Recent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Recent(
      uri: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}uri'])!,
      fingerprint: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fingerprint']),
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      mime: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mime']),
      size: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}size'])!,
      openedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}opened_at'])!,
    );
  }

  @override
  $RecentsTable createAlias(String alias) {
    return $RecentsTable(attachedDatabase, alias);
  }
}

class Recent extends DataClass implements Insertable<Recent> {
  final String uri;
  final String? fingerprint;
  final String name;
  final String? mime;
  final int size;
  final DateTime openedAt;
  const Recent({
    required this.uri,
    this.fingerprint,
    required this.name,
    this.mime,
    required this.size,
    required this.openedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['uri'] = Variable<String>(uri);
    if (!nullToAbsent || fingerprint != null) {
      map['fingerprint'] = Variable<String>(fingerprint);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || mime != null) {
      map['mime'] = Variable<String>(mime);
    }
    map['size'] = Variable<int>(size);
    map['opened_at'] = Variable<DateTime>(openedAt);
    return map;
  }

  RecentsCompanion toCompanion(bool nullToAbsent) {
    return RecentsCompanion(
      uri: Value(uri),
      fingerprint: fingerprint == null && nullToAbsent ? const Value.absent() : Value(fingerprint),
      name: Value(name),
      mime: mime == null && nullToAbsent ? const Value.absent() : Value(mime),
      size: Value(size),
      openedAt: Value(openedAt),
    );
  }

  factory Recent.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Recent(
      uri: serializer.fromJson<String>(json['uri']),
      fingerprint: serializer.fromJson<String?>(json['fingerprint']),
      name: serializer.fromJson<String>(json['name']),
      mime: serializer.fromJson<String?>(json['mime']),
      size: serializer.fromJson<int>(json['size']),
      openedAt: serializer.fromJson<DateTime>(json['openedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'uri': serializer.toJson<String>(uri),
      'fingerprint': serializer.toJson<String?>(fingerprint),
      'name': serializer.toJson<String>(name),
      'mime': serializer.toJson<String?>(mime),
      'size': serializer.toJson<int>(size),
      'openedAt': serializer.toJson<DateTime>(openedAt),
    };
  }

  Recent copyWith({
    String? uri,
    Value<String?> fingerprint = const Value.absent(),
    String? name,
    Value<String?> mime = const Value.absent(),
    int? size,
    DateTime? openedAt,
  }) => Recent(
    uri: uri ?? this.uri,
    fingerprint: fingerprint.present ? fingerprint.value : this.fingerprint,
    name: name ?? this.name,
    mime: mime.present ? mime.value : this.mime,
    size: size ?? this.size,
    openedAt: openedAt ?? this.openedAt,
  );
  Recent copyWithCompanion(RecentsCompanion data) {
    return Recent(
      uri: data.uri.present ? data.uri.value : this.uri,
      fingerprint: data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
      name: data.name.present ? data.name.value : this.name,
      mime: data.mime.present ? data.mime.value : this.mime,
      size: data.size.present ? data.size.value : this.size,
      openedAt: data.openedAt.present ? data.openedAt.value : this.openedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Recent(')
          ..write('uri: $uri, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('name: $name, ')
          ..write('mime: $mime, ')
          ..write('size: $size, ')
          ..write('openedAt: $openedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(uri, fingerprint, name, mime, size, openedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Recent &&
          other.uri == this.uri &&
          other.fingerprint == this.fingerprint &&
          other.name == this.name &&
          other.mime == this.mime &&
          other.size == this.size &&
          other.openedAt == this.openedAt);
}

class RecentsCompanion extends UpdateCompanion<Recent> {
  final Value<String> uri;
  final Value<String?> fingerprint;
  final Value<String> name;
  final Value<String?> mime;
  final Value<int> size;
  final Value<DateTime> openedAt;
  final Value<int> rowid;
  const RecentsCompanion({
    this.uri = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.name = const Value.absent(),
    this.mime = const Value.absent(),
    this.size = const Value.absent(),
    this.openedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentsCompanion.insert({
    required String uri,
    this.fingerprint = const Value.absent(),
    required String name,
    this.mime = const Value.absent(),
    this.size = const Value.absent(),
    required DateTime openedAt,
    this.rowid = const Value.absent(),
  }) : uri = Value(uri),
       name = Value(name),
       openedAt = Value(openedAt);
  static Insertable<Recent> custom({
    Expression<String>? uri,
    Expression<String>? fingerprint,
    Expression<String>? name,
    Expression<String>? mime,
    Expression<int>? size,
    Expression<DateTime>? openedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (uri != null) 'uri': uri,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (name != null) 'name': name,
      if (mime != null) 'mime': mime,
      if (size != null) 'size': size,
      if (openedAt != null) 'opened_at': openedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentsCompanion copyWith({
    Value<String>? uri,
    Value<String?>? fingerprint,
    Value<String>? name,
    Value<String?>? mime,
    Value<int>? size,
    Value<DateTime>? openedAt,
    Value<int>? rowid,
  }) {
    return RecentsCompanion(
      uri: uri ?? this.uri,
      fingerprint: fingerprint ?? this.fingerprint,
      name: name ?? this.name,
      mime: mime ?? this.mime,
      size: size ?? this.size,
      openedAt: openedAt ?? this.openedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (uri.present) {
      map['uri'] = Variable<String>(uri.value);
    }
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (mime.present) {
      map['mime'] = Variable<String>(mime.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (openedAt.present) {
      map['opened_at'] = Variable<DateTime>(openedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentsCompanion(')
          ..write('uri: $uri, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('name: $name, ')
          ..write('mime: $mime, ')
          ..write('size: $size, ')
          ..write('openedAt: $openedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $FoldersTable folders = $FoldersTable(this);
  late final $EntriesTable entries = $EntriesTable(this);
  late final $DocumentsTable documents = $DocumentsTable(this);
  late final $AnnotationsTable annotations = $AnnotationsTable(this);
  late final $RecentsTable recents = $RecentsTable(this);
  late final Index entriesParent = Index(
    'entries_parent',
    'CREATE INDEX entries_parent ON entries (folder_id, parent)',
  );
  late final Index entriesExt = Index('entries_ext', 'CREATE INDEX entries_ext ON entries (ext)');
  late final Index entriesFp = Index('entries_fp', 'CREATE INDEX entries_fp ON entries (fingerprint)');
  late final Index annotationsDoc = Index(
    'annotations_doc',
    'CREATE INDEX annotations_doc ON annotations (fingerprint)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    entries,
    documents,
    annotations,
    recents,
    entriesParent,
    entriesExt,
    entriesFp,
    annotationsDoc,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName('folders', limitUpdateKind: UpdateKind.delete),
      result: [TableUpdate('entries', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$FoldersTableCreateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  required String uri,
  required String name,
  Value<String> path,
  required DateTime addedAt,
  Value<DateTime?> scannedAt,
  Value<bool> accessLost,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  Value<String> uri,
  Value<String> name,
  Value<String> path,
  Value<DateTime> addedAt,
  Value<DateTime?> scannedAt,
  Value<bool> accessLost,
});

final class $$FoldersTableReferences extends BaseReferences<_$AppDatabase, $FoldersTable, Folder> {
  $$FoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$EntriesTable, List<Entry>> _entriesRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.entries, aliasName: 'folders__id__entries__folder_id');

  $$EntriesTableProcessedTableManager get entriesRefs {
    final manager = $$EntriesTableTableManager(
      $_db,
      $_db.entries,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_entriesRefsTable($_db));
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$FoldersTableFilterComposer extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uri => $composableBuilder(column: $table.uri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get path => $composableBuilder(column: $table.path, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get accessLost =>
      $composableBuilder(column: $table.accessLost, builder: (column) => ColumnFilters(column));

  Expression<bool> entriesRefs(Expression<bool> Function($$EntriesTableFilterComposer f) f) {
    final $$EntriesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.folderId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$EntriesTableFilterComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableOrderingComposer extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scannedAt =>
      $composableBuilder(column: $table.scannedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get accessLost =>
      $composableBuilder(column: $table.accessLost, builder: (column) => ColumnOrderings(column));
}

class $$FoldersTableAnnotationComposer extends Composer<_$AppDatabase, $FoldersTable> {
  $$FoldersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uri => $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get path => $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt => $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get scannedAt => $composableBuilder(column: $table.scannedAt, builder: (column) => column);

  GeneratedColumn<bool> get accessLost => $composableBuilder(column: $table.accessLost, builder: (column) => column);

  Expression<T> entriesRefs<T extends Object>(Expression<T> Function($$EntriesTableAnnotationComposer a) f) {
    final $$EntriesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.entries,
      getReferencedColumn: (t) => t.folderId,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$EntriesTableAnnotationComposer(
            $db: $db,
            $table: $db.entries,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoldersTable,
          Folder,
          $$FoldersTableFilterComposer,
          $$FoldersTableOrderingComposer,
          $$FoldersTableAnnotationComposer,
          $$FoldersTableCreateCompanionBuilder,
          $$FoldersTableUpdateCompanionBuilder,
          (Folder, $$FoldersTableReferences),
          Folder,
          PrefetchHooks Function({bool entriesRefs})
        > {
  $$FoldersTableTableManager(_$AppDatabase db, $FoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$FoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$FoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$FoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> path = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<DateTime?> scannedAt = const Value.absent(),
                Value<bool> accessLost = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                uri: uri,
                name: name,
                path: path,
                addedAt: addedAt,
                scannedAt: scannedAt,
                accessLost: accessLost,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String uri,
                required String name,
                Value<String> path = const Value.absent(),
                required DateTime addedAt,
                Value<DateTime?> scannedAt = const Value.absent(),
                Value<bool> accessLost = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                uri: uri,
                name: name,
                path: path,
                addedAt: addedAt,
                scannedAt: scannedAt,
                accessLost: accessLost,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$FoldersTable, Folder>(table), $$FoldersTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({entriesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (entriesRefs) db.entries],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (entriesRefs)
                    await $_getPrefetchedData<Folder, $FoldersTable, Entry>(
                      currentTable: table,
                      referencedTable: $$FoldersTableReferences._entriesRefsTable(db),
                      managerFromTypedResult: (p0) => $$FoldersTableReferences(db, table, p0).entriesRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$FoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoldersTable,
      Folder,
      $$FoldersTableFilterComposer,
      $$FoldersTableOrderingComposer,
      $$FoldersTableAnnotationComposer,
      $$FoldersTableCreateCompanionBuilder,
      $$FoldersTableUpdateCompanionBuilder,
      (Folder, $$FoldersTableReferences),
      Folder,
      PrefetchHooks Function({bool entriesRefs})
    >;
typedef $$EntriesTableCreateCompanionBuilder = EntriesCompanion Function({
  Value<int> id,
  required int folderId,
  required String docId,
  required String uri,
  required String parent,
  required String name,
  required String ext,
  Value<String?> mime,
  required bool isDir,
  Value<int> size,
  Value<int> modified,
  Value<String?> fingerprint,
  Value<String?> title,
  Value<String?> author,
  Value<int?> units,
  Value<int> enriched,
  Value<bool> hidden,
});
typedef $$EntriesTableUpdateCompanionBuilder = EntriesCompanion Function({
  Value<int> id,
  Value<int> folderId,
  Value<String> docId,
  Value<String> uri,
  Value<String> parent,
  Value<String> name,
  Value<String> ext,
  Value<String?> mime,
  Value<bool> isDir,
  Value<int> size,
  Value<int> modified,
  Value<String?> fingerprint,
  Value<String?> title,
  Value<String?> author,
  Value<int?> units,
  Value<int> enriched,
  Value<bool> hidden,
});

final class $$EntriesTableReferences extends BaseReferences<_$AppDatabase, $EntriesTable, Entry> {
  $$EntriesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoldersTable _folderIdTable(_$AppDatabase db) => db.folders.createAlias('entries__folder_id__folders__id');

  $$FoldersTableProcessedTableManager get folderId {
    final $_column = $_itemColumn<int>('folder_id')!;

    final manager = $$FoldersTableTableManager($_db, $_db.folders).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$EntriesTableFilterComposer extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get docId =>
      $composableBuilder(column: $table.docId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uri => $composableBuilder(column: $table.uri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parent =>
      $composableBuilder(column: $table.parent, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get ext => $composableBuilder(column: $table.ext, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mime => $composableBuilder(column: $table.mime, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isDir => $composableBuilder(column: $table.isDir, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get units => $composableBuilder(column: $table.units, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get enriched =>
      $composableBuilder(column: $table.enriched, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => ColumnFilters(column));

  $$FoldersTableFilterComposer get folderId {
    final $$FoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$FoldersTableFilterComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableOrderingComposer extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get docId =>
      $composableBuilder(column: $table.docId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parent =>
      $composableBuilder(column: $table.parent, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get ext =>
      $composableBuilder(column: $table.ext, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isDir =>
      $composableBuilder(column: $table.isDir, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get modified =>
      $composableBuilder(column: $table.modified, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get units =>
      $composableBuilder(column: $table.units, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get enriched =>
      $composableBuilder(column: $table.enriched, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => ColumnOrderings(column));

  $$FoldersTableOrderingComposer get folderId {
    final $$FoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$FoldersTableOrderingComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableAnnotationComposer extends Composer<_$AppDatabase, $EntriesTable> {
  $$EntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get docId => $composableBuilder(column: $table.docId, builder: (column) => column);

  GeneratedColumn<String> get uri => $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get parent => $composableBuilder(column: $table.parent, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get ext => $composableBuilder(column: $table.ext, builder: (column) => column);

  GeneratedColumn<String> get mime => $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<bool> get isDir => $composableBuilder(column: $table.isDir, builder: (column) => column);

  GeneratedColumn<int> get size => $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<int> get modified => $composableBuilder(column: $table.modified, builder: (column) => column);

  GeneratedColumn<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author => $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<int> get units => $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<int> get enriched => $composableBuilder(column: $table.enriched, builder: (column) => column);

  GeneratedColumn<bool> get hidden => $composableBuilder(column: $table.hidden, builder: (column) => column);

  $$FoldersTableAnnotationComposer get folderId {
    final $$FoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.folders,
      getReferencedColumn: (t) => t.id,
      builder: (joinBuilder, {$addJoinBuilderToRootComposer, $removeJoinBuilderFromRootComposer}) =>
          $$FoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.folders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer: $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$EntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $EntriesTable,
          Entry,
          $$EntriesTableFilterComposer,
          $$EntriesTableOrderingComposer,
          $$EntriesTableAnnotationComposer,
          $$EntriesTableCreateCompanionBuilder,
          $$EntriesTableUpdateCompanionBuilder,
          (Entry, $$EntriesTableReferences),
          Entry,
          PrefetchHooks Function({bool folderId})
        > {
  $$EntriesTableTableManager(_$AppDatabase db, $EntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$EntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$EntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$EntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> folderId = const Value.absent(),
                Value<String> docId = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<String> parent = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> ext = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<bool> isDir = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> modified = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> units = const Value.absent(),
                Value<int> enriched = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
              }) => EntriesCompanion(
                id: id,
                folderId: folderId,
                docId: docId,
                uri: uri,
                parent: parent,
                name: name,
                ext: ext,
                mime: mime,
                isDir: isDir,
                size: size,
                modified: modified,
                fingerprint: fingerprint,
                title: title,
                author: author,
                units: units,
                enriched: enriched,
                hidden: hidden,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int folderId,
                required String docId,
                required String uri,
                required String parent,
                required String name,
                required String ext,
                Value<String?> mime = const Value.absent(),
                required bool isDir,
                Value<int> size = const Value.absent(),
                Value<int> modified = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<int?> units = const Value.absent(),
                Value<int> enriched = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
              }) => EntriesCompanion.insert(
                id: id,
                folderId: folderId,
                docId: docId,
                uri: uri,
                parent: parent,
                name: name,
                ext: ext,
                mime: mime,
                isDir: isDir,
                size: size,
                modified: modified,
                fingerprint: fingerprint,
                title: title,
                author: author,
                units: units,
                enriched: enriched,
                hidden: hidden,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable<$EntriesTable, Entry>(table), $$EntriesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: ({folderId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderId) {
                      state = state.withJoin(
                        currentTable: table,
                        currentColumn: table.folderId,
                        referencedTable: $$EntriesTableReferences._folderIdTable(db),
                        referencedColumn: $$EntriesTableReferences._folderIdTable(db).id,
                      ) as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$EntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $EntriesTable,
      Entry,
      $$EntriesTableFilterComposer,
      $$EntriesTableOrderingComposer,
      $$EntriesTableAnnotationComposer,
      $$EntriesTableCreateCompanionBuilder,
      $$EntriesTableUpdateCompanionBuilder,
      (Entry, $$EntriesTableReferences),
      Entry,
      PrefetchHooks Function({bool folderId})
    >;
typedef $$DocumentsTableCreateCompanionBuilder = DocumentsCompanion Function({
  required String fingerprint,
  required String uri,
  required String name,
  required String format,
  Value<String?> title,
  Value<String?> author,
  Value<String?> position,
  Value<double> progress,
  Value<String?> mode,
  Value<bool> finished,
  Value<int?> units,
  Value<String?> where,
  Value<DateTime?> openedAt,
  required DateTime addedAt,
  Value<int> readMs,
  Value<int> readWords,
  Value<int> size,
  Value<int> rowid,
});
typedef $$DocumentsTableUpdateCompanionBuilder = DocumentsCompanion Function({
  Value<String> fingerprint,
  Value<String> uri,
  Value<String> name,
  Value<String> format,
  Value<String?> title,
  Value<String?> author,
  Value<String?> position,
  Value<double> progress,
  Value<String?> mode,
  Value<bool> finished,
  Value<int?> units,
  Value<String?> where,
  Value<DateTime?> openedAt,
  Value<DateTime> addedAt,
  Value<int> readMs,
  Value<int> readWords,
  Value<int> size,
  Value<int> rowid,
});

class $$DocumentsTableFilterComposer extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get uri => $composableBuilder(column: $table.uri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get units => $composableBuilder(column: $table.units, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get where =>
      $composableBuilder(column: $table.where, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readMs =>
      $composableBuilder(column: $table.readMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readWords =>
      $composableBuilder(column: $table.readWords, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(column: $table.size, builder: (column) => ColumnFilters(column));
}

class $$DocumentsTableOrderingComposer extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get author =>
      $composableBuilder(column: $table.author, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get position =>
      $composableBuilder(column: $table.position, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get finished =>
      $composableBuilder(column: $table.finished, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get units =>
      $composableBuilder(column: $table.units, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get where =>
      $composableBuilder(column: $table.where, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readMs =>
      $composableBuilder(column: $table.readMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readWords =>
      $composableBuilder(column: $table.readWords, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => ColumnOrderings(column));
}

class $$DocumentsTableAnnotationComposer extends Composer<_$AppDatabase, $DocumentsTable> {
  $$DocumentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => column);

  GeneratedColumn<String> get uri => $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get format => $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get title => $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get author => $composableBuilder(column: $table.author, builder: (column) => column);

  GeneratedColumn<String> get position => $composableBuilder(column: $table.position, builder: (column) => column);

  GeneratedColumn<double> get progress => $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<bool> get finished => $composableBuilder(column: $table.finished, builder: (column) => column);

  GeneratedColumn<int> get units => $composableBuilder(column: $table.units, builder: (column) => column);

  GeneratedColumn<String> get where => $composableBuilder(column: $table.where, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt => $composableBuilder(column: $table.openedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt => $composableBuilder(column: $table.addedAt, builder: (column) => column);

  GeneratedColumn<int> get readMs => $composableBuilder(column: $table.readMs, builder: (column) => column);

  GeneratedColumn<int> get readWords => $composableBuilder(column: $table.readWords, builder: (column) => column);

  GeneratedColumn<int> get size => $composableBuilder(column: $table.size, builder: (column) => column);
}

class $$DocumentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DocumentsTable,
          Document,
          $$DocumentsTableFilterComposer,
          $$DocumentsTableOrderingComposer,
          $$DocumentsTableAnnotationComposer,
          $$DocumentsTableCreateCompanionBuilder,
          $$DocumentsTableUpdateCompanionBuilder,
          (Document, BaseReferences<_$AppDatabase, $DocumentsTable, Document>),
          Document,
          PrefetchHooks Function()
        > {
  $$DocumentsTableTableManager(_$AppDatabase db, $DocumentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$DocumentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$DocumentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$DocumentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fingerprint = const Value.absent(),
                Value<String> uri = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<int?> units = const Value.absent(),
                Value<String?> where = const Value.absent(),
                Value<DateTime?> openedAt = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> readMs = const Value.absent(),
                Value<int> readWords = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion(
                fingerprint: fingerprint,
                uri: uri,
                name: name,
                format: format,
                title: title,
                author: author,
                position: position,
                progress: progress,
                mode: mode,
                finished: finished,
                units: units,
                where: where,
                openedAt: openedAt,
                addedAt: addedAt,
                readMs: readMs,
                readWords: readWords,
                size: size,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fingerprint,
                required String uri,
                required String name,
                required String format,
                Value<String?> title = const Value.absent(),
                Value<String?> author = const Value.absent(),
                Value<String?> position = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String?> mode = const Value.absent(),
                Value<bool> finished = const Value.absent(),
                Value<int?> units = const Value.absent(),
                Value<String?> where = const Value.absent(),
                Value<DateTime?> openedAt = const Value.absent(),
                required DateTime addedAt,
                Value<int> readMs = const Value.absent(),
                Value<int> readWords = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DocumentsCompanion.insert(
                fingerprint: fingerprint,
                uri: uri,
                name: name,
                format: format,
                title: title,
                author: author,
                position: position,
                progress: progress,
                mode: mode,
                finished: finished,
                units: units,
                where: where,
                openedAt: openedAt,
                addedAt: addedAt,
                readMs: readMs,
                readWords: readWords,
                size: size,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DocumentsTable, Document>(table),
                  BaseReferences<_$AppDatabase, $DocumentsTable, Document>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DocumentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DocumentsTable,
      Document,
      $$DocumentsTableFilterComposer,
      $$DocumentsTableOrderingComposer,
      $$DocumentsTableAnnotationComposer,
      $$DocumentsTableCreateCompanionBuilder,
      $$DocumentsTableUpdateCompanionBuilder,
      (Document, BaseReferences<_$AppDatabase, $DocumentsTable, Document>),
      Document,
      PrefetchHooks Function()
    >;
typedef $$AnnotationsTableCreateCompanionBuilder = AnnotationsCompanion Function({
  Value<int> id,
  required String fingerprint,
  required String kind,
  Value<int?> color,
  required String locator,
  Value<String> quote,
  Value<String?> note,
  Value<String> label,
  Value<double> progress,
  Value<String> mode,
  required DateTime createdAt,
});
typedef $$AnnotationsTableUpdateCompanionBuilder = AnnotationsCompanion Function({
  Value<int> id,
  Value<String> fingerprint,
  Value<String> kind,
  Value<int?> color,
  Value<String> locator,
  Value<String> quote,
  Value<String?> note,
  Value<String> label,
  Value<double> progress,
  Value<String> mode,
  Value<DateTime> createdAt,
});

class $$AnnotationsTableFilterComposer extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get color => $composableBuilder(column: $table.color, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get quote =>
      $composableBuilder(column: $table.quote, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get note => $composableBuilder(column: $table.note, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$AnnotationsTableOrderingComposer extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get color =>
      $composableBuilder(column: $table.color, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get locator =>
      $composableBuilder(column: $table.locator, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get quote =>
      $composableBuilder(column: $table.quote, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get progress =>
      $composableBuilder(column: $table.progress, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$AnnotationsTableAnnotationComposer extends Composer<_$AppDatabase, $AnnotationsTable> {
  $$AnnotationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => column);

  GeneratedColumn<String> get kind => $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<int> get color => $composableBuilder(column: $table.color, builder: (column) => column);

  GeneratedColumn<String> get locator => $composableBuilder(column: $table.locator, builder: (column) => column);

  GeneratedColumn<String> get quote => $composableBuilder(column: $table.quote, builder: (column) => column);

  GeneratedColumn<String> get note => $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get label => $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<double> get progress => $composableBuilder(column: $table.progress, builder: (column) => column);

  GeneratedColumn<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt => $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$AnnotationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AnnotationsTable,
          Annotation,
          $$AnnotationsTableFilterComposer,
          $$AnnotationsTableOrderingComposer,
          $$AnnotationsTableAnnotationComposer,
          $$AnnotationsTableCreateCompanionBuilder,
          $$AnnotationsTableUpdateCompanionBuilder,
          (Annotation, BaseReferences<_$AppDatabase, $AnnotationsTable, Annotation>),
          Annotation,
          PrefetchHooks Function()
        > {
  $$AnnotationsTableTableManager(_$AppDatabase db, $AnnotationsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$AnnotationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$AnnotationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$AnnotationsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<int?> color = const Value.absent(),
                Value<String> locator = const Value.absent(),
                Value<String> quote = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => AnnotationsCompanion(
                id: id,
                fingerprint: fingerprint,
                kind: kind,
                color: color,
                locator: locator,
                quote: quote,
                note: note,
                label: label,
                progress: progress,
                mode: mode,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fingerprint,
                required String kind,
                Value<int?> color = const Value.absent(),
                required String locator,
                Value<String> quote = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<double> progress = const Value.absent(),
                Value<String> mode = const Value.absent(),
                required DateTime createdAt,
              }) => AnnotationsCompanion.insert(
                id: id,
                fingerprint: fingerprint,
                kind: kind,
                color: color,
                locator: locator,
                quote: quote,
                note: note,
                label: label,
                progress: progress,
                mode: mode,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$AnnotationsTable, Annotation>(table),
                  BaseReferences<_$AppDatabase, $AnnotationsTable, Annotation>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AnnotationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AnnotationsTable,
      Annotation,
      $$AnnotationsTableFilterComposer,
      $$AnnotationsTableOrderingComposer,
      $$AnnotationsTableAnnotationComposer,
      $$AnnotationsTableCreateCompanionBuilder,
      $$AnnotationsTableUpdateCompanionBuilder,
      (Annotation, BaseReferences<_$AppDatabase, $AnnotationsTable, Annotation>),
      Annotation,
      PrefetchHooks Function()
    >;
typedef $$RecentsTableCreateCompanionBuilder = RecentsCompanion Function({
  required String uri,
  Value<String?> fingerprint,
  required String name,
  Value<String?> mime,
  Value<int> size,
  required DateTime openedAt,
  Value<int> rowid,
});
typedef $$RecentsTableUpdateCompanionBuilder = RecentsCompanion Function({
  Value<String> uri,
  Value<String?> fingerprint,
  Value<String> name,
  Value<String?> mime,
  Value<int> size,
  Value<DateTime> openedAt,
  Value<int> rowid,
});

class $$RecentsTableFilterComposer extends Composer<_$AppDatabase, $RecentsTable> {
  $$RecentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get uri => $composableBuilder(column: $table.uri, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mime => $composableBuilder(column: $table.mime, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get size => $composableBuilder(column: $table.size, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => ColumnFilters(column));
}

class $$RecentsTableOrderingComposer extends Composer<_$AppDatabase, $RecentsTable> {
  $$RecentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get uri =>
      $composableBuilder(column: $table.uri, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mime =>
      $composableBuilder(column: $table.mime, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get openedAt =>
      $composableBuilder(column: $table.openedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecentsTableAnnotationComposer extends Composer<_$AppDatabase, $RecentsTable> {
  $$RecentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get uri => $composableBuilder(column: $table.uri, builder: (column) => column);

  GeneratedColumn<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get mime => $composableBuilder(column: $table.mime, builder: (column) => column);

  GeneratedColumn<int> get size => $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get openedAt => $composableBuilder(column: $table.openedAt, builder: (column) => column);
}

class $$RecentsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentsTable,
          Recent,
          $$RecentsTableFilterComposer,
          $$RecentsTableOrderingComposer,
          $$RecentsTableAnnotationComposer,
          $$RecentsTableCreateCompanionBuilder,
          $$RecentsTableUpdateCompanionBuilder,
          (Recent, BaseReferences<_$AppDatabase, $RecentsTable, Recent>),
          Recent,
          PrefetchHooks Function()
        > {
  $$RecentsTableTableManager(_$AppDatabase db, $RecentsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$RecentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$RecentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$RecentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> uri = const Value.absent(),
                Value<String?> fingerprint = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> mime = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> openedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RecentsCompanion(
                uri: uri,
                fingerprint: fingerprint,
                name: name,
                mime: mime,
                size: size,
                openedAt: openedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String uri,
                Value<String?> fingerprint = const Value.absent(),
                required String name,
                Value<String?> mime = const Value.absent(),
                Value<int> size = const Value.absent(),
                required DateTime openedAt,
                Value<int> rowid = const Value.absent(),
              }) => RecentsCompanion.insert(
                uri: uri,
                fingerprint: fingerprint,
                name: name,
                mime: mime,
                size: size,
                openedAt: openedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$RecentsTable, Recent>(table),
                  BaseReferences<_$AppDatabase, $RecentsTable, Recent>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RecentsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentsTable,
      Recent,
      $$RecentsTableFilterComposer,
      $$RecentsTableOrderingComposer,
      $$RecentsTableAnnotationComposer,
      $$RecentsTableCreateCompanionBuilder,
      $$RecentsTableUpdateCompanionBuilder,
      (Recent, BaseReferences<_$AppDatabase, $RecentsTable, Recent>),
      Recent,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$FoldersTableTableManager get folders => $$FoldersTableTableManager(_db, _db.folders);
  $$EntriesTableTableManager get entries => $$EntriesTableTableManager(_db, _db.entries);
  $$DocumentsTableTableManager get documents => $$DocumentsTableTableManager(_db, _db.documents);
  $$AnnotationsTableTableManager get annotations => $$AnnotationsTableTableManager(_db, _db.annotations);
  $$RecentsTableTableManager get recents => $$RecentsTableTableManager(_db, _db.recents);
}
