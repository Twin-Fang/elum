import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../app/dio_provider.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/storage/card_image_disk_cache.dart';
import '../../../shared/models/action_card.dart';

/// 미리 만든 단계 음성 한 건의 위치: 일과, 단계, 음성 열쇠(서버 `speechPath`, 없으면 null)
typedef StoredSpeechSource = ({String routineId, String stepId, String? speechPath});

/// 단계 음성 받기·파일 캐시 (#675): 캐시 확인 > 받기 > 검증 > 저장 > 같은 단계 옛 파일 삭제
///
/// 위치 `{앱 지원 폴더}/card_images/speech/{stepId 해시}/{열쇠 해시}.wav`
/// 카드 그림 캐시 폴더 아래라 로그아웃·탈퇴·세션 만료 때 [CardImageDiskCache.clear] 가 함께 지움.
/// **절대 throw 하지 않음** — 실패하면 null, 호출부는 기기 음성으로 넘어감.
class CardSpeechRepository {
  CardSpeechRepository({
    required Dio dio,
    required CardImageDiskCache imageCache,
    required Future<Directory> Function() rootProvider,
    this.maxBytes = defaultMaxBytes,
    this.downloadTimeout = defaultDownloadTimeout,
  })  : _dio = dio,
        _imageCache = imageCache,
        _rootProvider = rootProvider;

  /// 음성 캐시 전체 상한 (60MB, 실측 25자 문장 1건 약 387KB). 넘으면 오래 안 쓴 것부터 삭제
  static const defaultMaxBytes = 60 * 1024 * 1024;

  /// 받기 대기 상한. 넘기면 기기 음성으로 넘어감 (누르고 오래 기다리지 않게)
  static const defaultDownloadTimeout = Duration(seconds: 8);

  static const _speechDirectoryName = 'speech';
  static const _speechExtension = '.wav';
  static const _tmpSuffix = '.tmp';

  // 서버 ETag = 음성 열쇠. 가진 열쇠를 If-None-Match 로 보내 같으면 304 (다시 받지 않음)
  static const _etagHeader = 'etag';

  final Dio _dio;
  final CardImageDiskCache _imageCache;
  final Future<Directory> Function() _rootProvider;
  final int maxBytes;
  final Duration downloadTimeout;

  /// 진행 중인 받기 by 단계·열쇠 (연타해도 받기는 1번)
  final Map<String, Future<File?>> _inFlight = {};

  /// 마지막으로 받은 열쇠 by stepId. 목록에 열쇠가 아직 없는 카드(방금 만든 일과)의 304 확인용
  final Map<String, String> _knownKeyByStepId = {};

  /// 재생할 파일. 캐시 > 받기 순, 실패하면 null
  Future<File?> fileFor(StoredSpeechSource source) {
    final inFlightKey = '${source.stepId}|${source.speechPath ?? ''}';
    return _inFlight[inFlightKey] ??= _load(source).whenComplete(() {
      _inFlight.remove(inFlightKey);
    });
  }

  /// 일과 진입 시 정리·미리 받기: 열쇠 없는 카드 > 옛 음성 삭제, 나머지 > 차례로 받기 (동시 1건)
  Future<void> syncRoutine(String routineId, List<ActionCard> cards) async {
    for (final card in cards) {
      try {
        final speechPath = card.speechPath;
        if (speechPath == null) {
          // 글을 고쳐 서버가 다시 만드는 중 > 옛 문장 음성은 버림
          await _deleteStepDirectory(card.id);
          continue;
        }
        await fileFor((routineId: routineId, stepId: card.id, speechPath: speechPath));
      } catch (e) {
        AppLogger.error('speech-cache', '미리 받기 실패(무시): $e');
      }
    }
  }

