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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('saf_folder'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, uri, name, path, addedAt, scannedAt, accessLost, source];
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
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
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
      source: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
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

  /// How it was added (schema 2): `saf_folder` (a tree URI from Android's
  /// picker), `path_folder` (a path, picked in Files with all-files access) or
  /// `device` (the one hidden row that holds "Find books across this device").
  final String source;
  const Folder({
    required this.id,
    required this.uri,
    required this.name,
    required this.path,
    required this.addedAt,
    this.scannedAt,
    required this.accessLost,
    required this.source,
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
    map['source'] = Variable<String>(source);
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
      source: Value(source),
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
      source: serializer.fromJson<String>(json['source']),
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
      'source': serializer.toJson<String>(source),
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
    String? source,
  }) => Folder(
    id: id ?? this.id,
    uri: uri ?? this.uri,
    name: name ?? this.name,
    path: path ?? this.path,
    addedAt: addedAt ?? this.addedAt,
    scannedAt: scannedAt.present ? scannedAt.value : this.scannedAt,
    accessLost: accessLost ?? this.accessLost,
    source: source ?? this.source,
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
      source: data.source.present ? data.source.value : this.source,
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
          ..write('accessLost: $accessLost, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, uri, name, path, addedAt, scannedAt, accessLost, source);
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
          other.accessLost == this.accessLost &&
          other.source == this.source);
}

