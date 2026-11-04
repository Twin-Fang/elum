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

/// 보호자 목소리 받기·파일 캐시: 서버 확인(If-None-Match) > 304 캐시 / 200 저장 / 404 캐시 삭제 / 실패 시 캐시
///
/// 재생할 때마다 서버에 확인 — 녹음한 보호자의 Pro 가 끝나면 서버가 404 를 줘 기본 음성으로 넘어감.
/// 위치 `{앱 지원 폴더}/card_images/guardian-voice/{열쇠 해시}.m4a` (로그아웃·탈퇴 때 그림 캐시와 함께 지움).
/// **절대 throw 하지 않음** — 실패하면 null, 호출부는 기본 음성으로 넘어감.
class GuardianVoiceRepository {
  GuardianVoiceRepository({
    required Dio dio,
    required CardImageDiskCache imageCache,
    required Future<Directory> Function() rootProvider,
    this.maxBytes = defaultMaxBytes,
    this.checkTimeout = defaultCheckTimeout,
  })  : _dio = dio,
        _imageCache = imageCache,
        _rootProvider = rootProvider;

  /// 녹음 캐시 전체 상한 (30MB, 15초 녹음 1건 약 120KB). 넘으면 오래 안 쓴 것부터 삭제
  static const defaultMaxBytes = 30 * 1024 * 1024;

  /// 서버 확인·받기 대기 상한. 넘기면 가진 캐시 또는 기본 음성 (누르고 오래 기다리지 않게)
  static const defaultCheckTimeout = Duration(seconds: 4);

  static const _voiceDirectoryName = 'guardian-voice';
  static const _voiceExtension = '.m4a';
  static const _partialFileSuffix = '.tmp';

  final Dio _dio;
  final CardImageDiskCache _imageCache;
  final Future<Directory> Function() _rootProvider;
  final int maxBytes;
  final Duration checkTimeout;

  /// 진행 중인 확인 by 열쇠 (연타해도 요청은 1번)
  final Map<String, Future<File?>> _inFlight = {};

  /// 재생할 녹음 파일. 서버가 없다고 하면(404) 캐시를 지우고 null
  Future<File?> fileFor({
    required String routineId,
    required String stepId,
    required String voiceKey,
  }) {
    return _inFlight[voiceKey] ??= _load(routineId, stepId, voiceKey)
        .whenComplete(() => _inFlight.remove(voiceKey));
  }

  Future<File?> _load(String routineId, String stepId, String voiceKey) async {
    try {
      // 받는 중 로그아웃(캐시 삭제)이 있었는지 확인용 표식
      final generation = _imageCache.generation;
      final file = await _fileOf(voiceKey);
      if (file == null) return null;
      final cached = await _isUsableFile(file) ? file : null;

      final Response<List<int>> response;
      try {
        // receiveTimeout 은 무응답 시간이라 조금씩 오는 응답을 못 끊음 > 전체 시간으로 제한
        response = await _dio
            .get<List<int>>(
              '/api/routines/$routineId/steps/$stepId/voice',
              options: Options(
                responseType: ResponseType.bytes,
                receiveTimeout: checkTimeout,
                headers: {if (cached != null) 'If-None-Match': '"$voiceKey"'},
                // 304 = 가진 것과 같음, 404 = 없음·재생 불가 (정상 흐름이라 예외로 받지 않음)
                validateStatus: (status) =>
                    status == 200 || status == 304 || status == 404,
              ),
            )
            .timeout(checkTimeout);
      } catch (e) {
        // 망이 없음 > 가진 녹음이 있으면 그대로 (오프라인에서도 익숙한 목소리)
        AppLogger.error('guardian-voice', '녹음 확인 실패 → 캐시 또는 기본 음성: $e');
        return cached;
      }

      switch (response.statusCode) {
        case 304:
          return cached == null ? null : await _touch(cached);
        case 404:
          // 녹음이 지워졌거나 Pro 가 끝남 > 이 기기에 남은 사본도 버림
          if (cached != null) await _tryDelete(cached);
          return null;
      }
      final bytes = Uint8List.fromList(response.data ?? const []);
      if (!looksLikeM4a(bytes)) {
        AppLogger.error('guardian-voice', '녹음 응답이 올바르지 않아 버림 (${bytes.length}B)');
        return cached;
      }
      if (generation != _imageCache.generation) return null;
      final saved = await _save(file, bytes);
      // 저장하는 사이 로그아웃이 있었으면 방금 쓴 파일도 지움 (다른 계정에 남지 않게)
      if (saved != null && generation != _imageCache.generation) {
        await _tryDelete(saved);
        return null;
      }
      return saved;
    } catch (e) {
      AppLogger.error('guardian-voice', '녹음 준비 실패 → 기본 음성: $e');
      return null;
    }
  }