  /// 열쇠를 알면 캐시 > 없으면 받기. 열쇠를 모르면 서버에 확인 (가진 열쇠와 같으면 304)
  Future<File?> _load(StoredSpeechSource source) async {
    try {
      // 받는 중 로그아웃(캐시 삭제)이 있었는지 확인용 표식
      final generation = _imageCache.generation;
      final speechPath = source.speechPath;

      // 목록이 열쇠를 알려 줌 > 캐시 그대로 (요청 없음)
      if (speechPath != null) {
        final cached = await _cachedFile(source.stepId, speechPath);
        if (cached != null) return cached;
      }

      // 서버 확인: 열쇠를 모르면 마지막으로 받은 열쇠로 304 확인 (고친 글의 옛 음성이 나오지 않게)
      final knownKey = speechPath ?? _knownKeyByStepId[source.stepId];
      final knownFile = knownKey == null ? null : await _cachedFile(source.stepId, knownKey);
      final result = await _download(source, knownFile == null ? null : knownKey);
      switch (result) {
        case _SpeechNotModified():
          return knownFile;
        case _SpeechMissing():
          // 서버에 지금 음성이 없음 (글 수정 후 다시 만드는 중 등) > 옛 음성 버림
          _knownKeyByStepId.remove(source.stepId);
          await _deleteStepDirectory(source.stepId);
          return null;
        case _SpeechFailed():
          return null;
        case _SpeechDownloaded(:final speechKey, :final bytes):
          if (generation != _imageCache.generation) return null;
          final saved = await _save(source.stepId, speechKey, bytes);
          // 저장하는 사이 로그아웃(캐시 삭제)이 있었으면 방금 쓴 파일도 지움 (다른 계정에 남지 않게)
          if (saved != null && generation != _imageCache.generation) {
            await _tryDelete(saved);
            return null;
          }
          if (saved != null) _knownKeyByStepId[source.stepId] = speechKey;
          return saved;
      }
    } catch (e) {
      AppLogger.error('speech-cache', '음성 준비 실패 → 기기 음성: $e');
      return null;
    }
  }

  Future<File?> _cachedFile(String stepId, String speechPath) async {
    final file = await _fileOf(stepId, speechPath);
    if (file == null || !await file.exists()) return null;
    final header = await _readHeader(file);
    if (!looksLikeWav(header)) {
      // 쓰다 끊긴 파일 > 지우고 다시 받음
      await _tryDelete(file);
      return null;
    }
    try {
      // 수정 시각 = 마지막 사용 (용량 정리 기준)
      await file.setLastModified(DateTime.now());
    } catch (_) {
      // 시각 갱신 실패는 정리 순서만 바뀜
    }
    return file;
  }

