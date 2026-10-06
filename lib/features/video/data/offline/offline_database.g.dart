// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_database.dart';

// ignore_for_file: type=lint
class $OfflineVideosTable extends OfflineVideos
    with TableInfo<$OfflineVideosTable, OfflineVideo> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineVideosTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _lessonIdMeta = const VerificationMeta(
    'lessonId',
  );
  @override
  late final GeneratedColumn<int> lessonId = GeneratedColumn<int>(
    'lesson_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _subjectNameMeta = const VerificationMeta(
    'subjectName',
  );
  @override
  late final GeneratedColumn<String> subjectName = GeneratedColumn<String>(
    'subject_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lessonTitleMeta = const VerificationMeta(
    'lessonTitle',
  );
  @override
  late final GeneratedColumn<String> lessonTitle = GeneratedColumn<String>(
    'lesson_title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _sourceUrlMeta = const VerificationMeta(
    'sourceUrl',
  );
  @override
  late final GeneratedColumn<String> sourceUrl = GeneratedColumn<String>(
    'source_url',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _localPathMeta = const VerificationMeta(
    'localPath',
  );
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
    'local_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _encryptedSizeMeta = const VerificationMeta(
    'encryptedSize',
  );
  @override
  late final GeneratedColumn<int> encryptedSize = GeneratedColumn<int>(
    'encrypted_size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _downloadStatusMeta = const VerificationMeta(
    'downloadStatus',
  );
  @override
  late final GeneratedColumn<String> downloadStatus = GeneratedColumn<String>(
    'download_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('queued'),
  );
  static const VerificationMeta _downloadProgressMeta = const VerificationMeta(
    'downloadProgress',
  );
  @override
  late final GeneratedColumn<double> downloadProgress = GeneratedColumn<double>(
    'download_progress',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _qualityMeta = const VerificationMeta(
    'quality',
  );
  @override
  late final GeneratedColumn<String> quality = GeneratedColumn<String>(
    'quality',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('720p'),
  );
  static const VerificationMeta _downloadedAtMeta = const VerificationMeta(
    'downloadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> downloadedAt = GeneratedColumn<DateTime>(
    'downloaded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<DateTime> expiresAt = GeneratedColumn<DateTime>(
    'expires_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _encryptionIvMeta = const VerificationMeta(
    'encryptionIv',
  );
  @override
  late final GeneratedColumn<String> encryptionIv = GeneratedColumn<String>(
    'encryption_iv',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _lastErrorMeta = const VerificationMeta(
    'lastError',
  );
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
    'last_error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pendingSyncPositionSecondsMeta =
      const VerificationMeta('pendingSyncPositionSeconds');
  @override
  late final GeneratedColumn<int> pendingSyncPositionSeconds =
      GeneratedColumn<int>(
        'pending_sync_position_seconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pendingSyncDurationSecondsMeta =
      const VerificationMeta('pendingSyncDurationSeconds');
  @override
  late final GeneratedColumn<int> pendingSyncDurationSeconds =
      GeneratedColumn<int>(
        'pending_sync_duration_seconds',
        aliasedName,
        true,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _pendingSyncProgressPercentageMeta =
      const VerificationMeta('pendingSyncProgressPercentage');
  @override
  late final GeneratedColumn<double> pendingSyncProgressPercentage =
      GeneratedColumn<double>(
        'pending_sync_progress_percentage',
        aliasedName,
        true,
        type: DriftSqlType.double,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    lessonId,
    subjectName,
    lessonTitle,
    sourceUrl,
    localPath,
    encryptedSize,
    downloadStatus,
    downloadProgress,
    quality,
    downloadedAt,
    expiresAt,
    encryptionIv,
    lastError,
    pendingSyncPositionSeconds,
    pendingSyncDurationSeconds,
    pendingSyncProgressPercentage,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_videos';
  @override
  VerificationContext validateIntegrity(
    Insertable<OfflineVideo> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('lesson_id')) {
      context.handle(
        _lessonIdMeta,
        lessonId.isAcceptableOrUnknown(data['lesson_id']!, _lessonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_lessonIdMeta);
    }
    if (data.containsKey('subject_name')) {
      context.handle(
        _subjectNameMeta,
        subjectName.isAcceptableOrUnknown(
          data['subject_name']!,
          _subjectNameMeta,
        ),
      );
    }
    if (data.containsKey('lesson_title')) {
      context.handle(
        _lessonTitleMeta,
        lessonTitle.isAcceptableOrUnknown(
          data['lesson_title']!,
          _lessonTitleMeta,
        ),
      );
    }
    if (data.containsKey('source_url')) {
      context.handle(
        _sourceUrlMeta,
        sourceUrl.isAcceptableOrUnknown(data['source_url']!, _sourceUrlMeta),
      );
    }
    if (data.containsKey('local_path')) {
      context.handle(
        _localPathMeta,
        localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta),
      );
    }
    if (data.containsKey('encrypted_size')) {
      context.handle(
        _encryptedSizeMeta,
        encryptedSize.isAcceptableOrUnknown(
          data['encrypted_size']!,
          _encryptedSizeMeta,
        ),
      );
    }
    if (data.containsKey('download_status')) {
      context.handle(
        _downloadStatusMeta,
        downloadStatus.isAcceptableOrUnknown(
          data['download_status']!,
          _downloadStatusMeta,
        ),
      );
    }
    if (data.containsKey('download_progress')) {
      context.handle(
        _downloadProgressMeta,
        downloadProgress.isAcceptableOrUnknown(
          data['download_progress']!,
          _downloadProgressMeta,
        ),
      );
    }
    if (data.containsKey('quality')) {
      context.handle(
        _qualityMeta,
        quality.isAcceptableOrUnknown(data['quality']!, _qualityMeta),
      );
    }
    if (data.containsKey('downloaded_at')) {
      context.handle(
        _downloadedAtMeta,
        downloadedAt.isAcceptableOrUnknown(
          data['downloaded_at']!,
          _downloadedAtMeta,
        ),
      );
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    }
    if (data.containsKey('encryption_iv')) {
      context.handle(
        _encryptionIvMeta,
        encryptionIv.isAcceptableOrUnknown(
          data['encryption_iv']!,
          _encryptionIvMeta,
        ),
      );
    }
    if (data.containsKey('last_error')) {
      context.handle(
        _lastErrorMeta,
        lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta),
      );
    }
    if (data.containsKey('pending_sync_position_seconds')) {
      context.handle(
        _pendingSyncPositionSecondsMeta,
        pendingSyncPositionSeconds.isAcceptableOrUnknown(
          data['pending_sync_position_seconds']!,
          _pendingSyncPositionSecondsMeta,
        ),
      );
    }
    if (data.containsKey('pending_sync_duration_seconds')) {
      context.handle(
        _pendingSyncDurationSecondsMeta,
        pendingSyncDurationSeconds.isAcceptableOrUnknown(
          data['pending_sync_duration_seconds']!,
          _pendingSyncDurationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('pending_sync_progress_percentage')) {
      context.handle(
        _pendingSyncProgressPercentageMeta,
        pendingSyncProgressPercentage.isAcceptableOrUnknown(
          data['pending_sync_progress_percentage']!,
          _pendingSyncProgressPercentageMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  OfflineVideo map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineVideo(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      lessonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}lesson_id'],
      )!,
      subjectName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_name'],
      )!,
      lessonTitle: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}lesson_title'],
      )!,
      sourceUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source_url'],
      )!,
      localPath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_path'],
      )!,
      encryptedSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}encrypted_size'],
      )!,
      downloadStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}download_status'],
      )!,
      downloadProgress: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}download_progress'],
      )!,
      quality: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}quality'],
      )!,
      downloadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}downloaded_at'],
      ),
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}expires_at'],
      ),
      encryptionIv: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}encryption_iv'],
      )!,
      lastError: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}last_error'],
      ),
      pendingSyncPositionSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_sync_position_seconds'],
      ),
      pendingSyncDurationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pending_sync_duration_seconds'],
      ),
      pendingSyncProgressPercentage: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}pending_sync_progress_percentage'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $OfflineVideosTable createAlias(String alias) {
    return $OfflineVideosTable(attachedDatabase, alias);
  }
}