class FoldersCompanion extends UpdateCompanion<Folder> {
  final Value<int> id;
  final Value<String> uri;
  final Value<String> name;
  final Value<String> path;
  final Value<DateTime> addedAt;
  final Value<DateTime?> scannedAt;
  final Value<bool> accessLost;
  final Value<String> source;
  const FoldersCompanion({
    this.id = const Value.absent(),
    this.uri = const Value.absent(),
    this.name = const Value.absent(),
    this.path = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.scannedAt = const Value.absent(),
    this.accessLost = const Value.absent(),
    this.source = const Value.absent(),
  });
  FoldersCompanion.insert({
    this.id = const Value.absent(),
    required String uri,
    required String name,
    this.path = const Value.absent(),
    required DateTime addedAt,
    this.scannedAt = const Value.absent(),
    this.accessLost = const Value.absent(),
    this.source = const Value.absent(),
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
    Expression<String>? source,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uri != null) 'uri': uri,
      if (name != null) 'name': name,
      if (path != null) 'path': path,
      if (addedAt != null) 'added_at': addedAt,
      if (scannedAt != null) 'scanned_at': scannedAt,
      if (accessLost != null) 'access_lost': accessLost,
      if (source != null) 'source': source,
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
    Value<String>? source,
  }) {
    return FoldersCompanion(
      id: id ?? this.id,
      uri: uri ?? this.uri,
      name: name ?? this.name,
      path: path ?? this.path,
      addedAt: addedAt ?? this.addedAt,
      scannedAt: scannedAt ?? this.scannedAt,
      accessLost: accessLost ?? this.accessLost,
      source: source ?? this.source,
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
    if (source.present) {
      map['source'] = Variable<String>(source.value);
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
          ..write('accessLost: $accessLost, ')
          ..write('source: $source')
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
  static const VerificationMeta _issueMeta = const VerificationMeta('issue');
  @override
  late final GeneratedColumn<String> issue = GeneratedColumn<String>(
    'issue',
    aliasedName,
    true,
    type: DriftSqlType.string,
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
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('saf_folder'),
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
    issue,
    enriched,
    hidden,
    source,
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
    if (data.containsKey('issue')) {
      context.handle(_issueMeta, issue.isAcceptableOrUnknown(data['issue']!, _issueMeta));
    }
    if (data.containsKey('enriched')) {
      context.handle(_enrichedMeta, enriched.isAcceptableOrUnknown(data['enriched']!, _enrichedMeta));
    }
    if (data.containsKey('hidden')) {
      context.handle(_hiddenMeta, hidden.isAcceptableOrUnknown(data['hidden']!, _hiddenMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta, source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
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
      issue: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}issue']),
      enriched: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}enriched'])!,
      hidden: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}hidden'])!,
      source: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}source'])!,
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

  /// Pages (PDF, comics) or chapters (EPUB).
  final int? units;

  /// A comic's issue or volume ("#14", "Vol. 2"), from its ComicInfo (schema 3).
  final String? issue;

  /// 0 never read, 1 metadata read, -1 unreadable, -2 protected (DRM),
  /// -3 a variant Unfurl can't read (Topaz, KFX, RAR 5).
  final int enriched;

  /// "Remove from library": hidden here; the file stays on the phone.
  final bool hidden;

  /// How it was found (schema 2): `saf_folder`, `path_folder` or `device`.
  final String source;
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
    this.issue,
    required this.enriched,
    required this.hidden,
    required this.source,
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
    if (!nullToAbsent || issue != null) {
      map['issue'] = Variable<String>(issue);
    }
    map['enriched'] = Variable<int>(enriched);
    map['hidden'] = Variable<bool>(hidden);
    map['source'] = Variable<String>(source);
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
      issue: issue == null && nullToAbsent ? const Value.absent() : Value(issue),
      enriched: Value(enriched),
      hidden: Value(hidden),
      source: Value(source),
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
      issue: serializer.fromJson<String?>(json['issue']),
      enriched: serializer.fromJson<int>(json['enriched']),
      hidden: serializer.fromJson<bool>(json['hidden']),
      source: serializer.fromJson<String>(json['source']),
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
      'issue': serializer.toJson<String?>(issue),
      'enriched': serializer.toJson<int>(enriched),
      'hidden': serializer.toJson<bool>(hidden),
      'source': serializer.toJson<String>(source),
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
    Value<String?> issue = const Value.absent(),
    int? enriched,
    bool? hidden,
    String? source,
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
    issue: issue.present ? issue.value : this.issue,
    enriched: enriched ?? this.enriched,
    hidden: hidden ?? this.hidden,
    source: source ?? this.source,
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
      issue: data.issue.present ? data.issue.value : this.issue,
      enriched: data.enriched.present ? data.enriched.value : this.enriched,
      hidden: data.hidden.present ? data.hidden.value : this.hidden,
      source: data.source.present ? data.source.value : this.source,
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
          ..write('issue: $issue, ')
          ..write('enriched: $enriched, ')
          ..write('hidden: $hidden, ')
          ..write('source: $source')
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
    issue,
    enriched,
    hidden,
    source,
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
          other.issue == this.issue &&
          other.enriched == this.enriched &&
          other.hidden == this.hidden &&
          other.source == this.source);
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
  final Value<String?> issue;
  final Value<int> enriched;
  final Value<bool> hidden;
  final Value<String> source;
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
    this.issue = const Value.absent(),
    this.enriched = const Value.absent(),
    this.hidden = const Value.absent(),
    this.source = const Value.absent(),
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
    this.issue = const Value.absent(),
    this.enriched = const Value.absent(),
    this.hidden = const Value.absent(),
    this.source = const Value.absent(),
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
    Expression<String>? issue,
    Expression<int>? enriched,
    Expression<bool>? hidden,
    Expression<String>? source,
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
      if (issue != null) 'issue': issue,
      if (enriched != null) 'enriched': enriched,
      if (hidden != null) 'hidden': hidden,
      if (source != null) 'source': source,
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
    Value<String?>? issue,
    Value<int>? enriched,
    Value<bool>? hidden,
    Value<String>? source,
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
      issue: issue ?? this.issue,
      enriched: enriched ?? this.enriched,
      hidden: hidden ?? this.hidden,
      source: source ?? this.source,
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
    if (issue.present) {
      map['issue'] = Variable<String>(issue.value);
    }
    if (enriched.present) {
      map['enriched'] = Variable<int>(enriched.value);
    }
    if (hidden.present) {
      map['hidden'] = Variable<bool>(hidden.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
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
          ..write('issue: $issue, ')
          ..write('enriched: $enriched, ')
          ..write('hidden: $hidden, ')
          ..write('source: $source')
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
  static const VerificationMeta _issueMeta = const VerificationMeta('issue');
  @override
  late final GeneratedColumn<String> issue = GeneratedColumn<String>(
    'issue',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
    issue,
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
    if (data.containsKey('issue')) {
      context.handle(_issueMeta, issue.isAcceptableOrUnknown(data['issue']!, _issueMeta));
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
      issue: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}issue']),
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

  /// A comic's issue or volume (schema 3).
  final String? issue;
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
    this.issue,
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
    if (!nullToAbsent || issue != null) {
      map['issue'] = Variable<String>(issue);
    }
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
      issue: issue == null && nullToAbsent ? const Value.absent() : Value(issue),
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
      issue: serializer.fromJson<String?>(json['issue']),
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
      'issue': serializer.toJson<String?>(issue),
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
    Value<String?> issue = const Value.absent(),
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
    issue: issue.present ? issue.value : this.issue,
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
      issue: data.issue.present ? data.issue.value : this.issue,
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
          ..write('size: $size, ')
          ..write('issue: $issue')
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
    issue,
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
          other.size == this.size &&
          other.issue == this.issue);
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
  final Value<String?> issue;
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
    this.issue = const Value.absent(),
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
    this.issue = const Value.absent(),
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
    Expression<String>? issue,
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
      if (issue != null) 'issue': issue,
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
    Value<String?>? issue,
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
      issue: issue ?? this.issue,
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
    if (issue.present) {
      map['issue'] = Variable<String>(issue.value);
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
          ..write('issue: $issue, ')
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

class $PlacesTable extends Places with TableInfo<$PlacesTable, Place> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PlacesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
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
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
    'pinned',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("pinned" IN (0, 1))'),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _visitedAtMeta = const VerificationMeta('visitedAt');
  @override
  late final GeneratedColumn<DateTime> visitedAt = GeneratedColumn<DateTime>(
    'visited_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [path, name, pinned, visitedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'places';
  @override
  VerificationContext validateIntegrity(Insertable<Place> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(_pathMeta, path.isAcceptableOrUnknown(data['path']!, _pathMeta));
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(_nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('pinned')) {
      context.handle(_pinnedMeta, pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta));
    }
    if (data.containsKey('visited_at')) {
      context.handle(_visitedAtMeta, visitedAt.isAcceptableOrUnknown(data['visited_at']!, _visitedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  Place map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Place(
      path: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}path'])!,
      name: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      pinned: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}pinned'])!,
      visitedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}visited_at']),
    );
  }

  @override
  $PlacesTable createAlias(String alias) {
    return $PlacesTable(attachedDatabase, alias);
  }
}

class Place extends DataClass implements Insertable<Place> {
  final String path;
  final String name;
  final bool pinned;
  final DateTime? visitedAt;
  const Place({required this.path, required this.name, required this.pinned, this.visitedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || visitedAt != null) {
      map['visited_at'] = Variable<DateTime>(visitedAt);
    }
    return map;
  }

  PlacesCompanion toCompanion(bool nullToAbsent) {
    return PlacesCompanion(
      path: Value(path),
      name: Value(name),
      pinned: Value(pinned),
      visitedAt: visitedAt == null && nullToAbsent ? const Value.absent() : Value(visitedAt),
    );
  }

  factory Place.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Place(
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      pinned: serializer.fromJson<bool>(json['pinned']),
      visitedAt: serializer.fromJson<DateTime?>(json['visitedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'pinned': serializer.toJson<bool>(pinned),
      'visitedAt': serializer.toJson<DateTime?>(visitedAt),
    };
  }

  Place copyWith({String? path, String? name, bool? pinned, Value<DateTime?> visitedAt = const Value.absent()}) =>
      Place(
        path: path ?? this.path,
        name: name ?? this.name,
        pinned: pinned ?? this.pinned,
        visitedAt: visitedAt.present ? visitedAt.value : this.visitedAt,
      );
  Place copyWithCompanion(PlacesCompanion data) {
    return Place(
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      visitedAt: data.visitedAt.present ? data.visitedAt.value : this.visitedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Place(')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('pinned: $pinned, ')
          ..write('visitedAt: $visitedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, name, pinned, visitedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Place &&
          other.path == this.path &&
          other.name == this.name &&
          other.pinned == this.pinned &&
          other.visitedAt == this.visitedAt);
}

class PlacesCompanion extends UpdateCompanion<Place> {
  final Value<String> path;
  final Value<String> name;
  final Value<bool> pinned;
  final Value<DateTime?> visitedAt;
  final Value<int> rowid;
  const PlacesCompanion({
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.pinned = const Value.absent(),
    this.visitedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PlacesCompanion.insert({
    required String path,
    required String name,
    this.pinned = const Value.absent(),
    this.visitedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       name = Value(name);
  static Insertable<Place> custom({
    Expression<String>? path,
    Expression<String>? name,
    Expression<bool>? pinned,
    Expression<DateTime>? visitedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (pinned != null) 'pinned': pinned,
      if (visitedAt != null) 'visited_at': visitedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PlacesCompanion copyWith({
    Value<String>? path,
    Value<String>? name,
    Value<bool>? pinned,
    Value<DateTime?>? visitedAt,
    Value<int>? rowid,
  }) {
    return PlacesCompanion(
      path: path ?? this.path,
      name: name ?? this.name,
      pinned: pinned ?? this.pinned,
      visitedAt: visitedAt ?? this.visitedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (visitedAt.present) {
      map['visited_at'] = Variable<DateTime>(visitedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PlacesCompanion(')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('pinned: $pinned, ')
          ..write('visitedAt: $visitedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ReadingSessionsTable extends ReadingSessions with TableInfo<$ReadingSessionsTable, ReadingSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReadingSessionsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _formatMeta = const VerificationMeta('format');
  @override
  late final GeneratedColumn<String> format = GeneratedColumn<String>(
    'format',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta('startedAt');
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta('endedAt');
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hourMeta = const VerificationMeta('hour');
  @override
  late final GeneratedColumn<int> hour = GeneratedColumn<int>(
    'hour',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activeMsMeta = const VerificationMeta('activeMs');
  @override
  late final GeneratedColumn<int> activeMs = GeneratedColumn<int>(
    'active_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _listeningMsMeta = const VerificationMeta('listeningMs');
  @override
  late final GeneratedColumn<int> listeningMs = GeneratedColumn<int>(
    'listening_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fromLocatorMeta = const VerificationMeta('fromLocator');
  @override
  late final GeneratedColumn<String> fromLocator = GeneratedColumn<String>(
    'from_locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _toLocatorMeta = const VerificationMeta('toLocator');
  @override
  late final GeneratedColumn<String> toLocator = GeneratedColumn<String>(
    'to_locator',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordsMeta = const VerificationMeta('words');
  @override
  late final GeneratedColumn<int> words = GeneratedColumn<int>(
    'words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pagesMeta = const VerificationMeta('pages');
  @override
  late final GeneratedColumn<int> pages = GeneratedColumn<int>(
    'pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _openMeta = const VerificationMeta('open');
  @override
  late final GeneratedColumn<bool> open = GeneratedColumn<bool>(
    'open',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('CHECK ("open" IN (0, 1))'),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    fingerprint,
    format,
    mode,
    startedAt,
    endedAt,
    day,
    hour,
    activeMs,
    listeningMs,
    fromLocator,
    toLocator,
    words,
    pages,
    open,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reading_sessions';
  @override
  VerificationContext validateIntegrity(Insertable<ReadingSession> instance, {bool isInserting = false}) {
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
    if (data.containsKey('format')) {
      context.handle(_formatMeta, format.isAcceptableOrUnknown(data['format']!, _formatMeta));
    } else if (isInserting) {
      context.missing(_formatMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(_modeMeta, mode.isAcceptableOrUnknown(data['mode']!, _modeMeta));
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('started_at')) {
      context.handle(_startedAtMeta, startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta));
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(_endedAtMeta, endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta));
    } else if (isInserting) {
      context.missing(_endedAtMeta);
    }
    if (data.containsKey('day')) {
      context.handle(_dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('hour')) {
      context.handle(_hourMeta, hour.isAcceptableOrUnknown(data['hour']!, _hourMeta));
    }
    if (data.containsKey('active_ms')) {
      context.handle(_activeMsMeta, activeMs.isAcceptableOrUnknown(data['active_ms']!, _activeMsMeta));
    }
    if (data.containsKey('listening_ms')) {
      context.handle(_listeningMsMeta, listeningMs.isAcceptableOrUnknown(data['listening_ms']!, _listeningMsMeta));
    }
    if (data.containsKey('from_locator')) {
      context.handle(_fromLocatorMeta, fromLocator.isAcceptableOrUnknown(data['from_locator']!, _fromLocatorMeta));
    }
    if (data.containsKey('to_locator')) {
      context.handle(_toLocatorMeta, toLocator.isAcceptableOrUnknown(data['to_locator']!, _toLocatorMeta));
    }
    if (data.containsKey('words')) {
      context.handle(_wordsMeta, words.isAcceptableOrUnknown(data['words']!, _wordsMeta));
    }
    if (data.containsKey('pages')) {
      context.handle(_pagesMeta, pages.isAcceptableOrUnknown(data['pages']!, _pagesMeta));
    }
    if (data.containsKey('open')) {
      context.handle(_openMeta, open.isAcceptableOrUnknown(data['open']!, _openMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ReadingSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ReadingSession(
      id: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      fingerprint: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fingerprint'])!,
      format: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}format'])!,
      mode: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}mode'])!,
      startedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}started_at'])!,
      endedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}ended_at'])!,
      day: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      hour: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}hour'])!,
      activeMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}active_ms'])!,
      listeningMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}listening_ms'])!,
      fromLocator: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}from_locator']),
      toLocator: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}to_locator']),
      words: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}words'])!,
      pages: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}pages'])!,
      open: attachedDatabase.typeMapping.read(DriftSqlType.bool, data['${effectivePrefix}open'])!,
    );
  }

  @override
  $ReadingSessionsTable createAlias(String alias) {
    return $ReadingSessionsTable(attachedDatabase, alias);
  }
}

class ReadingSession extends DataClass implements Insertable<ReadingSession> {
  final int id;
  final String fingerprint;

  /// Registry id ('epub', 'kindle', 'comics'...), for the formats breakdown.
  final String format;

  /// 'reader', 'page' (PDF, DOCX pages, slides) or 'comics'.
  final String mode;
  final DateTime startedAt;
  final DateTime endedAt;

  /// The local date it started, as yyyymmdd.
  final int day;

  /// The local hour it started, for time of day.
  final int hour;
  final int activeMs;
  final int listeningMs;
  final String? fromLocator;
  final String? toLocator;

  /// Forward progress only: words read (Reader mode), unique pages (Page
  /// view, comics).
  final int words;
  final int pages;

  /// Still running: a crash leaves it open, and the next launch folds it in.
  final bool open;
  const ReadingSession({
    required this.id,
    required this.fingerprint,
    required this.format,
    required this.mode,
    required this.startedAt,
    required this.endedAt,
    required this.day,
    required this.hour,
    required this.activeMs,
    required this.listeningMs,
    this.fromLocator,
    this.toLocator,
    required this.words,
    required this.pages,
    required this.open,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['fingerprint'] = Variable<String>(fingerprint);
    map['format'] = Variable<String>(format);
    map['mode'] = Variable<String>(mode);
    map['started_at'] = Variable<DateTime>(startedAt);
    map['ended_at'] = Variable<DateTime>(endedAt);
    map['day'] = Variable<int>(day);
    map['hour'] = Variable<int>(hour);
    map['active_ms'] = Variable<int>(activeMs);
    map['listening_ms'] = Variable<int>(listeningMs);
    if (!nullToAbsent || fromLocator != null) {
      map['from_locator'] = Variable<String>(fromLocator);
    }
    if (!nullToAbsent || toLocator != null) {
      map['to_locator'] = Variable<String>(toLocator);
    }
    map['words'] = Variable<int>(words);
    map['pages'] = Variable<int>(pages);
    map['open'] = Variable<bool>(open);
    return map;
  }

  ReadingSessionsCompanion toCompanion(bool nullToAbsent) {
    return ReadingSessionsCompanion(
      id: Value(id),
      fingerprint: Value(fingerprint),
      format: Value(format),
      mode: Value(mode),
      startedAt: Value(startedAt),
      endedAt: Value(endedAt),
      day: Value(day),
      hour: Value(hour),
      activeMs: Value(activeMs),
      listeningMs: Value(listeningMs),
      fromLocator: fromLocator == null && nullToAbsent ? const Value.absent() : Value(fromLocator),
      toLocator: toLocator == null && nullToAbsent ? const Value.absent() : Value(toLocator),
      words: Value(words),
      pages: Value(pages),
      open: Value(open),
    );
  }

  factory ReadingSession.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ReadingSession(
      id: serializer.fromJson<int>(json['id']),
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      format: serializer.fromJson<String>(json['format']),
      mode: serializer.fromJson<String>(json['mode']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime>(json['endedAt']),
      day: serializer.fromJson<int>(json['day']),
      hour: serializer.fromJson<int>(json['hour']),
      activeMs: serializer.fromJson<int>(json['activeMs']),
      listeningMs: serializer.fromJson<int>(json['listeningMs']),
      fromLocator: serializer.fromJson<String?>(json['fromLocator']),
      toLocator: serializer.fromJson<String?>(json['toLocator']),
      words: serializer.fromJson<int>(json['words']),
      pages: serializer.fromJson<int>(json['pages']),
      open: serializer.fromJson<bool>(json['open']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'fingerprint': serializer.toJson<String>(fingerprint),
      'format': serializer.toJson<String>(format),
      'mode': serializer.toJson<String>(mode),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime>(endedAt),
      'day': serializer.toJson<int>(day),
      'hour': serializer.toJson<int>(hour),
      'activeMs': serializer.toJson<int>(activeMs),
      'listeningMs': serializer.toJson<int>(listeningMs),
      'fromLocator': serializer.toJson<String?>(fromLocator),
      'toLocator': serializer.toJson<String?>(toLocator),
      'words': serializer.toJson<int>(words),
      'pages': serializer.toJson<int>(pages),
      'open': serializer.toJson<bool>(open),
    };
  }

  ReadingSession copyWith({
    int? id,
    String? fingerprint,
    String? format,
    String? mode,
    DateTime? startedAt,
    DateTime? endedAt,
    int? day,
    int? hour,
    int? activeMs,
    int? listeningMs,
    Value<String?> fromLocator = const Value.absent(),
    Value<String?> toLocator = const Value.absent(),
    int? words,
    int? pages,
    bool? open,
  }) => ReadingSession(
    id: id ?? this.id,
    fingerprint: fingerprint ?? this.fingerprint,
    format: format ?? this.format,
    mode: mode ?? this.mode,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt ?? this.endedAt,
    day: day ?? this.day,
    hour: hour ?? this.hour,
    activeMs: activeMs ?? this.activeMs,
    listeningMs: listeningMs ?? this.listeningMs,
    fromLocator: fromLocator.present ? fromLocator.value : this.fromLocator,
    toLocator: toLocator.present ? toLocator.value : this.toLocator,
    words: words ?? this.words,
    pages: pages ?? this.pages,
    open: open ?? this.open,
  );
  ReadingSession copyWithCompanion(ReadingSessionsCompanion data) {
    return ReadingSession(
      id: data.id.present ? data.id.value : this.id,
      fingerprint: data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
      format: data.format.present ? data.format.value : this.format,
      mode: data.mode.present ? data.mode.value : this.mode,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      day: data.day.present ? data.day.value : this.day,
      hour: data.hour.present ? data.hour.value : this.hour,
      activeMs: data.activeMs.present ? data.activeMs.value : this.activeMs,
      listeningMs: data.listeningMs.present ? data.listeningMs.value : this.listeningMs,
      fromLocator: data.fromLocator.present ? data.fromLocator.value : this.fromLocator,
      toLocator: data.toLocator.present ? data.toLocator.value : this.toLocator,
      words: data.words.present ? data.words.value : this.words,
      pages: data.pages.present ? data.pages.value : this.pages,
      open: data.open.present ? data.open.value : this.open,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSession(')
          ..write('id: $id, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('format: $format, ')
          ..write('mode: $mode, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('day: $day, ')
          ..write('hour: $hour, ')
          ..write('activeMs: $activeMs, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('fromLocator: $fromLocator, ')
          ..write('toLocator: $toLocator, ')
          ..write('words: $words, ')
          ..write('pages: $pages, ')
          ..write('open: $open')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    fingerprint,
    format,
    mode,
    startedAt,
    endedAt,
    day,
    hour,
    activeMs,
    listeningMs,
    fromLocator,
    toLocator,
    words,
    pages,
    open,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ReadingSession &&
          other.id == this.id &&
          other.fingerprint == this.fingerprint &&
          other.format == this.format &&
          other.mode == this.mode &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.day == this.day &&
          other.hour == this.hour &&
          other.activeMs == this.activeMs &&
          other.listeningMs == this.listeningMs &&
          other.fromLocator == this.fromLocator &&
          other.toLocator == this.toLocator &&
          other.words == this.words &&
          other.pages == this.pages &&
          other.open == this.open);
}

class ReadingSessionsCompanion extends UpdateCompanion<ReadingSession> {
  final Value<int> id;
  final Value<String> fingerprint;
  final Value<String> format;
  final Value<String> mode;
  final Value<DateTime> startedAt;
  final Value<DateTime> endedAt;
  final Value<int> day;
  final Value<int> hour;
  final Value<int> activeMs;
  final Value<int> listeningMs;
  final Value<String?> fromLocator;
  final Value<String?> toLocator;
  final Value<int> words;
  final Value<int> pages;
  final Value<bool> open;
  const ReadingSessionsCompanion({
    this.id = const Value.absent(),
    this.fingerprint = const Value.absent(),
    this.format = const Value.absent(),
    this.mode = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.day = const Value.absent(),
    this.hour = const Value.absent(),
    this.activeMs = const Value.absent(),
    this.listeningMs = const Value.absent(),
    this.fromLocator = const Value.absent(),
    this.toLocator = const Value.absent(),
    this.words = const Value.absent(),
    this.pages = const Value.absent(),
    this.open = const Value.absent(),
  });
  ReadingSessionsCompanion.insert({
    this.id = const Value.absent(),
    required String fingerprint,
    required String format,
    required String mode,
    required DateTime startedAt,
    required DateTime endedAt,
    required int day,
    this.hour = const Value.absent(),
    this.activeMs = const Value.absent(),
    this.listeningMs = const Value.absent(),
    this.fromLocator = const Value.absent(),
    this.toLocator = const Value.absent(),
    this.words = const Value.absent(),
    this.pages = const Value.absent(),
    this.open = const Value.absent(),
  }) : fingerprint = Value(fingerprint),
       format = Value(format),
       mode = Value(mode),
       startedAt = Value(startedAt),
       endedAt = Value(endedAt),
       day = Value(day);
  static Insertable<ReadingSession> custom({
    Expression<int>? id,
    Expression<String>? fingerprint,
    Expression<String>? format,
    Expression<String>? mode,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<int>? day,
    Expression<int>? hour,
    Expression<int>? activeMs,
    Expression<int>? listeningMs,
    Expression<String>? fromLocator,
    Expression<String>? toLocator,
    Expression<int>? words,
    Expression<int>? pages,
    Expression<bool>? open,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (format != null) 'format': format,
      if (mode != null) 'mode': mode,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (day != null) 'day': day,
      if (hour != null) 'hour': hour,
      if (activeMs != null) 'active_ms': activeMs,
      if (listeningMs != null) 'listening_ms': listeningMs,
      if (fromLocator != null) 'from_locator': fromLocator,
      if (toLocator != null) 'to_locator': toLocator,
      if (words != null) 'words': words,
      if (pages != null) 'pages': pages,
      if (open != null) 'open': open,
    });
  }

  ReadingSessionsCompanion copyWith({
    Value<int>? id,
    Value<String>? fingerprint,
    Value<String>? format,
    Value<String>? mode,
    Value<DateTime>? startedAt,
    Value<DateTime>? endedAt,
    Value<int>? day,
    Value<int>? hour,
    Value<int>? activeMs,
    Value<int>? listeningMs,
    Value<String?>? fromLocator,
    Value<String?>? toLocator,
    Value<int>? words,
    Value<int>? pages,
    Value<bool>? open,
  }) {
    return ReadingSessionsCompanion(
      id: id ?? this.id,
      fingerprint: fingerprint ?? this.fingerprint,
      format: format ?? this.format,
      mode: mode ?? this.mode,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      day: day ?? this.day,
      hour: hour ?? this.hour,
      activeMs: activeMs ?? this.activeMs,
      listeningMs: listeningMs ?? this.listeningMs,
      fromLocator: fromLocator ?? this.fromLocator,
      toLocator: toLocator ?? this.toLocator,
      words: words ?? this.words,
      pages: pages ?? this.pages,
      open: open ?? this.open,
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
    if (format.present) {
      map['format'] = Variable<String>(format.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (hour.present) {
      map['hour'] = Variable<int>(hour.value);
    }
    if (activeMs.present) {
      map['active_ms'] = Variable<int>(activeMs.value);
    }
    if (listeningMs.present) {
      map['listening_ms'] = Variable<int>(listeningMs.value);
    }
    if (fromLocator.present) {
      map['from_locator'] = Variable<String>(fromLocator.value);
    }
    if (toLocator.present) {
      map['to_locator'] = Variable<String>(toLocator.value);
    }
    if (words.present) {
      map['words'] = Variable<int>(words.value);
    }
    if (pages.present) {
      map['pages'] = Variable<int>(pages.value);
    }
    if (open.present) {
      map['open'] = Variable<bool>(open.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReadingSessionsCompanion(')
          ..write('id: $id, ')
          ..write('fingerprint: $fingerprint, ')
          ..write('format: $format, ')
          ..write('mode: $mode, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('day: $day, ')
          ..write('hour: $hour, ')
          ..write('activeMs: $activeMs, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('fromLocator: $fromLocator, ')
          ..write('toLocator: $toLocator, ')
          ..write('words: $words, ')
          ..write('pages: $pages, ')
          ..write('open: $open')
          ..write(')'))
        .toString();
  }
}

class $DailyStatsTable extends DailyStats with TableInfo<$DailyStatsTable, DailyStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _readingMsMeta = const VerificationMeta('readingMs');
  @override
  late final GeneratedColumn<int> readingMs = GeneratedColumn<int>(
    'reading_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _listeningMsMeta = const VerificationMeta('listeningMs');
  @override
  late final GeneratedColumn<int> listeningMs = GeneratedColumn<int>(
    'listening_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wordsMeta = const VerificationMeta('words');
  @override
  late final GeneratedColumn<int> words = GeneratedColumn<int>(
    'words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pagesMeta = const VerificationMeta('pages');
  @override
  late final GeneratedColumn<int> pages = GeneratedColumn<int>(
    'pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sessionsMeta = const VerificationMeta('sessions');
  @override
  late final GeneratedColumn<int> sessions = GeneratedColumn<int>(
    'sessions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readerMsMeta = const VerificationMeta('readerMs');
  @override
  late final GeneratedColumn<int> readerMs = GeneratedColumn<int>(
    'reader_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readerWordsMeta = const VerificationMeta('readerWords');
  @override
  late final GeneratedColumn<int> readerWords = GeneratedColumn<int>(
    'reader_words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pageMsMeta = const VerificationMeta('pageMs');
  @override
  late final GeneratedColumn<int> pageMs = GeneratedColumn<int>(
    'page_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pagePagesMeta = const VerificationMeta('pagePages');
  @override
  late final GeneratedColumn<int> pagePages = GeneratedColumn<int>(
    'page_pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestMsMeta = const VerificationMeta('longestMs');
  @override
  late final GeneratedColumn<int> longestMs = GeneratedColumn<int>(
    'longest_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestFpMeta = const VerificationMeta('longestFp');
  @override
  late final GeneratedColumn<String> longestFp = GeneratedColumn<String>(
    'longest_fp',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatMsMeta = const VerificationMeta('formatMs');
  @override
  late final GeneratedColumn<String> formatMs = GeneratedColumn<String>(
    'format_ms',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _hourMsMeta = const VerificationMeta('hourMs');
  @override
  late final GeneratedColumn<String> hourMs = GeneratedColumn<String>(
    'hour_ms',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  @override
  List<GeneratedColumn> get $columns => [
    day,
    readingMs,
    listeningMs,
    words,
    pages,
    sessions,
    readerMs,
    readerWords,
    pageMs,
    pagePages,
    longestMs,
    longestFp,
    formatMs,
    hourMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_stats';
  @override
  VerificationContext validateIntegrity(Insertable<DailyStat> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(_dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    }
    if (data.containsKey('reading_ms')) {
      context.handle(_readingMsMeta, readingMs.isAcceptableOrUnknown(data['reading_ms']!, _readingMsMeta));
    }
    if (data.containsKey('listening_ms')) {
      context.handle(_listeningMsMeta, listeningMs.isAcceptableOrUnknown(data['listening_ms']!, _listeningMsMeta));
    }
    if (data.containsKey('words')) {
      context.handle(_wordsMeta, words.isAcceptableOrUnknown(data['words']!, _wordsMeta));
    }
    if (data.containsKey('pages')) {
      context.handle(_pagesMeta, pages.isAcceptableOrUnknown(data['pages']!, _pagesMeta));
    }
    if (data.containsKey('sessions')) {
      context.handle(_sessionsMeta, sessions.isAcceptableOrUnknown(data['sessions']!, _sessionsMeta));
    }
    if (data.containsKey('reader_ms')) {
      context.handle(_readerMsMeta, readerMs.isAcceptableOrUnknown(data['reader_ms']!, _readerMsMeta));
    }
    if (data.containsKey('reader_words')) {
      context.handle(_readerWordsMeta, readerWords.isAcceptableOrUnknown(data['reader_words']!, _readerWordsMeta));
    }
    if (data.containsKey('page_ms')) {
      context.handle(_pageMsMeta, pageMs.isAcceptableOrUnknown(data['page_ms']!, _pageMsMeta));
    }
    if (data.containsKey('page_pages')) {
      context.handle(_pagePagesMeta, pagePages.isAcceptableOrUnknown(data['page_pages']!, _pagePagesMeta));
    }
    if (data.containsKey('longest_ms')) {
      context.handle(_longestMsMeta, longestMs.isAcceptableOrUnknown(data['longest_ms']!, _longestMsMeta));
    }
    if (data.containsKey('longest_fp')) {
      context.handle(_longestFpMeta, longestFp.isAcceptableOrUnknown(data['longest_fp']!, _longestFpMeta));
    }
    if (data.containsKey('format_ms')) {
      context.handle(_formatMsMeta, formatMs.isAcceptableOrUnknown(data['format_ms']!, _formatMsMeta));
    }
    if (data.containsKey('hour_ms')) {
      context.handle(_hourMsMeta, hourMs.isAcceptableOrUnknown(data['hour_ms']!, _hourMsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day};
  @override
  DailyStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyStat(
      day: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      readingMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reading_ms'])!,
      listeningMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}listening_ms'])!,
      words: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}words'])!,
      pages: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}pages'])!,
      sessions: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sessions'])!,
      readerMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reader_ms'])!,
      readerWords: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reader_words'])!,
      pageMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}page_ms'])!,
      pagePages: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}page_pages'])!,
      longestMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}longest_ms'])!,
      longestFp: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}longest_fp']),
      formatMs: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}format_ms'])!,
      hourMs: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}hour_ms'])!,
    );
  }

  @override
  $DailyStatsTable createAlias(String alias) {
    return $DailyStatsTable(attachedDatabase, alias);
  }
}

class DailyStat extends DataClass implements Insertable<DailyStat> {
  final int day;
  final int readingMs;
  final int listeningMs;
  final int words;
  final int pages;
  final int sessions;

  /// Time and progress per mode, for reading speed.
  final int readerMs;
  final int readerWords;
  final int pageMs;
  final int pagePages;

  /// The day's longest session and its book.
  final int longestMs;
  final String? longestFp;

  /// Reading ms per format id, as JSON.
  final String formatMs;

  /// Reading ms per local hour, 24 comma-separated numbers.
  final String hourMs;
  const DailyStat({
    required this.day,
    required this.readingMs,
    required this.listeningMs,
    required this.words,
    required this.pages,
    required this.sessions,
    required this.readerMs,
    required this.readerWords,
    required this.pageMs,
    required this.pagePages,
    required this.longestMs,
    this.longestFp,
    required this.formatMs,
    required this.hourMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<int>(day);
    map['reading_ms'] = Variable<int>(readingMs);
    map['listening_ms'] = Variable<int>(listeningMs);
    map['words'] = Variable<int>(words);
    map['pages'] = Variable<int>(pages);
    map['sessions'] = Variable<int>(sessions);
    map['reader_ms'] = Variable<int>(readerMs);
    map['reader_words'] = Variable<int>(readerWords);
    map['page_ms'] = Variable<int>(pageMs);
    map['page_pages'] = Variable<int>(pagePages);
    map['longest_ms'] = Variable<int>(longestMs);
    if (!nullToAbsent || longestFp != null) {
      map['longest_fp'] = Variable<String>(longestFp);
    }
    map['format_ms'] = Variable<String>(formatMs);
    map['hour_ms'] = Variable<String>(hourMs);
    return map;
  }

  DailyStatsCompanion toCompanion(bool nullToAbsent) {
    return DailyStatsCompanion(
      day: Value(day),
      readingMs: Value(readingMs),
      listeningMs: Value(listeningMs),
      words: Value(words),
      pages: Value(pages),
      sessions: Value(sessions),
      readerMs: Value(readerMs),
      readerWords: Value(readerWords),
      pageMs: Value(pageMs),
      pagePages: Value(pagePages),
      longestMs: Value(longestMs),
      longestFp: longestFp == null && nullToAbsent ? const Value.absent() : Value(longestFp),
      formatMs: Value(formatMs),
      hourMs: Value(hourMs),
    );
  }

  factory DailyStat.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyStat(
      day: serializer.fromJson<int>(json['day']),
      readingMs: serializer.fromJson<int>(json['readingMs']),
      listeningMs: serializer.fromJson<int>(json['listeningMs']),
      words: serializer.fromJson<int>(json['words']),
      pages: serializer.fromJson<int>(json['pages']),
      sessions: serializer.fromJson<int>(json['sessions']),
      readerMs: serializer.fromJson<int>(json['readerMs']),
      readerWords: serializer.fromJson<int>(json['readerWords']),
      pageMs: serializer.fromJson<int>(json['pageMs']),
      pagePages: serializer.fromJson<int>(json['pagePages']),
      longestMs: serializer.fromJson<int>(json['longestMs']),
      longestFp: serializer.fromJson<String?>(json['longestFp']),
      formatMs: serializer.fromJson<String>(json['formatMs']),
      hourMs: serializer.fromJson<String>(json['hourMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<int>(day),
      'readingMs': serializer.toJson<int>(readingMs),
      'listeningMs': serializer.toJson<int>(listeningMs),
      'words': serializer.toJson<int>(words),
      'pages': serializer.toJson<int>(pages),
      'sessions': serializer.toJson<int>(sessions),
      'readerMs': serializer.toJson<int>(readerMs),
      'readerWords': serializer.toJson<int>(readerWords),
      'pageMs': serializer.toJson<int>(pageMs),
      'pagePages': serializer.toJson<int>(pagePages),
      'longestMs': serializer.toJson<int>(longestMs),
      'longestFp': serializer.toJson<String?>(longestFp),
      'formatMs': serializer.toJson<String>(formatMs),
      'hourMs': serializer.toJson<String>(hourMs),
    };
  }

  DailyStat copyWith({
    int? day,
    int? readingMs,
    int? listeningMs,
    int? words,
    int? pages,
    int? sessions,
    int? readerMs,
    int? readerWords,
    int? pageMs,
    int? pagePages,
    int? longestMs,
    Value<String?> longestFp = const Value.absent(),
    String? formatMs,
    String? hourMs,
  }) => DailyStat(
    day: day ?? this.day,
    readingMs: readingMs ?? this.readingMs,
    listeningMs: listeningMs ?? this.listeningMs,
    words: words ?? this.words,
    pages: pages ?? this.pages,
    sessions: sessions ?? this.sessions,
    readerMs: readerMs ?? this.readerMs,
    readerWords: readerWords ?? this.readerWords,
    pageMs: pageMs ?? this.pageMs,
    pagePages: pagePages ?? this.pagePages,
    longestMs: longestMs ?? this.longestMs,
    longestFp: longestFp.present ? longestFp.value : this.longestFp,
    formatMs: formatMs ?? this.formatMs,
    hourMs: hourMs ?? this.hourMs,
  );
  DailyStat copyWithCompanion(DailyStatsCompanion data) {
    return DailyStat(
      day: data.day.present ? data.day.value : this.day,
      readingMs: data.readingMs.present ? data.readingMs.value : this.readingMs,
      listeningMs: data.listeningMs.present ? data.listeningMs.value : this.listeningMs,
      words: data.words.present ? data.words.value : this.words,
      pages: data.pages.present ? data.pages.value : this.pages,
      sessions: data.sessions.present ? data.sessions.value : this.sessions,
      readerMs: data.readerMs.present ? data.readerMs.value : this.readerMs,
      readerWords: data.readerWords.present ? data.readerWords.value : this.readerWords,
      pageMs: data.pageMs.present ? data.pageMs.value : this.pageMs,
      pagePages: data.pagePages.present ? data.pagePages.value : this.pagePages,
      longestMs: data.longestMs.present ? data.longestMs.value : this.longestMs,
      longestFp: data.longestFp.present ? data.longestFp.value : this.longestFp,
      formatMs: data.formatMs.present ? data.formatMs.value : this.formatMs,
      hourMs: data.hourMs.present ? data.hourMs.value : this.hourMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyStat(')
          ..write('day: $day, ')
          ..write('readingMs: $readingMs, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('words: $words, ')
          ..write('pages: $pages, ')
          ..write('sessions: $sessions, ')
          ..write('readerMs: $readerMs, ')
          ..write('readerWords: $readerWords, ')
          ..write('pageMs: $pageMs, ')
          ..write('pagePages: $pagePages, ')
          ..write('longestMs: $longestMs, ')
          ..write('longestFp: $longestFp, ')
          ..write('formatMs: $formatMs, ')
          ..write('hourMs: $hourMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    day,
    readingMs,
    listeningMs,
    words,
    pages,
    sessions,
    readerMs,
    readerWords,
    pageMs,
    pagePages,
    longestMs,
    longestFp,
    formatMs,
    hourMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyStat &&
          other.day == this.day &&
          other.readingMs == this.readingMs &&
          other.listeningMs == this.listeningMs &&
          other.words == this.words &&
          other.pages == this.pages &&
          other.sessions == this.sessions &&
          other.readerMs == this.readerMs &&
          other.readerWords == this.readerWords &&
          other.pageMs == this.pageMs &&
          other.pagePages == this.pagePages &&
          other.longestMs == this.longestMs &&
          other.longestFp == this.longestFp &&
          other.formatMs == this.formatMs &&
          other.hourMs == this.hourMs);
}

class DailyStatsCompanion extends UpdateCompanion<DailyStat> {
  final Value<int> day;
  final Value<int> readingMs;
  final Value<int> listeningMs;
  final Value<int> words;
  final Value<int> pages;
  final Value<int> sessions;
  final Value<int> readerMs;
  final Value<int> readerWords;
  final Value<int> pageMs;
  final Value<int> pagePages;
  final Value<int> longestMs;
  final Value<String?> longestFp;
  final Value<String> formatMs;
  final Value<String> hourMs;
  const DailyStatsCompanion({
    this.day = const Value.absent(),
    this.readingMs = const Value.absent(),
    this.listeningMs = const Value.absent(),
    this.words = const Value.absent(),
    this.pages = const Value.absent(),
    this.sessions = const Value.absent(),
    this.readerMs = const Value.absent(),
    this.readerWords = const Value.absent(),
    this.pageMs = const Value.absent(),
    this.pagePages = const Value.absent(),
    this.longestMs = const Value.absent(),
    this.longestFp = const Value.absent(),
    this.formatMs = const Value.absent(),
    this.hourMs = const Value.absent(),
  });
  DailyStatsCompanion.insert({
    this.day = const Value.absent(),
    this.readingMs = const Value.absent(),
    this.listeningMs = const Value.absent(),
    this.words = const Value.absent(),
    this.pages = const Value.absent(),
    this.sessions = const Value.absent(),
    this.readerMs = const Value.absent(),
    this.readerWords = const Value.absent(),
    this.pageMs = const Value.absent(),
    this.pagePages = const Value.absent(),
    this.longestMs = const Value.absent(),
    this.longestFp = const Value.absent(),
    this.formatMs = const Value.absent(),
    this.hourMs = const Value.absent(),
  });
  static Insertable<DailyStat> custom({
    Expression<int>? day,
    Expression<int>? readingMs,
    Expression<int>? listeningMs,
    Expression<int>? words,
    Expression<int>? pages,
    Expression<int>? sessions,
    Expression<int>? readerMs,
    Expression<int>? readerWords,
    Expression<int>? pageMs,
    Expression<int>? pagePages,
    Expression<int>? longestMs,
    Expression<String>? longestFp,
    Expression<String>? formatMs,
    Expression<String>? hourMs,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (readingMs != null) 'reading_ms': readingMs,
      if (listeningMs != null) 'listening_ms': listeningMs,
      if (words != null) 'words': words,
      if (pages != null) 'pages': pages,
      if (sessions != null) 'sessions': sessions,
      if (readerMs != null) 'reader_ms': readerMs,
      if (readerWords != null) 'reader_words': readerWords,
      if (pageMs != null) 'page_ms': pageMs,
      if (pagePages != null) 'page_pages': pagePages,
      if (longestMs != null) 'longest_ms': longestMs,
      if (longestFp != null) 'longest_fp': longestFp,
      if (formatMs != null) 'format_ms': formatMs,
      if (hourMs != null) 'hour_ms': hourMs,
    });
  }

  DailyStatsCompanion copyWith({
    Value<int>? day,
    Value<int>? readingMs,
    Value<int>? listeningMs,
    Value<int>? words,
    Value<int>? pages,
    Value<int>? sessions,
    Value<int>? readerMs,
    Value<int>? readerWords,
    Value<int>? pageMs,
    Value<int>? pagePages,
    Value<int>? longestMs,
    Value<String?>? longestFp,
    Value<String>? formatMs,
    Value<String>? hourMs,
  }) {
    return DailyStatsCompanion(
      day: day ?? this.day,
      readingMs: readingMs ?? this.readingMs,
      listeningMs: listeningMs ?? this.listeningMs,
      words: words ?? this.words,
      pages: pages ?? this.pages,
      sessions: sessions ?? this.sessions,
      readerMs: readerMs ?? this.readerMs,
      readerWords: readerWords ?? this.readerWords,
      pageMs: pageMs ?? this.pageMs,
      pagePages: pagePages ?? this.pagePages,
      longestMs: longestMs ?? this.longestMs,
      longestFp: longestFp ?? this.longestFp,
      formatMs: formatMs ?? this.formatMs,
      hourMs: hourMs ?? this.hourMs,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (readingMs.present) {
      map['reading_ms'] = Variable<int>(readingMs.value);
    }
    if (listeningMs.present) {
      map['listening_ms'] = Variable<int>(listeningMs.value);
    }
    if (words.present) {
      map['words'] = Variable<int>(words.value);
    }
    if (pages.present) {
      map['pages'] = Variable<int>(pages.value);
    }
    if (sessions.present) {
      map['sessions'] = Variable<int>(sessions.value);
    }
    if (readerMs.present) {
      map['reader_ms'] = Variable<int>(readerMs.value);
    }
    if (readerWords.present) {
      map['reader_words'] = Variable<int>(readerWords.value);
    }
    if (pageMs.present) {
      map['page_ms'] = Variable<int>(pageMs.value);
    }
    if (pagePages.present) {
      map['page_pages'] = Variable<int>(pagePages.value);
    }
    if (longestMs.present) {
      map['longest_ms'] = Variable<int>(longestMs.value);
    }
    if (longestFp.present) {
      map['longest_fp'] = Variable<String>(longestFp.value);
    }
    if (formatMs.present) {
      map['format_ms'] = Variable<String>(formatMs.value);
    }
    if (hourMs.present) {
      map['hour_ms'] = Variable<String>(hourMs.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyStatsCompanion(')
          ..write('day: $day, ')
          ..write('readingMs: $readingMs, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('words: $words, ')
          ..write('pages: $pages, ')
          ..write('sessions: $sessions, ')
          ..write('readerMs: $readerMs, ')
          ..write('readerWords: $readerWords, ')
          ..write('pageMs: $pageMs, ')
          ..write('pagePages: $pagePages, ')
          ..write('longestMs: $longestMs, ')
          ..write('longestFp: $longestFp, ')
          ..write('formatMs: $formatMs, ')
          ..write('hourMs: $hourMs')
          ..write(')'))
        .toString();
  }
}

class $BookStatsTable extends BookStats with TableInfo<$BookStatsTable, BookStat> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fingerprintMeta = const VerificationMeta('fingerprint');
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _readingMsMeta = const VerificationMeta('readingMs');
  @override
  late final GeneratedColumn<int> readingMs = GeneratedColumn<int>(
    'reading_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _listeningMsMeta = const VerificationMeta('listeningMs');
  @override
  late final GeneratedColumn<int> listeningMs = GeneratedColumn<int>(
    'listening_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sessionsMeta = const VerificationMeta('sessions');
  @override
  late final GeneratedColumn<int> sessions = GeneratedColumn<int>(
    'sessions',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _wordsMeta = const VerificationMeta('words');
  @override
  late final GeneratedColumn<int> words = GeneratedColumn<int>(
    'words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pagesMeta = const VerificationMeta('pages');
  @override
  late final GeneratedColumn<int> pages = GeneratedColumn<int>(
    'pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readerMsMeta = const VerificationMeta('readerMs');
  @override
  late final GeneratedColumn<int> readerMs = GeneratedColumn<int>(
    'reader_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _readerWordsMeta = const VerificationMeta('readerWords');
  @override
  late final GeneratedColumn<int> readerWords = GeneratedColumn<int>(
    'reader_words',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pageMsMeta = const VerificationMeta('pageMs');
  @override
  late final GeneratedColumn<int> pageMs = GeneratedColumn<int>(
    'page_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _pagePagesMeta = const VerificationMeta('pagePages');
  @override
  late final GeneratedColumn<int> pagePages = GeneratedColumn<int>(
    'page_pages',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _longestMsMeta = const VerificationMeta('longestMs');
  @override
  late final GeneratedColumn<int> longestMs = GeneratedColumn<int>(
    'longest_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _medianPageMsMeta = const VerificationMeta('medianPageMs');
  @override
  late final GeneratedColumn<int> medianPageMs = GeneratedColumn<int>(
    'median_page_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _totalWordsMeta = const VerificationMeta('totalWords');
  @override
  late final GeneratedColumn<int> totalWords = GeneratedColumn<int>(
    'total_words',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _wordsLeftMeta = const VerificationMeta('wordsLeft');
  @override
  late final GeneratedColumn<int> wordsLeft = GeneratedColumn<int>(
    'words_left',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _firstReadMeta = const VerificationMeta('firstRead');
  @override
  late final GeneratedColumn<DateTime> firstRead = GeneratedColumn<DateTime>(
    'first_read',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastReadMeta = const VerificationMeta('lastRead');
  @override
  late final GeneratedColumn<DateTime> lastRead = GeneratedColumn<DateTime>(
    'last_read',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _finishedAtMeta = const VerificationMeta('finishedAt');
  @override
  late final GeneratedColumn<DateTime> finishedAt = GeneratedColumn<DateTime>(
    'finished_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    fingerprint,
    readingMs,
    listeningMs,
    sessions,
    words,
    pages,
    readerMs,
    readerWords,
    pageMs,
    pagePages,
    longestMs,
    medianPageMs,
    totalWords,
    wordsLeft,
    firstRead,
    lastRead,
    finishedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_stats';
  @override
  VerificationContext validateIntegrity(Insertable<BookStat> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fingerprint')) {
      context.handle(_fingerprintMeta, fingerprint.isAcceptableOrUnknown(data['fingerprint']!, _fingerprintMeta));
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('reading_ms')) {
      context.handle(_readingMsMeta, readingMs.isAcceptableOrUnknown(data['reading_ms']!, _readingMsMeta));
    }
    if (data.containsKey('listening_ms')) {
      context.handle(_listeningMsMeta, listeningMs.isAcceptableOrUnknown(data['listening_ms']!, _listeningMsMeta));
    }
    if (data.containsKey('sessions')) {
      context.handle(_sessionsMeta, sessions.isAcceptableOrUnknown(data['sessions']!, _sessionsMeta));
    }
    if (data.containsKey('words')) {
      context.handle(_wordsMeta, words.isAcceptableOrUnknown(data['words']!, _wordsMeta));
    }
    if (data.containsKey('pages')) {
      context.handle(_pagesMeta, pages.isAcceptableOrUnknown(data['pages']!, _pagesMeta));
    }
    if (data.containsKey('reader_ms')) {
      context.handle(_readerMsMeta, readerMs.isAcceptableOrUnknown(data['reader_ms']!, _readerMsMeta));
    }
    if (data.containsKey('reader_words')) {
      context.handle(_readerWordsMeta, readerWords.isAcceptableOrUnknown(data['reader_words']!, _readerWordsMeta));
    }
    if (data.containsKey('page_ms')) {
      context.handle(_pageMsMeta, pageMs.isAcceptableOrUnknown(data['page_ms']!, _pageMsMeta));
    }
    if (data.containsKey('page_pages')) {
      context.handle(_pagePagesMeta, pagePages.isAcceptableOrUnknown(data['page_pages']!, _pagePagesMeta));
    }
    if (data.containsKey('longest_ms')) {
      context.handle(_longestMsMeta, longestMs.isAcceptableOrUnknown(data['longest_ms']!, _longestMsMeta));
    }
    if (data.containsKey('median_page_ms')) {
      context.handle(_medianPageMsMeta, medianPageMs.isAcceptableOrUnknown(data['median_page_ms']!, _medianPageMsMeta));
    }
    if (data.containsKey('total_words')) {
      context.handle(_totalWordsMeta, totalWords.isAcceptableOrUnknown(data['total_words']!, _totalWordsMeta));
    }
    if (data.containsKey('words_left')) {
      context.handle(_wordsLeftMeta, wordsLeft.isAcceptableOrUnknown(data['words_left']!, _wordsLeftMeta));
    }
    if (data.containsKey('first_read')) {
      context.handle(_firstReadMeta, firstRead.isAcceptableOrUnknown(data['first_read']!, _firstReadMeta));
    }
    if (data.containsKey('last_read')) {
      context.handle(_lastReadMeta, lastRead.isAcceptableOrUnknown(data['last_read']!, _lastReadMeta));
    }
    if (data.containsKey('finished_at')) {
      context.handle(_finishedAtMeta, finishedAt.isAcceptableOrUnknown(data['finished_at']!, _finishedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fingerprint};
  @override
  BookStat map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookStat(
      fingerprint: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fingerprint'])!,
      readingMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reading_ms'])!,
      listeningMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}listening_ms'])!,
      sessions: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}sessions'])!,
      words: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}words'])!,
      pages: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}pages'])!,
      readerMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reader_ms'])!,
      readerWords: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}reader_words'])!,
      pageMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}page_ms'])!,
      pagePages: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}page_pages'])!,
      longestMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}longest_ms'])!,
      medianPageMs: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}median_page_ms'])!,
      totalWords: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}total_words']),
      wordsLeft: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}words_left']),
      firstRead: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}first_read']),
      lastRead: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}last_read']),
      finishedAt: attachedDatabase.typeMapping.read(DriftSqlType.dateTime, data['${effectivePrefix}finished_at']),
    );
  }

  @override
  $BookStatsTable createAlias(String alias) {
    return $BookStatsTable(attachedDatabase, alias);
  }
}

class BookStat extends DataClass implements Insertable<BookStat> {
  final String fingerprint;
  final int readingMs;
  final int listeningMs;
  final int sessions;
  final int words;
  final int pages;
  final int readerMs;
  final int readerWords;
  final int pageMs;
  final int pagePages;
  final int longestMs;

  /// A running median of time per page or screen, for the idle threshold.
  final int medianPageMs;

  /// Words in the book and words after the last place read (Reader mode),
  /// for "Estimated time left" (schema 4). Page and comic books use units.
  final int? totalWords;
  final int? wordsLeft;
  final DateTime? firstRead;
  final DateTime? lastRead;
  final DateTime? finishedAt;
  const BookStat({
    required this.fingerprint,
    required this.readingMs,
    required this.listeningMs,
    required this.sessions,
    required this.words,
    required this.pages,
    required this.readerMs,
    required this.readerWords,
    required this.pageMs,
    required this.pagePages,
    required this.longestMs,
    required this.medianPageMs,
    this.totalWords,
    this.wordsLeft,
    this.firstRead,
    this.lastRead,
    this.finishedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fingerprint'] = Variable<String>(fingerprint);
    map['reading_ms'] = Variable<int>(readingMs);
    map['listening_ms'] = Variable<int>(listeningMs);
    map['sessions'] = Variable<int>(sessions);
    map['words'] = Variable<int>(words);
    map['pages'] = Variable<int>(pages);
    map['reader_ms'] = Variable<int>(readerMs);
    map['reader_words'] = Variable<int>(readerWords);
    map['page_ms'] = Variable<int>(pageMs);
    map['page_pages'] = Variable<int>(pagePages);
    map['longest_ms'] = Variable<int>(longestMs);
    map['median_page_ms'] = Variable<int>(medianPageMs);
    if (!nullToAbsent || totalWords != null) {
      map['total_words'] = Variable<int>(totalWords);
    }
    if (!nullToAbsent || wordsLeft != null) {
      map['words_left'] = Variable<int>(wordsLeft);
    }
    if (!nullToAbsent || firstRead != null) {
      map['first_read'] = Variable<DateTime>(firstRead);
    }
    if (!nullToAbsent || lastRead != null) {
      map['last_read'] = Variable<DateTime>(lastRead);
    }
    if (!nullToAbsent || finishedAt != null) {
      map['finished_at'] = Variable<DateTime>(finishedAt);
    }
    return map;
  }

  BookStatsCompanion toCompanion(bool nullToAbsent) {
    return BookStatsCompanion(
      fingerprint: Value(fingerprint),
      readingMs: Value(readingMs),
      listeningMs: Value(listeningMs),
      sessions: Value(sessions),
      words: Value(words),
      pages: Value(pages),
      readerMs: Value(readerMs),
      readerWords: Value(readerWords),
      pageMs: Value(pageMs),
      pagePages: Value(pagePages),
      longestMs: Value(longestMs),
      medianPageMs: Value(medianPageMs),
      totalWords: totalWords == null && nullToAbsent ? const Value.absent() : Value(totalWords),
      wordsLeft: wordsLeft == null && nullToAbsent ? const Value.absent() : Value(wordsLeft),
      firstRead: firstRead == null && nullToAbsent ? const Value.absent() : Value(firstRead),
      lastRead: lastRead == null && nullToAbsent ? const Value.absent() : Value(lastRead),
      finishedAt: finishedAt == null && nullToAbsent ? const Value.absent() : Value(finishedAt),
    );
  }

  factory BookStat.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookStat(
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      readingMs: serializer.fromJson<int>(json['readingMs']),
      listeningMs: serializer.fromJson<int>(json['listeningMs']),
      sessions: serializer.fromJson<int>(json['sessions']),
      words: serializer.fromJson<int>(json['words']),
      pages: serializer.fromJson<int>(json['pages']),
      readerMs: serializer.fromJson<int>(json['readerMs']),
      readerWords: serializer.fromJson<int>(json['readerWords']),
      pageMs: serializer.fromJson<int>(json['pageMs']),
      pagePages: serializer.fromJson<int>(json['pagePages']),
      longestMs: serializer.fromJson<int>(json['longestMs']),
      medianPageMs: serializer.fromJson<int>(json['medianPageMs']),
      totalWords: serializer.fromJson<int?>(json['totalWords']),
      wordsLeft: serializer.fromJson<int?>(json['wordsLeft']),
      firstRead: serializer.fromJson<DateTime?>(json['firstRead']),
      lastRead: serializer.fromJson<DateTime?>(json['lastRead']),
      finishedAt: serializer.fromJson<DateTime?>(json['finishedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fingerprint': serializer.toJson<String>(fingerprint),
      'readingMs': serializer.toJson<int>(readingMs),
      'listeningMs': serializer.toJson<int>(listeningMs),
      'sessions': serializer.toJson<int>(sessions),
      'words': serializer.toJson<int>(words),
      'pages': serializer.toJson<int>(pages),
      'readerMs': serializer.toJson<int>(readerMs),
      'readerWords': serializer.toJson<int>(readerWords),
      'pageMs': serializer.toJson<int>(pageMs),
      'pagePages': serializer.toJson<int>(pagePages),
      'longestMs': serializer.toJson<int>(longestMs),
      'medianPageMs': serializer.toJson<int>(medianPageMs),
      'totalWords': serializer.toJson<int?>(totalWords),
      'wordsLeft': serializer.toJson<int?>(wordsLeft),
      'firstRead': serializer.toJson<DateTime?>(firstRead),
      'lastRead': serializer.toJson<DateTime?>(lastRead),
      'finishedAt': serializer.toJson<DateTime?>(finishedAt),
    };
  }

  BookStat copyWith({
    String? fingerprint,
    int? readingMs,
    int? listeningMs,
    int? sessions,
    int? words,
    int? pages,
    int? readerMs,
    int? readerWords,
    int? pageMs,
    int? pagePages,
    int? longestMs,
    int? medianPageMs,
    Value<int?> totalWords = const Value.absent(),
    Value<int?> wordsLeft = const Value.absent(),
    Value<DateTime?> firstRead = const Value.absent(),
    Value<DateTime?> lastRead = const Value.absent(),
    Value<DateTime?> finishedAt = const Value.absent(),
  }) => BookStat(
    fingerprint: fingerprint ?? this.fingerprint,
    readingMs: readingMs ?? this.readingMs,
    listeningMs: listeningMs ?? this.listeningMs,
    sessions: sessions ?? this.sessions,
    words: words ?? this.words,
    pages: pages ?? this.pages,
    readerMs: readerMs ?? this.readerMs,
    readerWords: readerWords ?? this.readerWords,
    pageMs: pageMs ?? this.pageMs,
    pagePages: pagePages ?? this.pagePages,
    longestMs: longestMs ?? this.longestMs,
    medianPageMs: medianPageMs ?? this.medianPageMs,
    totalWords: totalWords.present ? totalWords.value : this.totalWords,
    wordsLeft: wordsLeft.present ? wordsLeft.value : this.wordsLeft,
    firstRead: firstRead.present ? firstRead.value : this.firstRead,
    lastRead: lastRead.present ? lastRead.value : this.lastRead,
    finishedAt: finishedAt.present ? finishedAt.value : this.finishedAt,
  );
  BookStat copyWithCompanion(BookStatsCompanion data) {
    return BookStat(
      fingerprint: data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
      readingMs: data.readingMs.present ? data.readingMs.value : this.readingMs,
      listeningMs: data.listeningMs.present ? data.listeningMs.value : this.listeningMs,
      sessions: data.sessions.present ? data.sessions.value : this.sessions,
      words: data.words.present ? data.words.value : this.words,
      pages: data.pages.present ? data.pages.value : this.pages,
      readerMs: data.readerMs.present ? data.readerMs.value : this.readerMs,
      readerWords: data.readerWords.present ? data.readerWords.value : this.readerWords,
      pageMs: data.pageMs.present ? data.pageMs.value : this.pageMs,
      pagePages: data.pagePages.present ? data.pagePages.value : this.pagePages,
      longestMs: data.longestMs.present ? data.longestMs.value : this.longestMs,
      medianPageMs: data.medianPageMs.present ? data.medianPageMs.value : this.medianPageMs,
      totalWords: data.totalWords.present ? data.totalWords.value : this.totalWords,
      wordsLeft: data.wordsLeft.present ? data.wordsLeft.value : this.wordsLeft,
      firstRead: data.firstRead.present ? data.firstRead.value : this.firstRead,
      lastRead: data.lastRead.present ? data.lastRead.value : this.lastRead,
      finishedAt: data.finishedAt.present ? data.finishedAt.value : this.finishedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookStat(')
          ..write('fingerprint: $fingerprint, ')
          ..write('readingMs: $readingMs, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('sessions: $sessions, ')
          ..write('words: $words, ')
          ..write('pages: $pages, ')
          ..write('readerMs: $readerMs, ')
          ..write('readerWords: $readerWords, ')
          ..write('pageMs: $pageMs, ')
          ..write('pagePages: $pagePages, ')
          ..write('longestMs: $longestMs, ')
          ..write('medianPageMs: $medianPageMs, ')
          ..write('totalWords: $totalWords, ')
          ..write('wordsLeft: $wordsLeft, ')
          ..write('firstRead: $firstRead, ')
          ..write('lastRead: $lastRead, ')
          ..write('finishedAt: $finishedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    fingerprint,
    readingMs,
    listeningMs,
    sessions,
    words,
    pages,
    readerMs,
    readerWords,
    pageMs,
    pagePages,
    longestMs,
    medianPageMs,
    totalWords,
    wordsLeft,
    firstRead,
    lastRead,
    finishedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookStat &&
          other.fingerprint == this.fingerprint &&
          other.readingMs == this.readingMs &&
          other.listeningMs == this.listeningMs &&
          other.sessions == this.sessions &&
          other.words == this.words &&
          other.pages == this.pages &&
          other.readerMs == this.readerMs &&
          other.readerWords == this.readerWords &&
          other.pageMs == this.pageMs &&
          other.pagePages == this.pagePages &&
          other.longestMs == this.longestMs &&
          other.medianPageMs == this.medianPageMs &&
          other.totalWords == this.totalWords &&
          other.wordsLeft == this.wordsLeft &&
          other.firstRead == this.firstRead &&
          other.lastRead == this.lastRead &&
          other.finishedAt == this.finishedAt);
}

class BookStatsCompanion extends UpdateCompanion<BookStat> {
  final Value<String> fingerprint;
  final Value<int> readingMs;
  final Value<int> listeningMs;
  final Value<int> sessions;
  final Value<int> words;
  final Value<int> pages;
  final Value<int> readerMs;
  final Value<int> readerWords;
  final Value<int> pageMs;
  final Value<int> pagePages;
  final Value<int> longestMs;
  final Value<int> medianPageMs;
  final Value<int?> totalWords;
  final Value<int?> wordsLeft;
  final Value<DateTime?> firstRead;
  final Value<DateTime?> lastRead;
  final Value<DateTime?> finishedAt;
  final Value<int> rowid;
  const BookStatsCompanion({
    this.fingerprint = const Value.absent(),
    this.readingMs = const Value.absent(),
    this.listeningMs = const Value.absent(),
    this.sessions = const Value.absent(),
    this.words = const Value.absent(),
    this.pages = const Value.absent(),
    this.readerMs = const Value.absent(),
    this.readerWords = const Value.absent(),
    this.pageMs = const Value.absent(),
    this.pagePages = const Value.absent(),
    this.longestMs = const Value.absent(),
    this.medianPageMs = const Value.absent(),
    this.totalWords = const Value.absent(),
    this.wordsLeft = const Value.absent(),
    this.firstRead = const Value.absent(),
    this.lastRead = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookStatsCompanion.insert({
    required String fingerprint,
    this.readingMs = const Value.absent(),
    this.listeningMs = const Value.absent(),
    this.sessions = const Value.absent(),
    this.words = const Value.absent(),
    this.pages = const Value.absent(),
    this.readerMs = const Value.absent(),
    this.readerWords = const Value.absent(),
    this.pageMs = const Value.absent(),
    this.pagePages = const Value.absent(),
    this.longestMs = const Value.absent(),
    this.medianPageMs = const Value.absent(),
    this.totalWords = const Value.absent(),
    this.wordsLeft = const Value.absent(),
    this.firstRead = const Value.absent(),
    this.lastRead = const Value.absent(),
    this.finishedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fingerprint = Value(fingerprint);
  static Insertable<BookStat> custom({
    Expression<String>? fingerprint,
    Expression<int>? readingMs,
    Expression<int>? listeningMs,
    Expression<int>? sessions,
    Expression<int>? words,
    Expression<int>? pages,
    Expression<int>? readerMs,
    Expression<int>? readerWords,
    Expression<int>? pageMs,
    Expression<int>? pagePages,
    Expression<int>? longestMs,
    Expression<int>? medianPageMs,
    Expression<int>? totalWords,
    Expression<int>? wordsLeft,
    Expression<DateTime>? firstRead,
    Expression<DateTime>? lastRead,
    Expression<DateTime>? finishedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (readingMs != null) 'reading_ms': readingMs,
      if (listeningMs != null) 'listening_ms': listeningMs,
      if (sessions != null) 'sessions': sessions,
      if (words != null) 'words': words,
      if (pages != null) 'pages': pages,
      if (readerMs != null) 'reader_ms': readerMs,
      if (readerWords != null) 'reader_words': readerWords,
      if (pageMs != null) 'page_ms': pageMs,
      if (pagePages != null) 'page_pages': pagePages,
      if (longestMs != null) 'longest_ms': longestMs,
      if (medianPageMs != null) 'median_page_ms': medianPageMs,
      if (totalWords != null) 'total_words': totalWords,
      if (wordsLeft != null) 'words_left': wordsLeft,
      if (firstRead != null) 'first_read': firstRead,
      if (lastRead != null) 'last_read': lastRead,
      if (finishedAt != null) 'finished_at': finishedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookStatsCompanion copyWith({
    Value<String>? fingerprint,
    Value<int>? readingMs,
    Value<int>? listeningMs,
    Value<int>? sessions,
    Value<int>? words,
    Value<int>? pages,
    Value<int>? readerMs,
    Value<int>? readerWords,
    Value<int>? pageMs,
    Value<int>? pagePages,
    Value<int>? longestMs,
    Value<int>? medianPageMs,
    Value<int?>? totalWords,
    Value<int?>? wordsLeft,
    Value<DateTime?>? firstRead,
    Value<DateTime?>? lastRead,
    Value<DateTime?>? finishedAt,
    Value<int>? rowid,
  }) {
    return BookStatsCompanion(
      fingerprint: fingerprint ?? this.fingerprint,
      readingMs: readingMs ?? this.readingMs,
      listeningMs: listeningMs ?? this.listeningMs,
      sessions: sessions ?? this.sessions,
      words: words ?? this.words,
      pages: pages ?? this.pages,
      readerMs: readerMs ?? this.readerMs,
      readerWords: readerWords ?? this.readerWords,
      pageMs: pageMs ?? this.pageMs,
      pagePages: pagePages ?? this.pagePages,
      longestMs: longestMs ?? this.longestMs,
      medianPageMs: medianPageMs ?? this.medianPageMs,
      totalWords: totalWords ?? this.totalWords,
      wordsLeft: wordsLeft ?? this.wordsLeft,
      firstRead: firstRead ?? this.firstRead,
      lastRead: lastRead ?? this.lastRead,
      finishedAt: finishedAt ?? this.finishedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (readingMs.present) {
      map['reading_ms'] = Variable<int>(readingMs.value);
    }
    if (listeningMs.present) {
      map['listening_ms'] = Variable<int>(listeningMs.value);
    }
    if (sessions.present) {
      map['sessions'] = Variable<int>(sessions.value);
    }
    if (words.present) {
      map['words'] = Variable<int>(words.value);
    }
    if (pages.present) {
      map['pages'] = Variable<int>(pages.value);
    }
    if (readerMs.present) {
      map['reader_ms'] = Variable<int>(readerMs.value);
    }
    if (readerWords.present) {
      map['reader_words'] = Variable<int>(readerWords.value);
    }
    if (pageMs.present) {
      map['page_ms'] = Variable<int>(pageMs.value);
    }
    if (pagePages.present) {
      map['page_pages'] = Variable<int>(pagePages.value);
    }
    if (longestMs.present) {
      map['longest_ms'] = Variable<int>(longestMs.value);
    }
    if (medianPageMs.present) {
      map['median_page_ms'] = Variable<int>(medianPageMs.value);
    }
    if (totalWords.present) {
      map['total_words'] = Variable<int>(totalWords.value);
    }
    if (wordsLeft.present) {
      map['words_left'] = Variable<int>(wordsLeft.value);
    }
    if (firstRead.present) {
      map['first_read'] = Variable<DateTime>(firstRead.value);
    }
    if (lastRead.present) {
      map['last_read'] = Variable<DateTime>(lastRead.value);
    }
    if (finishedAt.present) {
      map['finished_at'] = Variable<DateTime>(finishedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookStatsCompanion(')
          ..write('fingerprint: $fingerprint, ')
          ..write('readingMs: $readingMs, ')
          ..write('listeningMs: $listeningMs, ')
          ..write('sessions: $sessions, ')
          ..write('words: $words, ')
          ..write('pages: $pages, ')
          ..write('readerMs: $readerMs, ')
          ..write('readerWords: $readerWords, ')
          ..write('pageMs: $pageMs, ')
          ..write('pagePages: $pagePages, ')
          ..write('longestMs: $longestMs, ')
          ..write('medianPageMs: $medianPageMs, ')
          ..write('totalWords: $totalWords, ')
          ..write('wordsLeft: $wordsLeft, ')
          ..write('firstRead: $firstRead, ')
          ..write('lastRead: $lastRead, ')
          ..write('finishedAt: $finishedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookDaysTable extends BookDays with TableInfo<$BookDaysTable, BookDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _fingerprintMeta = const VerificationMeta('fingerprint');
  @override
  late final GeneratedColumn<String> fingerprint = GeneratedColumn<String>(
    'fingerprint',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<int> day = GeneratedColumn<int>(
    'day',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _msMeta = const VerificationMeta('ms');
  @override
  late final GeneratedColumn<int> ms = GeneratedColumn<int>(
    'ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [fingerprint, day, ms];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'book_days';
  @override
  VerificationContext validateIntegrity(Insertable<BookDay> instance, {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('fingerprint')) {
      context.handle(_fingerprintMeta, fingerprint.isAcceptableOrUnknown(data['fingerprint']!, _fingerprintMeta));
    } else if (isInserting) {
      context.missing(_fingerprintMeta);
    }
    if (data.containsKey('day')) {
      context.handle(_dayMeta, day.isAcceptableOrUnknown(data['day']!, _dayMeta));
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('ms')) {
      context.handle(_msMeta, ms.isAcceptableOrUnknown(data['ms']!, _msMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {fingerprint, day};
  @override
  BookDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookDay(
      fingerprint: attachedDatabase.typeMapping.read(DriftSqlType.string, data['${effectivePrefix}fingerprint'])!,
      day: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}day'])!,
      ms: attachedDatabase.typeMapping.read(DriftSqlType.int, data['${effectivePrefix}ms'])!,
    );
  }

  @override
  $BookDaysTable createAlias(String alias) {
    return $BookDaysTable(attachedDatabase, alias);
  }
}

class BookDay extends DataClass implements Insertable<BookDay> {
  final String fingerprint;
  final int day;
  final int ms;
  const BookDay({required this.fingerprint, required this.day, required this.ms});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['fingerprint'] = Variable<String>(fingerprint);
    map['day'] = Variable<int>(day);
    map['ms'] = Variable<int>(ms);
    return map;
  }

  BookDaysCompanion toCompanion(bool nullToAbsent) {
    return BookDaysCompanion(fingerprint: Value(fingerprint), day: Value(day), ms: Value(ms));
  }

  factory BookDay.fromJson(Map<String, dynamic> json, {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookDay(
      fingerprint: serializer.fromJson<String>(json['fingerprint']),
      day: serializer.fromJson<int>(json['day']),
      ms: serializer.fromJson<int>(json['ms']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'fingerprint': serializer.toJson<String>(fingerprint),
      'day': serializer.toJson<int>(day),
      'ms': serializer.toJson<int>(ms),
    };
  }

  BookDay copyWith({String? fingerprint, int? day, int? ms}) =>
      BookDay(fingerprint: fingerprint ?? this.fingerprint, day: day ?? this.day, ms: ms ?? this.ms);
  BookDay copyWithCompanion(BookDaysCompanion data) {
    return BookDay(
      fingerprint: data.fingerprint.present ? data.fingerprint.value : this.fingerprint,
      day: data.day.present ? data.day.value : this.day,
      ms: data.ms.present ? data.ms.value : this.ms,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookDay(')
          ..write('fingerprint: $fingerprint, ')
          ..write('day: $day, ')
          ..write('ms: $ms')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(fingerprint, day, ms);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookDay && other.fingerprint == this.fingerprint && other.day == this.day && other.ms == this.ms);
}

class BookDaysCompanion extends UpdateCompanion<BookDay> {
  final Value<String> fingerprint;
  final Value<int> day;
  final Value<int> ms;
  final Value<int> rowid;
  const BookDaysCompanion({
    this.fingerprint = const Value.absent(),
    this.day = const Value.absent(),
    this.ms = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookDaysCompanion.insert({
    required String fingerprint,
    required int day,
    this.ms = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : fingerprint = Value(fingerprint),
       day = Value(day);
  static Insertable<BookDay> custom({
    Expression<String>? fingerprint,
    Expression<int>? day,
    Expression<int>? ms,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (fingerprint != null) 'fingerprint': fingerprint,
      if (day != null) 'day': day,
      if (ms != null) 'ms': ms,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookDaysCompanion copyWith({Value<String>? fingerprint, Value<int>? day, Value<int>? ms, Value<int>? rowid}) {
    return BookDaysCompanion(
      fingerprint: fingerprint ?? this.fingerprint,
      day: day ?? this.day,
      ms: ms ?? this.ms,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (fingerprint.present) {
      map['fingerprint'] = Variable<String>(fingerprint.value);
    }
    if (day.present) {
      map['day'] = Variable<int>(day.value);
    }
    if (ms.present) {
      map['ms'] = Variable<int>(ms.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookDaysCompanion(')
          ..write('fingerprint: $fingerprint, ')
          ..write('day: $day, ')
          ..write('ms: $ms, ')
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
  late final $PlacesTable places = $PlacesTable(this);
  late final $ReadingSessionsTable readingSessions = $ReadingSessionsTable(this);
  late final $DailyStatsTable dailyStats = $DailyStatsTable(this);
  late final $BookStatsTable bookStats = $BookStatsTable(this);
  late final $BookDaysTable bookDays = $BookDaysTable(this);
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
  late final Index sessionsDoc = Index('sessions_doc', 'CREATE INDEX sessions_doc ON reading_sessions (fingerprint)');
  late final Index sessionsOpen = Index('sessions_open', 'CREATE INDEX sessions_open ON reading_sessions (open)');
  late final Index bookStatsTime = Index('book_stats_time', 'CREATE INDEX book_stats_time ON book_stats (reading_ms)');
  @override
  Iterable<TableInfo<Table, Object?>> get allTables => allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    folders,
    entries,
    documents,
    annotations,
    recents,
    places,
    readingSessions,
    dailyStats,
    bookStats,
    bookDays,
    entriesParent,
    entriesExt,
    entriesFp,
    annotationsDoc,
    sessionsDoc,
    sessionsOpen,
    bookStatsTime,
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
  Value<String> source,
});
typedef $$FoldersTableUpdateCompanionBuilder = FoldersCompanion Function({
  Value<int> id,
  Value<String> uri,
  Value<String> name,
  Value<String> path,
  Value<DateTime> addedAt,
  Value<DateTime?> scannedAt,
  Value<bool> accessLost,
  Value<String> source,
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

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get source => $composableBuilder(column: $table.source, builder: (column) => column);

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
                Value<String> source = const Value.absent(),
              }) => FoldersCompanion(
                id: id,
                uri: uri,
                name: name,
                path: path,
                addedAt: addedAt,
                scannedAt: scannedAt,
                accessLost: accessLost,
                source: source,
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
                Value<String> source = const Value.absent(),
              }) => FoldersCompanion.insert(
                id: id,
                uri: uri,
                name: name,
                path: path,
                addedAt: addedAt,
                scannedAt: scannedAt,
                accessLost: accessLost,
                source: source,
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
  Value<String?> issue,
  Value<int> enriched,
  Value<bool> hidden,
  Value<String> source,
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
  Value<String?> issue,
  Value<int> enriched,
  Value<bool> hidden,
  Value<String> source,
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

  ColumnFilters<String> get issue =>
      $composableBuilder(column: $table.issue, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get enriched =>
      $composableBuilder(column: $table.enriched, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnFilters(column));

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

  ColumnOrderings<String> get issue =>
      $composableBuilder(column: $table.issue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get enriched =>
      $composableBuilder(column: $table.enriched, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hidden =>
      $composableBuilder(column: $table.hidden, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => ColumnOrderings(column));

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

  GeneratedColumn<String> get issue => $composableBuilder(column: $table.issue, builder: (column) => column);

  GeneratedColumn<int> get enriched => $composableBuilder(column: $table.enriched, builder: (column) => column);

  GeneratedColumn<bool> get hidden => $composableBuilder(column: $table.hidden, builder: (column) => column);

  GeneratedColumn<String> get source => $composableBuilder(column: $table.source, builder: (column) => column);

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
                Value<String?> issue = const Value.absent(),
                Value<int> enriched = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String> source = const Value.absent(),
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
                issue: issue,
                enriched: enriched,
                hidden: hidden,
                source: source,
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
                Value<String?> issue = const Value.absent(),
                Value<int> enriched = const Value.absent(),
                Value<bool> hidden = const Value.absent(),
                Value<String> source = const Value.absent(),
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
                issue: issue,
                enriched: enriched,
                hidden: hidden,
                source: source,
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
  Value<String?> issue,
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
  Value<String?> issue,
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

  ColumnFilters<String> get issue =>
      $composableBuilder(column: $table.issue, builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<String> get issue =>
      $composableBuilder(column: $table.issue, builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<String> get issue => $composableBuilder(column: $table.issue, builder: (column) => column);
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
                Value<String?> issue = const Value.absent(),
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
                issue: issue,
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
                Value<String?> issue = const Value.absent(),
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
                issue: issue,
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
typedef $$PlacesTableCreateCompanionBuilder = PlacesCompanion Function({
  required String path,
  required String name,
  Value<bool> pinned,
  Value<DateTime?> visitedAt,
  Value<int> rowid,
});
typedef $$PlacesTableUpdateCompanionBuilder = PlacesCompanion Function({
  Value<String> path,
  Value<String> name,
  Value<bool> pinned,
  Value<DateTime?> visitedAt,
  Value<int> rowid,
});

class $$PlacesTableFilterComposer extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(column: $table.path, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get visitedAt =>
      $composableBuilder(column: $table.visitedAt, builder: (column) => ColumnFilters(column));
}

class $$PlacesTableOrderingComposer extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get visitedAt =>
      $composableBuilder(column: $table.visitedAt, builder: (column) => ColumnOrderings(column));
}

class $$PlacesTableAnnotationComposer extends Composer<_$AppDatabase, $PlacesTable> {
  $$PlacesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path => $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name => $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<bool> get pinned => $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<DateTime> get visitedAt => $composableBuilder(column: $table.visitedAt, builder: (column) => column);
}

class $$PlacesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PlacesTable,
          Place,
          $$PlacesTableFilterComposer,
          $$PlacesTableOrderingComposer,
          $$PlacesTableAnnotationComposer,
          $$PlacesTableCreateCompanionBuilder,
          $$PlacesTableUpdateCompanionBuilder,
          (Place, BaseReferences<_$AppDatabase, $PlacesTable, Place>),
          Place,
          PrefetchHooks Function()
        > {
  $$PlacesTableTableManager(_$AppDatabase db, $PlacesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$PlacesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$PlacesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$PlacesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> path = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<bool> pinned = const Value.absent(),
            Value<DateTime?> visitedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PlacesCompanion(path: path, name: name, pinned: pinned, visitedAt: visitedAt, rowid: rowid),
          createCompanionCallback: ({
            required String path,
            required String name,
            Value<bool> pinned = const Value.absent(),
            Value<DateTime?> visitedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => PlacesCompanion.insert(path: path, name: name, pinned: pinned, visitedAt: visitedAt, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$PlacesTable, Place>(table),
                  BaseReferences<_$AppDatabase, $PlacesTable, Place>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PlacesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PlacesTable,
      Place,
      $$PlacesTableFilterComposer,
      $$PlacesTableOrderingComposer,
      $$PlacesTableAnnotationComposer,
      $$PlacesTableCreateCompanionBuilder,
      $$PlacesTableUpdateCompanionBuilder,
      (Place, BaseReferences<_$AppDatabase, $PlacesTable, Place>),
      Place,
      PrefetchHooks Function()
    >;
typedef $$ReadingSessionsTableCreateCompanionBuilder = ReadingSessionsCompanion Function({
  Value<int> id,
  required String fingerprint,
  required String format,
  required String mode,
  required DateTime startedAt,
  required DateTime endedAt,
  required int day,
  Value<int> hour,
  Value<int> activeMs,
  Value<int> listeningMs,
  Value<String?> fromLocator,
  Value<String?> toLocator,
  Value<int> words,
  Value<int> pages,
  Value<bool> open,
});
typedef $$ReadingSessionsTableUpdateCompanionBuilder = ReadingSessionsCompanion Function({
  Value<int> id,
  Value<String> fingerprint,
  Value<String> format,
  Value<String> mode,
  Value<DateTime> startedAt,
  Value<DateTime> endedAt,
  Value<int> day,
  Value<int> hour,
  Value<int> activeMs,
  Value<int> listeningMs,
  Value<String?> fromLocator,
  Value<String?> toLocator,
  Value<int> words,
  Value<int> pages,
  Value<bool> open,
});

class $$ReadingSessionsTableFilterComposer extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get day => $composableBuilder(column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get hour => $composableBuilder(column: $table.hour, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get activeMs =>
      $composableBuilder(column: $table.activeMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get listeningMs =>
      $composableBuilder(column: $table.listeningMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get fromLocator =>
      $composableBuilder(column: $table.fromLocator, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get toLocator =>
      $composableBuilder(column: $table.toLocator, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get words => $composableBuilder(column: $table.words, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pages => $composableBuilder(column: $table.pages, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get open => $composableBuilder(column: $table.open, builder: (column) => ColumnFilters(column));
}

class $$ReadingSessionsTableOrderingComposer extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get format =>
      $composableBuilder(column: $table.format, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get day => $composableBuilder(column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get hour =>
      $composableBuilder(column: $table.hour, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get activeMs =>
      $composableBuilder(column: $table.activeMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get listeningMs =>
      $composableBuilder(column: $table.listeningMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get fromLocator =>
      $composableBuilder(column: $table.fromLocator, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get toLocator =>
      $composableBuilder(column: $table.toLocator, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get words =>
      $composableBuilder(column: $table.words, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pages =>
      $composableBuilder(column: $table.pages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get open =>
      $composableBuilder(column: $table.open, builder: (column) => ColumnOrderings(column));
}

class $$ReadingSessionsTableAnnotationComposer extends Composer<_$AppDatabase, $ReadingSessionsTable> {
  $$ReadingSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id => $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => column);

  GeneratedColumn<String> get format => $composableBuilder(column: $table.format, builder: (column) => column);

  GeneratedColumn<String> get mode => $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<DateTime> get startedAt => $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt => $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<int> get day => $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get hour => $composableBuilder(column: $table.hour, builder: (column) => column);

  GeneratedColumn<int> get activeMs => $composableBuilder(column: $table.activeMs, builder: (column) => column);

  GeneratedColumn<int> get listeningMs => $composableBuilder(column: $table.listeningMs, builder: (column) => column);

  GeneratedColumn<String> get fromLocator =>
      $composableBuilder(column: $table.fromLocator, builder: (column) => column);

  GeneratedColumn<String> get toLocator => $composableBuilder(column: $table.toLocator, builder: (column) => column);

  GeneratedColumn<int> get words => $composableBuilder(column: $table.words, builder: (column) => column);

  GeneratedColumn<int> get pages => $composableBuilder(column: $table.pages, builder: (column) => column);

  GeneratedColumn<bool> get open => $composableBuilder(column: $table.open, builder: (column) => column);
}

class $$ReadingSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReadingSessionsTable,
          ReadingSession,
          $$ReadingSessionsTableFilterComposer,
          $$ReadingSessionsTableOrderingComposer,
          $$ReadingSessionsTableAnnotationComposer,
          $$ReadingSessionsTableCreateCompanionBuilder,
          $$ReadingSessionsTableUpdateCompanionBuilder,
          (ReadingSession, BaseReferences<_$AppDatabase, $ReadingSessionsTable, ReadingSession>),
          ReadingSession,
          PrefetchHooks Function()
        > {
  $$ReadingSessionsTableTableManager(_$AppDatabase db, $ReadingSessionsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$ReadingSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$ReadingSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$ReadingSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> fingerprint = const Value.absent(),
                Value<String> format = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime> endedAt = const Value.absent(),
                Value<int> day = const Value.absent(),
                Value<int> hour = const Value.absent(),
                Value<int> activeMs = const Value.absent(),
                Value<int> listeningMs = const Value.absent(),
                Value<String?> fromLocator = const Value.absent(),
                Value<String?> toLocator = const Value.absent(),
                Value<int> words = const Value.absent(),
                Value<int> pages = const Value.absent(),
                Value<bool> open = const Value.absent(),
              }) => ReadingSessionsCompanion(
                id: id,
                fingerprint: fingerprint,
                format: format,
                mode: mode,
                startedAt: startedAt,
                endedAt: endedAt,
                day: day,
                hour: hour,
                activeMs: activeMs,
                listeningMs: listeningMs,
                fromLocator: fromLocator,
                toLocator: toLocator,
                words: words,
                pages: pages,
                open: open,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String fingerprint,
                required String format,
                required String mode,
                required DateTime startedAt,
                required DateTime endedAt,
                required int day,
                Value<int> hour = const Value.absent(),
                Value<int> activeMs = const Value.absent(),
                Value<int> listeningMs = const Value.absent(),
                Value<String?> fromLocator = const Value.absent(),
                Value<String?> toLocator = const Value.absent(),
                Value<int> words = const Value.absent(),
                Value<int> pages = const Value.absent(),
                Value<bool> open = const Value.absent(),
              }) => ReadingSessionsCompanion.insert(
                id: id,
                fingerprint: fingerprint,
                format: format,
                mode: mode,
                startedAt: startedAt,
                endedAt: endedAt,
                day: day,
                hour: hour,
                activeMs: activeMs,
                listeningMs: listeningMs,
                fromLocator: fromLocator,
                toLocator: toLocator,
                words: words,
                pages: pages,
                open: open,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReadingSessionsTable, ReadingSession>(table),
                  BaseReferences<_$AppDatabase, $ReadingSessionsTable, ReadingSession>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReadingSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReadingSessionsTable,
      ReadingSession,
      $$ReadingSessionsTableFilterComposer,
      $$ReadingSessionsTableOrderingComposer,
      $$ReadingSessionsTableAnnotationComposer,
      $$ReadingSessionsTableCreateCompanionBuilder,
      $$ReadingSessionsTableUpdateCompanionBuilder,
      (ReadingSession, BaseReferences<_$AppDatabase, $ReadingSessionsTable, ReadingSession>),
      ReadingSession,
      PrefetchHooks Function()
    >;
typedef $$DailyStatsTableCreateCompanionBuilder = DailyStatsCompanion Function({
  Value<int> day,
  Value<int> readingMs,
  Value<int> listeningMs,
  Value<int> words,
  Value<int> pages,
  Value<int> sessions,
  Value<int> readerMs,
  Value<int> readerWords,
  Value<int> pageMs,
  Value<int> pagePages,
  Value<int> longestMs,
  Value<String?> longestFp,
  Value<String> formatMs,
  Value<String> hourMs,
});
typedef $$DailyStatsTableUpdateCompanionBuilder = DailyStatsCompanion Function({
  Value<int> day,
  Value<int> readingMs,
  Value<int> listeningMs,
  Value<int> words,
  Value<int> pages,
  Value<int> sessions,
  Value<int> readerMs,
  Value<int> readerWords,
  Value<int> pageMs,
  Value<int> pagePages,
  Value<int> longestMs,
  Value<String?> longestFp,
  Value<String> formatMs,
  Value<String> hourMs,
});

class $$DailyStatsTableFilterComposer extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get day => $composableBuilder(column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readingMs =>
      $composableBuilder(column: $table.readingMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get listeningMs =>
      $composableBuilder(column: $table.listeningMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get words => $composableBuilder(column: $table.words, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pages => $composableBuilder(column: $table.pages, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sessions =>
      $composableBuilder(column: $table.sessions, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readerMs =>
      $composableBuilder(column: $table.readerMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readerWords =>
      $composableBuilder(column: $table.readerWords, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageMs =>
      $composableBuilder(column: $table.pageMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pagePages =>
      $composableBuilder(column: $table.pagePages, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get longestMs =>
      $composableBuilder(column: $table.longestMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get longestFp =>
      $composableBuilder(column: $table.longestFp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get formatMs =>
      $composableBuilder(column: $table.formatMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hourMs =>
      $composableBuilder(column: $table.hourMs, builder: (column) => ColumnFilters(column));
}

class $$DailyStatsTableOrderingComposer extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get day => $composableBuilder(column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readingMs =>
      $composableBuilder(column: $table.readingMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get listeningMs =>
      $composableBuilder(column: $table.listeningMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get words =>
      $composableBuilder(column: $table.words, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pages =>
      $composableBuilder(column: $table.pages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sessions =>
      $composableBuilder(column: $table.sessions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readerMs =>
      $composableBuilder(column: $table.readerMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readerWords =>
      $composableBuilder(column: $table.readerWords, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageMs =>
      $composableBuilder(column: $table.pageMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pagePages =>
      $composableBuilder(column: $table.pagePages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get longestMs =>
      $composableBuilder(column: $table.longestMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get longestFp =>
      $composableBuilder(column: $table.longestFp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get formatMs =>
      $composableBuilder(column: $table.formatMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hourMs =>
      $composableBuilder(column: $table.hourMs, builder: (column) => ColumnOrderings(column));
}

class $$DailyStatsTableAnnotationComposer extends Composer<_$AppDatabase, $DailyStatsTable> {
  $$DailyStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get day => $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get readingMs => $composableBuilder(column: $table.readingMs, builder: (column) => column);

  GeneratedColumn<int> get listeningMs => $composableBuilder(column: $table.listeningMs, builder: (column) => column);

  GeneratedColumn<int> get words => $composableBuilder(column: $table.words, builder: (column) => column);

  GeneratedColumn<int> get pages => $composableBuilder(column: $table.pages, builder: (column) => column);

  GeneratedColumn<int> get sessions => $composableBuilder(column: $table.sessions, builder: (column) => column);

  GeneratedColumn<int> get readerMs => $composableBuilder(column: $table.readerMs, builder: (column) => column);

  GeneratedColumn<int> get readerWords => $composableBuilder(column: $table.readerWords, builder: (column) => column);

  GeneratedColumn<int> get pageMs => $composableBuilder(column: $table.pageMs, builder: (column) => column);

  GeneratedColumn<int> get pagePages => $composableBuilder(column: $table.pagePages, builder: (column) => column);

  GeneratedColumn<int> get longestMs => $composableBuilder(column: $table.longestMs, builder: (column) => column);

  GeneratedColumn<String> get longestFp => $composableBuilder(column: $table.longestFp, builder: (column) => column);

  GeneratedColumn<String> get formatMs => $composableBuilder(column: $table.formatMs, builder: (column) => column);

  GeneratedColumn<String> get hourMs => $composableBuilder(column: $table.hourMs, builder: (column) => column);
}

class $$DailyStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyStatsTable,
          DailyStat,
          $$DailyStatsTableFilterComposer,
          $$DailyStatsTableOrderingComposer,
          $$DailyStatsTableAnnotationComposer,
          $$DailyStatsTableCreateCompanionBuilder,
          $$DailyStatsTableUpdateCompanionBuilder,
          (DailyStat, BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStat>),
          DailyStat,
          PrefetchHooks Function()
        > {
  $$DailyStatsTableTableManager(_$AppDatabase db, $DailyStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$DailyStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$DailyStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$DailyStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> day = const Value.absent(),
                Value<int> readingMs = const Value.absent(),
                Value<int> listeningMs = const Value.absent(),
                Value<int> words = const Value.absent(),
                Value<int> pages = const Value.absent(),
                Value<int> sessions = const Value.absent(),
                Value<int> readerMs = const Value.absent(),
                Value<int> readerWords = const Value.absent(),
                Value<int> pageMs = const Value.absent(),
                Value<int> pagePages = const Value.absent(),
                Value<int> longestMs = const Value.absent(),
                Value<String?> longestFp = const Value.absent(),
                Value<String> formatMs = const Value.absent(),
                Value<String> hourMs = const Value.absent(),
              }) => DailyStatsCompanion(
                day: day,
                readingMs: readingMs,
                listeningMs: listeningMs,
                words: words,
                pages: pages,
                sessions: sessions,
                readerMs: readerMs,
                readerWords: readerWords,
                pageMs: pageMs,
                pagePages: pagePages,
                longestMs: longestMs,
                longestFp: longestFp,
                formatMs: formatMs,
                hourMs: hourMs,
              ),
          createCompanionCallback:
              ({
                Value<int> day = const Value.absent(),
                Value<int> readingMs = const Value.absent(),
                Value<int> listeningMs = const Value.absent(),
                Value<int> words = const Value.absent(),
                Value<int> pages = const Value.absent(),
                Value<int> sessions = const Value.absent(),
                Value<int> readerMs = const Value.absent(),
                Value<int> readerWords = const Value.absent(),
                Value<int> pageMs = const Value.absent(),
                Value<int> pagePages = const Value.absent(),
                Value<int> longestMs = const Value.absent(),
                Value<String?> longestFp = const Value.absent(),
                Value<String> formatMs = const Value.absent(),
                Value<String> hourMs = const Value.absent(),
              }) => DailyStatsCompanion.insert(
                day: day,
                readingMs: readingMs,
                listeningMs: listeningMs,
                words: words,
                pages: pages,
                sessions: sessions,
                readerMs: readerMs,
                readerWords: readerWords,
                pageMs: pageMs,
                pagePages: pagePages,
                longestMs: longestMs,
                longestFp: longestFp,
                formatMs: formatMs,
                hourMs: hourMs,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DailyStatsTable, DailyStat>(table),
                  BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStat>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyStatsTable,
      DailyStat,
      $$DailyStatsTableFilterComposer,
      $$DailyStatsTableOrderingComposer,
      $$DailyStatsTableAnnotationComposer,
      $$DailyStatsTableCreateCompanionBuilder,
      $$DailyStatsTableUpdateCompanionBuilder,
      (DailyStat, BaseReferences<_$AppDatabase, $DailyStatsTable, DailyStat>),
      DailyStat,
      PrefetchHooks Function()
    >;
typedef $$BookStatsTableCreateCompanionBuilder = BookStatsCompanion Function({
  required String fingerprint,
  Value<int> readingMs,
  Value<int> listeningMs,
  Value<int> sessions,
  Value<int> words,
  Value<int> pages,
  Value<int> readerMs,
  Value<int> readerWords,
  Value<int> pageMs,
  Value<int> pagePages,
  Value<int> longestMs,
  Value<int> medianPageMs,
  Value<int?> totalWords,
  Value<int?> wordsLeft,
  Value<DateTime?> firstRead,
  Value<DateTime?> lastRead,
  Value<DateTime?> finishedAt,
  Value<int> rowid,
});
typedef $$BookStatsTableUpdateCompanionBuilder = BookStatsCompanion Function({
  Value<String> fingerprint,
  Value<int> readingMs,
  Value<int> listeningMs,
  Value<int> sessions,
  Value<int> words,
  Value<int> pages,
  Value<int> readerMs,
  Value<int> readerWords,
  Value<int> pageMs,
  Value<int> pagePages,
  Value<int> longestMs,
  Value<int> medianPageMs,
  Value<int?> totalWords,
  Value<int?> wordsLeft,
  Value<DateTime?> firstRead,
  Value<DateTime?> lastRead,
  Value<DateTime?> finishedAt,
  Value<int> rowid,
});

class $$BookStatsTableFilterComposer extends Composer<_$AppDatabase, $BookStatsTable> {
  $$BookStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readingMs =>
      $composableBuilder(column: $table.readingMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get listeningMs =>
      $composableBuilder(column: $table.listeningMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sessions =>
      $composableBuilder(column: $table.sessions, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get words => $composableBuilder(column: $table.words, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pages => $composableBuilder(column: $table.pages, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readerMs =>
      $composableBuilder(column: $table.readerMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get readerWords =>
      $composableBuilder(column: $table.readerWords, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pageMs =>
      $composableBuilder(column: $table.pageMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get pagePages =>
      $composableBuilder(column: $table.pagePages, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get longestMs =>
      $composableBuilder(column: $table.longestMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get medianPageMs =>
      $composableBuilder(column: $table.medianPageMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalWords =>
      $composableBuilder(column: $table.totalWords, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get wordsLeft =>
      $composableBuilder(column: $table.wordsLeft, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get firstRead =>
      $composableBuilder(column: $table.firstRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastRead =>
      $composableBuilder(column: $table.lastRead, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get finishedAt =>
      $composableBuilder(column: $table.finishedAt, builder: (column) => ColumnFilters(column));
}

class $$BookStatsTableOrderingComposer extends Composer<_$AppDatabase, $BookStatsTable> {
  $$BookStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readingMs =>
      $composableBuilder(column: $table.readingMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get listeningMs =>
      $composableBuilder(column: $table.listeningMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sessions =>
      $composableBuilder(column: $table.sessions, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get words =>
      $composableBuilder(column: $table.words, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pages =>
      $composableBuilder(column: $table.pages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readerMs =>
      $composableBuilder(column: $table.readerMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get readerWords =>
      $composableBuilder(column: $table.readerWords, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pageMs =>
      $composableBuilder(column: $table.pageMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get pagePages =>
      $composableBuilder(column: $table.pagePages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get longestMs =>
      $composableBuilder(column: $table.longestMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get medianPageMs =>
      $composableBuilder(column: $table.medianPageMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalWords =>
      $composableBuilder(column: $table.totalWords, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get wordsLeft =>
      $composableBuilder(column: $table.wordsLeft, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get firstRead =>
      $composableBuilder(column: $table.firstRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastRead =>
      $composableBuilder(column: $table.lastRead, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get finishedAt =>
      $composableBuilder(column: $table.finishedAt, builder: (column) => ColumnOrderings(column));
}

class $$BookStatsTableAnnotationComposer extends Composer<_$AppDatabase, $BookStatsTable> {
  $$BookStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => column);

  GeneratedColumn<int> get readingMs => $composableBuilder(column: $table.readingMs, builder: (column) => column);

  GeneratedColumn<int> get listeningMs => $composableBuilder(column: $table.listeningMs, builder: (column) => column);

  GeneratedColumn<int> get sessions => $composableBuilder(column: $table.sessions, builder: (column) => column);

  GeneratedColumn<int> get words => $composableBuilder(column: $table.words, builder: (column) => column);

  GeneratedColumn<int> get pages => $composableBuilder(column: $table.pages, builder: (column) => column);

  GeneratedColumn<int> get readerMs => $composableBuilder(column: $table.readerMs, builder: (column) => column);

  GeneratedColumn<int> get readerWords => $composableBuilder(column: $table.readerWords, builder: (column) => column);

  GeneratedColumn<int> get pageMs => $composableBuilder(column: $table.pageMs, builder: (column) => column);

  GeneratedColumn<int> get pagePages => $composableBuilder(column: $table.pagePages, builder: (column) => column);

  GeneratedColumn<int> get longestMs => $composableBuilder(column: $table.longestMs, builder: (column) => column);

  GeneratedColumn<int> get medianPageMs => $composableBuilder(column: $table.medianPageMs, builder: (column) => column);

  GeneratedColumn<int> get totalWords => $composableBuilder(column: $table.totalWords, builder: (column) => column);

  GeneratedColumn<int> get wordsLeft => $composableBuilder(column: $table.wordsLeft, builder: (column) => column);

  GeneratedColumn<DateTime> get firstRead => $composableBuilder(column: $table.firstRead, builder: (column) => column);

  GeneratedColumn<DateTime> get lastRead => $composableBuilder(column: $table.lastRead, builder: (column) => column);

  GeneratedColumn<DateTime> get finishedAt =>
      $composableBuilder(column: $table.finishedAt, builder: (column) => column);
}

class $$BookStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookStatsTable,
          BookStat,
          $$BookStatsTableFilterComposer,
          $$BookStatsTableOrderingComposer,
          $$BookStatsTableAnnotationComposer,
          $$BookStatsTableCreateCompanionBuilder,
          $$BookStatsTableUpdateCompanionBuilder,
          (BookStat, BaseReferences<_$AppDatabase, $BookStatsTable, BookStat>),
          BookStat,
          PrefetchHooks Function()
        > {
  $$BookStatsTableTableManager(_$AppDatabase db, $BookStatsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$BookStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$BookStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$BookStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> fingerprint = const Value.absent(),
                Value<int> readingMs = const Value.absent(),
                Value<int> listeningMs = const Value.absent(),
                Value<int> sessions = const Value.absent(),
                Value<int> words = const Value.absent(),
                Value<int> pages = const Value.absent(),
                Value<int> readerMs = const Value.absent(),
                Value<int> readerWords = const Value.absent(),
                Value<int> pageMs = const Value.absent(),
                Value<int> pagePages = const Value.absent(),
                Value<int> longestMs = const Value.absent(),
                Value<int> medianPageMs = const Value.absent(),
                Value<int?> totalWords = const Value.absent(),
                Value<int?> wordsLeft = const Value.absent(),
                Value<DateTime?> firstRead = const Value.absent(),
                Value<DateTime?> lastRead = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookStatsCompanion(
                fingerprint: fingerprint,
                readingMs: readingMs,
                listeningMs: listeningMs,
                sessions: sessions,
                words: words,
                pages: pages,
                readerMs: readerMs,
                readerWords: readerWords,
                pageMs: pageMs,
                pagePages: pagePages,
                longestMs: longestMs,
                medianPageMs: medianPageMs,
                totalWords: totalWords,
                wordsLeft: wordsLeft,
                firstRead: firstRead,
                lastRead: lastRead,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String fingerprint,
                Value<int> readingMs = const Value.absent(),
                Value<int> listeningMs = const Value.absent(),
                Value<int> sessions = const Value.absent(),
                Value<int> words = const Value.absent(),
                Value<int> pages = const Value.absent(),
                Value<int> readerMs = const Value.absent(),
                Value<int> readerWords = const Value.absent(),
                Value<int> pageMs = const Value.absent(),
                Value<int> pagePages = const Value.absent(),
                Value<int> longestMs = const Value.absent(),
                Value<int> medianPageMs = const Value.absent(),
                Value<int?> totalWords = const Value.absent(),
                Value<int?> wordsLeft = const Value.absent(),
                Value<DateTime?> firstRead = const Value.absent(),
                Value<DateTime?> lastRead = const Value.absent(),
                Value<DateTime?> finishedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookStatsCompanion.insert(
                fingerprint: fingerprint,
                readingMs: readingMs,
                listeningMs: listeningMs,
                sessions: sessions,
                words: words,
                pages: pages,
                readerMs: readerMs,
                readerWords: readerWords,
                pageMs: pageMs,
                pagePages: pagePages,
                longestMs: longestMs,
                medianPageMs: medianPageMs,
                totalWords: totalWords,
                wordsLeft: wordsLeft,
                firstRead: firstRead,
                lastRead: lastRead,
                finishedAt: finishedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookStatsTable, BookStat>(table),
                  BaseReferences<_$AppDatabase, $BookStatsTable, BookStat>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookStatsTable,
      BookStat,
      $$BookStatsTableFilterComposer,
      $$BookStatsTableOrderingComposer,
      $$BookStatsTableAnnotationComposer,
      $$BookStatsTableCreateCompanionBuilder,
      $$BookStatsTableUpdateCompanionBuilder,
      (BookStat, BaseReferences<_$AppDatabase, $BookStatsTable, BookStat>),
      BookStat,
      PrefetchHooks Function()
    >;
typedef $$BookDaysTableCreateCompanionBuilder = BookDaysCompanion Function({
  required String fingerprint,
  required int day,
  Value<int> ms,
  Value<int> rowid,
});
typedef $$BookDaysTableUpdateCompanionBuilder = BookDaysCompanion Function({
  Value<String> fingerprint,
  Value<int> day,
  Value<int> ms,
  Value<int> rowid,
});

class $$BookDaysTableFilterComposer extends Composer<_$AppDatabase, $BookDaysTable> {
  $$BookDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get day => $composableBuilder(column: $table.day, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get ms => $composableBuilder(column: $table.ms, builder: (column) => ColumnFilters(column));
}

class $$BookDaysTableOrderingComposer extends Composer<_$AppDatabase, $BookDaysTable> {
  $$BookDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get day => $composableBuilder(column: $table.day, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get ms => $composableBuilder(column: $table.ms, builder: (column) => ColumnOrderings(column));
}

class $$BookDaysTableAnnotationComposer extends Composer<_$AppDatabase, $BookDaysTable> {
  $$BookDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get fingerprint =>
      $composableBuilder(column: $table.fingerprint, builder: (column) => column);

  GeneratedColumn<int> get day => $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<int> get ms => $composableBuilder(column: $table.ms, builder: (column) => column);
}

class $$BookDaysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $BookDaysTable,
          BookDay,
          $$BookDaysTableFilterComposer,
          $$BookDaysTableOrderingComposer,
          $$BookDaysTableAnnotationComposer,
          $$BookDaysTableCreateCompanionBuilder,
          $$BookDaysTableUpdateCompanionBuilder,
          (BookDay, BaseReferences<_$AppDatabase, $BookDaysTable, BookDay>),
          BookDay,
          PrefetchHooks Function()
        > {
  $$BookDaysTableTableManager(_$AppDatabase db, $BookDaysTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () => $$BookDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () => $$BookDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () => $$BookDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> fingerprint = const Value.absent(),
            Value<int> day = const Value.absent(),
            Value<int> ms = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => BookDaysCompanion(fingerprint: fingerprint, day: day, ms: ms, rowid: rowid),
          createCompanionCallback: ({
            required String fingerprint,
            required int day,
            Value<int> ms = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) => BookDaysCompanion.insert(fingerprint: fingerprint, day: day, ms: ms, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$BookDaysTable, BookDay>(table),
                  BaseReferences<_$AppDatabase, $BookDaysTable, BookDay>(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookDaysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $BookDaysTable,
      BookDay,
      $$BookDaysTableFilterComposer,
      $$BookDaysTableOrderingComposer,
      $$BookDaysTableAnnotationComposer,
      $$BookDaysTableCreateCompanionBuilder,
      $$BookDaysTableUpdateCompanionBuilder,
      (BookDay, BaseReferences<_$AppDatabase, $BookDaysTable, BookDay>),
      BookDay,
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
  $$PlacesTableTableManager get places => $$PlacesTableTableManager(_db, _db.places);
  $$ReadingSessionsTableTableManager get readingSessions =>
      $$ReadingSessionsTableTableManager(_db, _db.readingSessions);
  $$DailyStatsTableTableManager get dailyStats => $$DailyStatsTableTableManager(_db, _db.dailyStats);
  $$BookStatsTableTableManager get bookStats => $$BookStatsTableTableManager(_db, _db.bookStats);
  $$BookDaysTableTableManager get bookDays => $$BookDaysTableTableManager(_db, _db.bookDays);
}