  Future<bool> _isUsableFile(File file) async {
    if (!await file.exists()) return false;
    final handle = await file.open();
    try {
      if (looksLikeM4a(await handle.read(8))) return true;
    } finally {
      await handle.close();
    }
    // 쓰다 끊긴 파일 > 지우고 다시 받음
    await _tryDelete(file);
    return false;
  }

  /// 수정 시각 = 마지막 사용 (용량 정리 기준)
  Future<File> _touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
    } catch (_) {
      // 시각 갱신 실패는 정리 순서만 바뀜
    }
    return file;
  }

  /// 저장: 임시 파일 > 이름 바꾸기 > 용량 정리
  Future<File?> _save(File file, Uint8List bytes) async {
    final partialFile = File('${file.path}$_partialFileSuffix');
    try {
      await file.parent.create(recursive: true);
      await partialFile.writeAsBytes(bytes, flush: true);
      await partialFile.rename(file.path);
    } catch (e) {
      AppLogger.error('guardian-voice', '녹음 저장 실패: $e');
      await _tryDelete(partialFile);
      return null;
    }
    await _prune();
    return file;
  }

  /// 상한 초과 시 오래 안 쓴 것부터 삭제 (다시 녹음해 안 쓰는 옛 열쇠도 결국 여기서 빠짐)
  Future<void> _prune() async {
    try {
      final root = await _voiceRoot();
      if (root == null || !await root.exists()) return;
      final entries = <({File file, int size, DateTime usedAt})>[];
      await for (final entity in root.list(followLinks: false)) {
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
      AppLogger.error('guardian-voice', '용량 정리 실패(무시): $e');
    }
  }

  Future<Directory?> _voiceRoot() async {
    try {
      final root = await _rootProvider();
      final separator = Platform.pathSeparator;
      return Directory(
        '${root.path}$separator${CardImageDiskCache.directoryName}$separator$_voiceDirectoryName',
      );
    } catch (e) {
      AppLogger.error('guardian-voice', '저장 폴더를 찾지 못함 → 캐시 없이 동작: $e');
      return null;
    }
  }

  /// 파일 이름 = 열쇠 SHA-256 (경로 문자가 폴더 밖으로 새지 않게)
  Future<File?> _fileOf(String voiceKey) async {
    final root = await _voiceRoot();
    if (root == null) return null;
    final hash = await Sha256().hash(utf8.encode(voiceKey));
    final name = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return File('${root.path}${Platform.pathSeparator}$name$_voiceExtension');
  }

  Future<bool> _tryDelete(File file) async {
    try {
      if (await file.exists()) await file.delete();
      return true;
    } catch (e) {
      AppLogger.error('guardian-voice', '파일 삭제 실패: $e');
      return false;
    }
  }

  /// MP4 머리 `....ftyp` 확인 (HTML 오류 페이지 등을 걸러냄)
  @visibleForTesting
  static bool looksLikeM4a(Uint8List bytes) =>
      bytes.length >= 8 &&
      bytes[4] == 0x66 &&
      bytes[5] == 0x74 &&
      bytes[6] == 0x79 &&
      bytes[7] == 0x70;
}

final guardianVoiceRepositoryProvider = Provider<GuardianVoiceRepository>(
  (ref) => GuardianVoiceRepository(
    dio: ref.watch(dioProvider),
    imageCache: ref.watch(cardImageDiskCacheProvider),
    rootProvider: getApplicationSupportDirectory,
  ),
);