class OfflineVideo extends DataClass implements Insertable<OfflineVideo> {
  final int id;
  final int lessonId;
  final String subjectName;
  final String lessonTitle;

  /// The lesson's own `video_url` (a YouTube link or a direct file URL) —
  /// what `OfflineDownloadManager` resolves into real bytes on every
  /// start/resume/retry (YouTube stream URLs expire, so it can't be stored).
  final String sourceUrl;

  /// Absolute path to the encrypted file in app-private storage.
  final String localPath;
  final int encryptedSize;

  /// queued | downloading | paused | completed | failed | cancelled | expired
  final String downloadStatus;

  /// 0-1.
  final double downloadProgress;
  final String quality;
  final DateTime? downloadedAt;

  /// The download's own validity window (subscription/enrollment-driven,
  /// not an HTTP cache expiry) — see `OfflineLicenseChecker`.
  final DateTime? expiresAt;
  final String encryptionIv;

  /// Set once a failed download's error is known, so the "المحمّلات" screen
  /// can show it next to "إعادة المحاولة" — cleared on retry.
  final String? lastError;

  /// Non-null exactly when offline playback has reported progress that
  /// hasn't reached the server yet — set instead of calling the network
  /// progress endpoints while there's no connection, and flushed (then
  /// cleared) by `OfflineLicenseChecker.syncPendingProgress` once it's back.
  final int? pendingSyncPositionSeconds;
  final int? pendingSyncDurationSeconds;
  final double? pendingSyncProgressPercentage;
  final DateTime createdAt;
  final DateTime updatedAt;
  const OfflineVideo({
    required this.id,
    required this.lessonId,
    required this.subjectName,
    required this.lessonTitle,
    required this.sourceUrl,
    required this.localPath,
    required this.encryptedSize,
    required this.downloadStatus,
    required this.downloadProgress,
    required this.quality,
    this.downloadedAt,
    this.expiresAt,
    required this.encryptionIv,
    this.lastError,
    this.pendingSyncPositionSeconds,
    this.pendingSyncDurationSeconds,
    this.pendingSyncProgressPercentage,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['lesson_id'] = Variable<int>(lessonId);
    map['subject_name'] = Variable<String>(subjectName);
    map['lesson_title'] = Variable<String>(lessonTitle);
    map['source_url'] = Variable<String>(sourceUrl);
    map['local_path'] = Variable<String>(localPath);
    map['encrypted_size'] = Variable<int>(encryptedSize);
    map['download_status'] = Variable<String>(downloadStatus);
    map['download_progress'] = Variable<double>(downloadProgress);
    map['quality'] = Variable<String>(quality);
    if (!nullToAbsent || downloadedAt != null) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt);
    }
    if (!nullToAbsent || expiresAt != null) {
      map['expires_at'] = Variable<DateTime>(expiresAt);
    }
    map['encryption_iv'] = Variable<String>(encryptionIv);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    if (!nullToAbsent || pendingSyncPositionSeconds != null) {
      map['pending_sync_position_seconds'] = Variable<int>(
        pendingSyncPositionSeconds,
      );
    }
    if (!nullToAbsent || pendingSyncDurationSeconds != null) {
      map['pending_sync_duration_seconds'] = Variable<int>(
        pendingSyncDurationSeconds,
      );
    }
    if (!nullToAbsent || pendingSyncProgressPercentage != null) {
      map['pending_sync_progress_percentage'] = Variable<double>(
        pendingSyncProgressPercentage,
      );
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  OfflineVideosCompanion toCompanion(bool nullToAbsent) {
    return OfflineVideosCompanion(
      id: Value(id),
      lessonId: Value(lessonId),
      subjectName: Value(subjectName),
      lessonTitle: Value(lessonTitle),
      sourceUrl: Value(sourceUrl),
      localPath: Value(localPath),
      encryptedSize: Value(encryptedSize),
      downloadStatus: Value(downloadStatus),
      downloadProgress: Value(downloadProgress),
      quality: Value(quality),
      downloadedAt: downloadedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(downloadedAt),
      expiresAt: expiresAt == null && nullToAbsent
          ? const Value.absent()
          : Value(expiresAt),
      encryptionIv: Value(encryptionIv),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      pendingSyncPositionSeconds:
          pendingSyncPositionSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingSyncPositionSeconds),
      pendingSyncDurationSeconds:
          pendingSyncDurationSeconds == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingSyncDurationSeconds),
      pendingSyncProgressPercentage:
          pendingSyncProgressPercentage == null && nullToAbsent
          ? const Value.absent()
          : Value(pendingSyncProgressPercentage),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory OfflineVideo.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineVideo(
      id: serializer.fromJson<int>(json['id']),
      lessonId: serializer.fromJson<int>(json['lessonId']),
      subjectName: serializer.fromJson<String>(json['subjectName']),
      lessonTitle: serializer.fromJson<String>(json['lessonTitle']),
      sourceUrl: serializer.fromJson<String>(json['sourceUrl']),
      localPath: serializer.fromJson<String>(json['localPath']),
      encryptedSize: serializer.fromJson<int>(json['encryptedSize']),
      downloadStatus: serializer.fromJson<String>(json['downloadStatus']),
      downloadProgress: serializer.fromJson<double>(json['downloadProgress']),
      quality: serializer.fromJson<String>(json['quality']),
      downloadedAt: serializer.fromJson<DateTime?>(json['downloadedAt']),
      expiresAt: serializer.fromJson<DateTime?>(json['expiresAt']),
      encryptionIv: serializer.fromJson<String>(json['encryptionIv']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      pendingSyncPositionSeconds: serializer.fromJson<int?>(
        json['pendingSyncPositionSeconds'],
      ),
      pendingSyncDurationSeconds: serializer.fromJson<int?>(
        json['pendingSyncDurationSeconds'],
      ),
      pendingSyncProgressPercentage: serializer.fromJson<double?>(
        json['pendingSyncProgressPercentage'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'lessonId': serializer.toJson<int>(lessonId),
      'subjectName': serializer.toJson<String>(subjectName),
      'lessonTitle': serializer.toJson<String>(lessonTitle),
      'sourceUrl': serializer.toJson<String>(sourceUrl),
      'localPath': serializer.toJson<String>(localPath),
      'encryptedSize': serializer.toJson<int>(encryptedSize),
      'downloadStatus': serializer.toJson<String>(downloadStatus),
      'downloadProgress': serializer.toJson<double>(downloadProgress),
      'quality': serializer.toJson<String>(quality),
      'downloadedAt': serializer.toJson<DateTime?>(downloadedAt),
      'expiresAt': serializer.toJson<DateTime?>(expiresAt),
      'encryptionIv': serializer.toJson<String>(encryptionIv),
      'lastError': serializer.toJson<String?>(lastError),
      'pendingSyncPositionSeconds': serializer.toJson<int?>(
        pendingSyncPositionSeconds,
      ),
      'pendingSyncDurationSeconds': serializer.toJson<int?>(
        pendingSyncDurationSeconds,
      ),
      'pendingSyncProgressPercentage': serializer.toJson<double?>(
        pendingSyncProgressPercentage,
      ),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  OfflineVideo copyWith({
    int? id,
    int? lessonId,
    String? subjectName,
    String? lessonTitle,
    String? sourceUrl,
    String? localPath,
    int? encryptedSize,
    String? downloadStatus,
    double? downloadProgress,
    String? quality,
    Value<DateTime?> downloadedAt = const Value.absent(),
    Value<DateTime?> expiresAt = const Value.absent(),
    String? encryptionIv,
    Value<String?> lastError = const Value.absent(),
    Value<int?> pendingSyncPositionSeconds = const Value.absent(),
    Value<int?> pendingSyncDurationSeconds = const Value.absent(),
    Value<double?> pendingSyncProgressPercentage = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => OfflineVideo(
    id: id ?? this.id,
    lessonId: lessonId ?? this.lessonId,
    subjectName: subjectName ?? this.subjectName,
    lessonTitle: lessonTitle ?? this.lessonTitle,
    sourceUrl: sourceUrl ?? this.sourceUrl,
    localPath: localPath ?? this.localPath,
    encryptedSize: encryptedSize ?? this.encryptedSize,
    downloadStatus: downloadStatus ?? this.downloadStatus,
    downloadProgress: downloadProgress ?? this.downloadProgress,
    quality: quality ?? this.quality,
    downloadedAt: downloadedAt.present ? downloadedAt.value : this.downloadedAt,
    expiresAt: expiresAt.present ? expiresAt.value : this.expiresAt,
    encryptionIv: encryptionIv ?? this.encryptionIv,
    lastError: lastError.present ? lastError.value : this.lastError,
    pendingSyncPositionSeconds: pendingSyncPositionSeconds.present
        ? pendingSyncPositionSeconds.value
        : this.pendingSyncPositionSeconds,
    pendingSyncDurationSeconds: pendingSyncDurationSeconds.present
        ? pendingSyncDurationSeconds.value
        : this.pendingSyncDurationSeconds,
    pendingSyncProgressPercentage: pendingSyncProgressPercentage.present
        ? pendingSyncProgressPercentage.value
        : this.pendingSyncProgressPercentage,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  OfflineVideo copyWithCompanion(OfflineVideosCompanion data) {
    return OfflineVideo(
      id: data.id.present ? data.id.value : this.id,
      lessonId: data.lessonId.present ? data.lessonId.value : this.lessonId,
      subjectName: data.subjectName.present
          ? data.subjectName.value
          : this.subjectName,
      lessonTitle: data.lessonTitle.present
          ? data.lessonTitle.value
          : this.lessonTitle,
      sourceUrl: data.sourceUrl.present ? data.sourceUrl.value : this.sourceUrl,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      encryptedSize: data.encryptedSize.present
          ? data.encryptedSize.value
          : this.encryptedSize,
      downloadStatus: data.downloadStatus.present
          ? data.downloadStatus.value
          : this.downloadStatus,
      downloadProgress: data.downloadProgress.present
          ? data.downloadProgress.value
          : this.downloadProgress,
      quality: data.quality.present ? data.quality.value : this.quality,
      downloadedAt: data.downloadedAt.present
          ? data.downloadedAt.value
          : this.downloadedAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      encryptionIv: data.encryptionIv.present
          ? data.encryptionIv.value
          : this.encryptionIv,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      pendingSyncPositionSeconds: data.pendingSyncPositionSeconds.present
          ? data.pendingSyncPositionSeconds.value
          : this.pendingSyncPositionSeconds,
      pendingSyncDurationSeconds: data.pendingSyncDurationSeconds.present
          ? data.pendingSyncDurationSeconds.value
          : this.pendingSyncDurationSeconds,
      pendingSyncProgressPercentage: data.pendingSyncProgressPercentage.present
          ? data.pendingSyncProgressPercentage.value
          : this.pendingSyncProgressPercentage,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineVideo(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('subjectName: $subjectName, ')
          ..write('lessonTitle: $lessonTitle, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('localPath: $localPath, ')
          ..write('encryptedSize: $encryptedSize, ')
          ..write('downloadStatus: $downloadStatus, ')
          ..write('downloadProgress: $downloadProgress, ')
          ..write('quality: $quality, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('encryptionIv: $encryptionIv, ')
          ..write('lastError: $lastError, ')
          ..write('pendingSyncPositionSeconds: $pendingSyncPositionSeconds, ')
          ..write('pendingSyncDurationSeconds: $pendingSyncDurationSeconds, ')
          ..write(
            'pendingSyncProgressPercentage: $pendingSyncProgressPercentage, ',
          )
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    lessonId,
    subjectName,
    lessonTitle,
    sourceUrl,
    localPath,
    encryptedSize,
    downloadStatus,
    downloadProgress,
    quality,
    downloadedAt,
    expiresAt,
    encryptionIv,
    lastError,
    pendingSyncPositionSeconds,
    pendingSyncDurationSeconds,
    pendingSyncProgressPercentage,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineVideo &&
          other.id == this.id &&
          other.lessonId == this.lessonId &&
          other.subjectName == this.subjectName &&
          other.lessonTitle == this.lessonTitle &&
          other.sourceUrl == this.sourceUrl &&
          other.localPath == this.localPath &&
          other.encryptedSize == this.encryptedSize &&
          other.downloadStatus == this.downloadStatus &&
          other.downloadProgress == this.downloadProgress &&
          other.quality == this.quality &&
          other.downloadedAt == this.downloadedAt &&
          other.expiresAt == this.expiresAt &&
          other.encryptionIv == this.encryptionIv &&
          other.lastError == this.lastError &&
          other.pendingSyncPositionSeconds == this.pendingSyncPositionSeconds &&
          other.pendingSyncDurationSeconds == this.pendingSyncDurationSeconds &&
          other.pendingSyncProgressPercentage ==
              this.pendingSyncProgressPercentage &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class OfflineVideosCompanion extends UpdateCompanion<OfflineVideo> {
  final Value<int> id;
  final Value<int> lessonId;
  final Value<String> subjectName;
  final Value<String> lessonTitle;
  final Value<String> sourceUrl;
  final Value<String> localPath;
  final Value<int> encryptedSize;
  final Value<String> downloadStatus;
  final Value<double> downloadProgress;
  final Value<String> quality;
  final Value<DateTime?> downloadedAt;
  final Value<DateTime?> expiresAt;
  final Value<String> encryptionIv;
  final Value<String?> lastError;
  final Value<int?> pendingSyncPositionSeconds;
  final Value<int?> pendingSyncDurationSeconds;
  final Value<double?> pendingSyncProgressPercentage;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const OfflineVideosCompanion({
    this.id = const Value.absent(),
    this.lessonId = const Value.absent(),
    this.subjectName = const Value.absent(),
    this.lessonTitle = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.encryptedSize = const Value.absent(),
    this.downloadStatus = const Value.absent(),
    this.downloadProgress = const Value.absent(),
    this.quality = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.encryptionIv = const Value.absent(),
    this.lastError = const Value.absent(),
    this.pendingSyncPositionSeconds = const Value.absent(),
    this.pendingSyncDurationSeconds = const Value.absent(),
    this.pendingSyncProgressPercentage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  OfflineVideosCompanion.insert({
    this.id = const Value.absent(),
    required int lessonId,
    this.subjectName = const Value.absent(),
    this.lessonTitle = const Value.absent(),
    this.sourceUrl = const Value.absent(),
    this.localPath = const Value.absent(),
    this.encryptedSize = const Value.absent(),
    this.downloadStatus = const Value.absent(),
    this.downloadProgress = const Value.absent(),
    this.quality = const Value.absent(),
    this.downloadedAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.encryptionIv = const Value.absent(),
    this.lastError = const Value.absent(),
    this.pendingSyncPositionSeconds = const Value.absent(),
    this.pendingSyncDurationSeconds = const Value.absent(),
    this.pendingSyncProgressPercentage = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : lessonId = Value(lessonId);
  static Insertable<OfflineVideo> custom({
    Expression<int>? id,
    Expression<int>? lessonId,
    Expression<String>? subjectName,
    Expression<String>? lessonTitle,
    Expression<String>? sourceUrl,
    Expression<String>? localPath,
    Expression<int>? encryptedSize,
    Expression<String>? downloadStatus,
    Expression<double>? downloadProgress,
    Expression<String>? quality,
    Expression<DateTime>? downloadedAt,
    Expression<DateTime>? expiresAt,
    Expression<String>? encryptionIv,
    Expression<String>? lastError,
    Expression<int>? pendingSyncPositionSeconds,
    Expression<int>? pendingSyncDurationSeconds,
    Expression<double>? pendingSyncProgressPercentage,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (lessonId != null) 'lesson_id': lessonId,
      if (subjectName != null) 'subject_name': subjectName,
      if (lessonTitle != null) 'lesson_title': lessonTitle,
      if (sourceUrl != null) 'source_url': sourceUrl,
      if (localPath != null) 'local_path': localPath,
      if (encryptedSize != null) 'encrypted_size': encryptedSize,
      if (downloadStatus != null) 'download_status': downloadStatus,
      if (downloadProgress != null) 'download_progress': downloadProgress,
      if (quality != null) 'quality': quality,
      if (downloadedAt != null) 'downloaded_at': downloadedAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (encryptionIv != null) 'encryption_iv': encryptionIv,
      if (lastError != null) 'last_error': lastError,
      if (pendingSyncPositionSeconds != null)
        'pending_sync_position_seconds': pendingSyncPositionSeconds,
      if (pendingSyncDurationSeconds != null)
        'pending_sync_duration_seconds': pendingSyncDurationSeconds,
      if (pendingSyncProgressPercentage != null)
        'pending_sync_progress_percentage': pendingSyncProgressPercentage,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  OfflineVideosCompanion copyWith({
    Value<int>? id,
    Value<int>? lessonId,
    Value<String>? subjectName,
    Value<String>? lessonTitle,
    Value<String>? sourceUrl,
    Value<String>? localPath,
    Value<int>? encryptedSize,
    Value<String>? downloadStatus,
    Value<double>? downloadProgress,
    Value<String>? quality,
    Value<DateTime?>? downloadedAt,
    Value<DateTime?>? expiresAt,
    Value<String>? encryptionIv,
    Value<String?>? lastError,
    Value<int?>? pendingSyncPositionSeconds,
    Value<int?>? pendingSyncDurationSeconds,
    Value<double?>? pendingSyncProgressPercentage,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return OfflineVideosCompanion(
      id: id ?? this.id,
      lessonId: lessonId ?? this.lessonId,
      subjectName: subjectName ?? this.subjectName,
      lessonTitle: lessonTitle ?? this.lessonTitle,
      sourceUrl: sourceUrl ?? this.sourceUrl,
      localPath: localPath ?? this.localPath,
      encryptedSize: encryptedSize ?? this.encryptedSize,
      downloadStatus: downloadStatus ?? this.downloadStatus,
      downloadProgress: downloadProgress ?? this.downloadProgress,
      quality: quality ?? this.quality,
      downloadedAt: downloadedAt ?? this.downloadedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      encryptionIv: encryptionIv ?? this.encryptionIv,
      lastError: lastError ?? this.lastError,
      pendingSyncPositionSeconds:
          pendingSyncPositionSeconds ?? this.pendingSyncPositionSeconds,
      pendingSyncDurationSeconds:
          pendingSyncDurationSeconds ?? this.pendingSyncDurationSeconds,
      pendingSyncProgressPercentage:
          pendingSyncProgressPercentage ?? this.pendingSyncProgressPercentage,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (lessonId.present) {
      map['lesson_id'] = Variable<int>(lessonId.value);
    }
    if (subjectName.present) {
      map['subject_name'] = Variable<String>(subjectName.value);
    }
    if (lessonTitle.present) {
      map['lesson_title'] = Variable<String>(lessonTitle.value);
    }
    if (sourceUrl.present) {
      map['source_url'] = Variable<String>(sourceUrl.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (encryptedSize.present) {
      map['encrypted_size'] = Variable<int>(encryptedSize.value);
    }
    if (downloadStatus.present) {
      map['download_status'] = Variable<String>(downloadStatus.value);
    }
    if (downloadProgress.present) {
      map['download_progress'] = Variable<double>(downloadProgress.value);
    }
    if (quality.present) {
      map['quality'] = Variable<String>(quality.value);
    }
    if (downloadedAt.present) {
      map['downloaded_at'] = Variable<DateTime>(downloadedAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<DateTime>(expiresAt.value);
    }
    if (encryptionIv.present) {
      map['encryption_iv'] = Variable<String>(encryptionIv.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (pendingSyncPositionSeconds.present) {
      map['pending_sync_position_seconds'] = Variable<int>(
        pendingSyncPositionSeconds.value,
      );
    }
    if (pendingSyncDurationSeconds.present) {
      map['pending_sync_duration_seconds'] = Variable<int>(
        pendingSyncDurationSeconds.value,
      );
    }
    if (pendingSyncProgressPercentage.present) {
      map['pending_sync_progress_percentage'] = Variable<double>(
        pendingSyncProgressPercentage.value,
      );
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineVideosCompanion(')
          ..write('id: $id, ')
          ..write('lessonId: $lessonId, ')
          ..write('subjectName: $subjectName, ')
          ..write('lessonTitle: $lessonTitle, ')
          ..write('sourceUrl: $sourceUrl, ')
          ..write('localPath: $localPath, ')
          ..write('encryptedSize: $encryptedSize, ')
          ..write('downloadStatus: $downloadStatus, ')
          ..write('downloadProgress: $downloadProgress, ')
          ..write('quality: $quality, ')
          ..write('downloadedAt: $downloadedAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('encryptionIv: $encryptionIv, ')
          ..write('lastError: $lastError, ')
          ..write('pendingSyncPositionSeconds: $pendingSyncPositionSeconds, ')
          ..write('pendingSyncDurationSeconds: $pendingSyncDurationSeconds, ')
          ..write(
            'pendingSyncProgressPercentage: $pendingSyncProgressPercentage, ',
          )
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$OfflineDatabase extends GeneratedDatabase {
  _$OfflineDatabase(QueryExecutor e) : super(e);
  $OfflineDatabaseManager get managers => $OfflineDatabaseManager(this);
  late final $OfflineVideosTable offlineVideos = $OfflineVideosTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [offlineVideos];
}

typedef $$OfflineVideosTableCreateCompanionBuilder =
    OfflineVideosCompanion Function({
      Value<int> id,
      required int lessonId,
      Value<String> subjectName,
      Value<String> lessonTitle,
      Value<String> sourceUrl,
      Value<String> localPath,
      Value<int> encryptedSize,
      Value<String> downloadStatus,
      Value<double> downloadProgress,
      Value<String> quality,
      Value<DateTime?> downloadedAt,
      Value<DateTime?> expiresAt,
      Value<String> encryptionIv,
      Value<String?> lastError,
      Value<int?> pendingSyncPositionSeconds,
      Value<int?> pendingSyncDurationSeconds,
      Value<double?> pendingSyncProgressPercentage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$OfflineVideosTableUpdateCompanionBuilder =
    OfflineVideosCompanion Function({
      Value<int> id,
      Value<int> lessonId,
      Value<String> subjectName,
      Value<String> lessonTitle,
      Value<String> sourceUrl,
      Value<String> localPath,
      Value<int> encryptedSize,
      Value<String> downloadStatus,
      Value<double> downloadProgress,
      Value<String> quality,
      Value<DateTime?> downloadedAt,
      Value<DateTime?> expiresAt,
      Value<String> encryptionIv,
      Value<String?> lastError,
      Value<int?> pendingSyncPositionSeconds,
      Value<int?> pendingSyncDurationSeconds,
      Value<double?> pendingSyncProgressPercentage,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$OfflineVideosTableFilterComposer
    extends Composer<_$OfflineDatabase, $OfflineVideosTable> {
  $$OfflineVideosTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lessonTitle => $composableBuilder(
    column: $table.lessonTitle,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get downloadProgress => $composableBuilder(
    column: $table.downloadProgress,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get encryptionIv => $composableBuilder(
    column: $table.encryptionIv,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pendingSyncPositionSeconds => $composableBuilder(
    column: $table.pendingSyncPositionSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pendingSyncDurationSeconds => $composableBuilder(
    column: $table.pendingSyncDurationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get pendingSyncProgressPercentage => $composableBuilder(
    column: $table.pendingSyncProgressPercentage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$OfflineVideosTableOrderingComposer
    extends Composer<_$OfflineDatabase, $OfflineVideosTable> {
  $$OfflineVideosTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lessonId => $composableBuilder(
    column: $table.lessonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lessonTitle => $composableBuilder(
    column: $table.lessonTitle,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get sourceUrl => $composableBuilder(
    column: $table.sourceUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get localPath => $composableBuilder(
    column: $table.localPath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get downloadProgress => $composableBuilder(
    column: $table.downloadProgress,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get quality => $composableBuilder(
    column: $table.quality,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get encryptionIv => $composableBuilder(
    column: $table.encryptionIv,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lastError => $composableBuilder(
    column: $table.lastError,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pendingSyncPositionSeconds => $composableBuilder(
    column: $table.pendingSyncPositionSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pendingSyncDurationSeconds => $composableBuilder(
    column: $table.pendingSyncDurationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get pendingSyncProgressPercentage =>
      $composableBuilder(
        column: $table.pendingSyncProgressPercentage,
        builder: (column) => ColumnOrderings(column),
      );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$OfflineVideosTableAnnotationComposer
    extends Composer<_$OfflineDatabase, $OfflineVideosTable> {
  $$OfflineVideosTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get lessonId =>
      $composableBuilder(column: $table.lessonId, builder: (column) => column);

  GeneratedColumn<String> get subjectName => $composableBuilder(
    column: $table.subjectName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lessonTitle => $composableBuilder(
    column: $table.lessonTitle,
    builder: (column) => column,
  );

  GeneratedColumn<String> get sourceUrl =>
      $composableBuilder(column: $table.sourceUrl, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<int> get encryptedSize => $composableBuilder(
    column: $table.encryptedSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get downloadStatus => $composableBuilder(
    column: $table.downloadStatus,
    builder: (column) => column,
  );

  GeneratedColumn<double> get downloadProgress => $composableBuilder(
    column: $table.downloadProgress,
    builder: (column) => column,
  );

  GeneratedColumn<String> get quality =>
      $composableBuilder(column: $table.quality, builder: (column) => column);

  GeneratedColumn<DateTime> get downloadedAt => $composableBuilder(
    column: $table.downloadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get encryptionIv => $composableBuilder(
    column: $table.encryptionIv,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<int> get pendingSyncPositionSeconds => $composableBuilder(
    column: $table.pendingSyncPositionSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<int> get pendingSyncDurationSeconds => $composableBuilder(
    column: $table.pendingSyncDurationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<double> get pendingSyncProgressPercentage =>
      $composableBuilder(
        column: $table.pendingSyncProgressPercentage,
        builder: (column) => column,
      );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$OfflineVideosTableTableManager
    extends
        RootTableManager<
          _$OfflineDatabase,
          $OfflineVideosTable,
          OfflineVideo,
          $$OfflineVideosTableFilterComposer,
          $$OfflineVideosTableOrderingComposer,
          $$OfflineVideosTableAnnotationComposer,
          $$OfflineVideosTableCreateCompanionBuilder,
          $$OfflineVideosTableUpdateCompanionBuilder,
          (
            OfflineVideo,
            BaseReferences<
              _$OfflineDatabase,
              $OfflineVideosTable,
              OfflineVideo
            >,
          ),
          OfflineVideo,
          PrefetchHooks Function()
        > {
  $$OfflineVideosTableTableManager(
    _$OfflineDatabase db,
    $OfflineVideosTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineVideosTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineVideosTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineVideosTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> lessonId = const Value.absent(),
                Value<String> subjectName = const Value.absent(),
                Value<String> lessonTitle = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> encryptedSize = const Value.absent(),
                Value<String> downloadStatus = const Value.absent(),
                Value<double> downloadProgress = const Value.absent(),
                Value<String> quality = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<String> encryptionIv = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> pendingSyncPositionSeconds = const Value.absent(),
                Value<int?> pendingSyncDurationSeconds = const Value.absent(),
                Value<double?> pendingSyncProgressPercentage =
                    const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => OfflineVideosCompanion(
                id: id,
                lessonId: lessonId,
                subjectName: subjectName,
                lessonTitle: lessonTitle,
                sourceUrl: sourceUrl,
                localPath: localPath,
                encryptedSize: encryptedSize,
                downloadStatus: downloadStatus,
                downloadProgress: downloadProgress,
                quality: quality,
                downloadedAt: downloadedAt,
                expiresAt: expiresAt,
                encryptionIv: encryptionIv,
                lastError: lastError,
                pendingSyncPositionSeconds: pendingSyncPositionSeconds,
                pendingSyncDurationSeconds: pendingSyncDurationSeconds,
                pendingSyncProgressPercentage: pendingSyncProgressPercentage,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int lessonId,
                Value<String> subjectName = const Value.absent(),
                Value<String> lessonTitle = const Value.absent(),
                Value<String> sourceUrl = const Value.absent(),
                Value<String> localPath = const Value.absent(),
                Value<int> encryptedSize = const Value.absent(),
                Value<String> downloadStatus = const Value.absent(),
                Value<double> downloadProgress = const Value.absent(),
                Value<String> quality = const Value.absent(),
                Value<DateTime?> downloadedAt = const Value.absent(),
                Value<DateTime?> expiresAt = const Value.absent(),
                Value<String> encryptionIv = const Value.absent(),
                Value<String?> lastError = const Value.absent(),
                Value<int?> pendingSyncPositionSeconds = const Value.absent(),
                Value<int?> pendingSyncDurationSeconds = const Value.absent(),
                Value<double?> pendingSyncProgressPercentage =
                    const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => OfflineVideosCompanion.insert(
                id: id,
                lessonId: lessonId,
                subjectName: subjectName,
                lessonTitle: lessonTitle,
                sourceUrl: sourceUrl,
                localPath: localPath,
                encryptedSize: encryptedSize,
                downloadStatus: downloadStatus,
                downloadProgress: downloadProgress,
                quality: quality,
                downloadedAt: downloadedAt,
                expiresAt: expiresAt,
                encryptionIv: encryptionIv,
                lastError: lastError,
                pendingSyncPositionSeconds: pendingSyncPositionSeconds,
                pendingSyncDurationSeconds: pendingSyncDurationSeconds,
                pendingSyncProgressPercentage: pendingSyncProgressPercentage,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$OfflineVideosTableProcessedTableManager =
    ProcessedTableManager<
      _$OfflineDatabase,
      $OfflineVideosTable,
      OfflineVideo,
      $$OfflineVideosTableFilterComposer,
      $$OfflineVideosTableOrderingComposer,
      $$OfflineVideosTableAnnotationComposer,
      $$OfflineVideosTableCreateCompanionBuilder,
      $$OfflineVideosTableUpdateCompanionBuilder,
      (
        OfflineVideo,
        BaseReferences<_$OfflineDatabase, $OfflineVideosTable, OfflineVideo>,
      ),
      OfflineVideo,
      PrefetchHooks Function()
    >;

class $OfflineDatabaseManager {
  final _$OfflineDatabase _db;
  $OfflineDatabaseManager(this._db);
  $$OfflineVideosTableTableManager get offlineVideos =>
      $$OfflineVideosTableTableManager(_db, _db.offlineVideos);
}