  /// 받기. [knownKey] 가 있으면 If-None-Match 로 보내 같으면 304
  Future<_SpeechFetchResult> _download(StoredSpeechSource source, String? knownKey) async {
    try {
      // receiveTimeout 은 무응답 시간이라 조금씩 오는 응답을 못 끊음 > 전체 시간으로 제한
      final response = await _dio.get<List<int>>(
        '/api/routines/${source.routineId}/steps/${source.stepId}/speech',
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: downloadTimeout,
          headers: {if (knownKey != null) 'If-None-Match': '"$knownKey"'},
          // 304 = 가진 것과 같음, 404 = 아직 없음 (정상 흐름이라 예외로 받지 않음)
          validateStatus: (status) => status == 200 || status == 304 || status == 404,
        ),
      ).timeout(downloadTimeout);
      if (response.statusCode == 304) return const _SpeechNotModified();
      if (response.statusCode == 404) return const _SpeechMissing();
      final bytes = Uint8List.fromList(response.data ?? const []);
      final speechKey = _keyFromEtag(response.headers.value(_etagHeader)) ?? source.speechPath;
      if (speechKey == null || speechKey.isEmpty || !looksLikeWav(bytes)) {
        AppLogger.error('speech-cache', '음성 응답이 올바르지 않아 버림 (${bytes.length}B)');
        return const _SpeechFailed();
      }
      return _SpeechDownloaded(speechKey: speechKey, bytes: bytes);
    } catch (e) {
      AppLogger.error('speech-cache', '음성 받기 실패 → 기기 음성: $e');
      return const _SpeechFailed();
    }
  }

  /// ETag `"s-1/abcd.wav"` (약한 `W/` 포함) > 열쇠
  static String? _keyFromEtag(String? etag) {
    if (etag == null) return null;
    final value = etag.startsWith('W/') ? etag.substring(2) : etag;
    return value.replaceAll('"', '');
  }

  /// 저장: 임시 파일 > 이름 바꾸기 > 같은 단계 옛 파일 삭제 > 용량 정리
  Future<File?> _save(String stepId, String speechKey, Uint8List bytes) async {
    final file = await _fileOf(stepId, speechKey);
    if (file == null) return null;
    final tmp = File('${file.path}$_tmpSuffix');
    try {
      await file.parent.create(recursive: true);
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
    } catch (e) {
      AppLogger.error('speech-cache', '음성 저장 실패: $e');
      await _tryDelete(tmp);
      return null;
    }
    await _deleteOtherFiles(file);
    await _prune();
    return file;
  }

  /// 글을 고쳐 열쇠가 바뀌면 옛 문장 음성 삭제
  Future<void> _deleteOtherFiles(File keep) async {
    try {
      await for (final entity in keep.parent.list(followLinks: false)) {
        if (entity is File && entity.path != keep.path) await _tryDelete(entity);
      }
    } catch (e) {
      AppLogger.error('speech-cache', '옛 음성 정리 실패(무시): $e');
    }
  }

  Future<void> _deleteStepDirectory(String stepId) async {
    final dir = await _stepDirectory(stepId);
    if (dir == null || !await dir.exists()) return;
    try {
      await dir.delete(recursive: true);
    } catch (e) {
      AppLogger.error('speech-cache', '단계 음성 삭제 실패: $e');
    }
  }

  /// 상한 초과 시 오래 안 쓴 것부터 삭제 (지워진 카드의 음성도 결국 여기서 빠짐)
  Future<void> _prune() async {
    try {
      final root = await _speechRoot();
      if (root == null || !await root.exists()) return;
      final entries = <({File file, int size, DateTime usedAt})>[];
      await for (final entity in root.list(recursive: true, followLinks: false)) {
        if (entity is! File) continue;
        final stat = await entity.stat();
        entries.add((file: entity, size: stat.size, usedAt: stat.modified));
      }
      entries.sort((a, b) => a.usedAt.compareTo(b.usedAt));
      var totalBytes = entries.fold<int>(0, (sum, e) => sum + e.size);
      for (final entry in entries) {
        if (totalBytes <= maxBytes) break;
        if (await _tryDelete(entry.file)) totalBytes -= entry.size;
      }
    } catch (e) {
      AppLogger.error('speech-cache', '용량 정리 실패(무시): $e');
    }
  }

  Future<Directory?> _speechRoot() async {
    try {
      final root = await _rootProvider();
      final separator = Platform.pathSeparator;
      return Directory(
        '${root.path}$separator${CardImageDiskCache.directoryName}$separator$_speechDirectoryName',
      );
    } catch (e) {
      AppLogger.error('speech-cache', '저장 폴더를 찾지 못함 → 캐시 없이 동작: $e');
      return null;
    }
  }

  /// 폴더·파일 이름 = SHA-256 (경로 문자가 폴더 밖으로 새지 않게)
  Future<Directory?> _stepDirectory(String stepId) async {
    final root = await _speechRoot();
    if (root == null) return null;
    return Directory('${root.path}${Platform.pathSeparator}${await _hashOf(stepId)}');
  }

  Future<File?> _fileOf(String stepId, String speechKey) async {
    final dir = await _stepDirectory(stepId);
    if (dir == null) return null;
    return File('${dir.path}${Platform.pathSeparator}${await _hashOf(speechKey)}$_speechExtension');
  }

  static Future<String> _hashOf(String value) async {
    final hash = await Sha256().hash(utf8.encode(value));
    return hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  static Future<Uint8List> _readHeader(File file) async {
    final handle = await file.open();
    try {
      return await handle.read(12);
    } finally {
      await handle.close();
    }
  }

  Future<bool> _tryDelete(File file) async {
    try {
      if (await file.exists()) await file.delete();
      return true;
    } catch (e) {
      AppLogger.error('speech-cache', '파일 삭제 실패: $e');
      return false;
    }
  }

  /// WAV 머리 `RIFF....WAVE` 확인 (HTML 오류 페이지 등을 걸러냄)
  @visibleForTesting
  static bool looksLikeWav(Uint8List bytes) =>
      bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x41 &&
      bytes[10] == 0x56 &&
      bytes[11] == 0x45;
}

/// 받기 결과 4가지: 받음, 같음(304), 없음(404), 실패
sealed class _SpeechFetchResult {
  const _SpeechFetchResult();
}

class _SpeechDownloaded extends _SpeechFetchResult {
  const _SpeechDownloaded({required this.speechKey, required this.bytes});

  final String speechKey;
  final Uint8List bytes;
}

class _SpeechNotModified extends _SpeechFetchResult {
  const _SpeechNotModified();
}

class _SpeechMissing extends _SpeechFetchResult {
  const _SpeechMissing();
}

class _SpeechFailed extends _SpeechFetchResult {
  const _SpeechFailed();
}

final cardSpeechRepositoryProvider = Provider<CardSpeechRepository>(
  (ref) => CardSpeechRepository(
    dio: ref.watch(dioProvider),
    imageCache: ref.watch(cardImageDiskCacheProvider),
    rootProvider: getApplicationSupportDirectory,
  ),
);
