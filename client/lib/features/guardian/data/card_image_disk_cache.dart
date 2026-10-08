import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/logger/app_logger.dart';

/// 카드 그림을 기기 저장소에 보관한다 (#462).
///
/// 메모리 캐시만 있으면 앱을 다시 켜거나 오프라인일 때 전에 본 그림도 사라진다.
/// 서버 `imagePath` 는 그림이 바뀔 때마다 새 열쇠라서, 이 값을 해시한 것을 파일 이름으로
/// 쓰면 옛 그림이 새 그림으로 잘못 보이는 일이 없다 (옛 파일은 용량 정리가 치운다).
///
/// 보호자가 올린 사진(#455)도 여기 남으므로 **로그아웃·탈퇴·세션 만료 때 [clear]** 로
/// 폴더째 지운다. OS 가 임의로 비우는 캐시 폴더가 아니라 앱 지원 폴더를 쓴다.
///
/// **절대 throw 하지 않는다.** 저장소가 막혀도(디스크 가득·권한) 그림은 네트워크로 계속
/// 보여야 한다. 실패는 AppLogger 로만 남기고 사진 내용·경로는 남기지 않는다.
class CardImageDiskCache {
  CardImageDiskCache({
    required Future<Directory> Function() rootProvider,
    this.maxBytes = defaultMaxBytes,
    this.maxFiles = defaultMaxFiles,
    this.maxEntryBytes = defaultMaxEntryBytes,
  }) : _rootProvider = rootProvider;

  static const defaultMaxBytes = 150 * 1024 * 1024;
  static const defaultMaxFiles = 500;

  /// 한 장 상한. 이보다 큰 응답은 화면엔 보여주되 디스크엔 두지 않는다 —
  /// 한 장이 상한을 통째로 차지해 나머지를 다 밀어내는 것을 막는다.
  static const defaultMaxEntryBytes = 20 * 1024 * 1024;

  static const _dirName = 'card_images';
  static const _tmpSuffix = '.tmp';

  final Future<Directory> Function() _rootProvider;
  final int maxBytes;
  final int maxFiles;
  final int maxEntryBytes;

  /// [clear] 때마다 오른다. 지우기 전에 시작한 다운로드가 뒤늦게 저장해 되살아나는 것을
  /// 막는 표식이다 — 로그아웃 뒤에 이전 계정의 사진이 남으면 안 된다.
  int _generation = 0;
  int get generation => _generation;

  /// 쓰기·정리·삭제를 한 줄로 세운다. 정리 중에 새 파일이 끼어 용량 계산이 어긋나는 것을 막는다.
  Future<void> _chain = Future<void>.value();

  Directory? _dirCache;

  Future<Directory?> _dir() async {
    final cached = _dirCache;
    if (cached != null) return cached;
    try {
      final root = await _rootProvider();
      return _dirCache = Directory('${root.path}${Platform.pathSeparator}$_dirName');
    } catch (e) {
      // 저장소 폴더를 못 찾으면 캐시 없이 동작한다(매번 다시 시도)
      AppLogger.error('card-cache', '저장 폴더를 찾지 못했다 → 디스크 캐시 없이 동작: $e');
      return null;
    }
  }

  /// 파일 이름 = imagePath 의 SHA-256. 경로 문자(`/`·`..`)가 폴더 밖으로 새지 않는다.
  Future<File?> _fileFor(String imagePath) async {
    final dir = await _dir();
    if (dir == null) return null;
    final hash = await Sha256().hash(utf8.encode(imagePath));
    final name = hash.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return File('${dir.path}${Platform.pathSeparator}$name');
  }

  /// 디스크에 있는 그림. 없거나 깨졌으면 null (깨진 파일은 지운다).
  Future<Uint8List?> read(String imagePath) async {
    try {
      final file = await _fileFor(imagePath);
      if (file == null || !await file.exists()) return null;

      final bytes = await file.readAsBytes();
      if (!looksLikeImage(bytes)) {
        // 반쯤 쓰다 끊겼거나 빈 파일이다 — 다시 받게 치운다
        AppLogger.error('card-cache', '깨진 캐시 파일을 버렸다 (${bytes.length}B)');
        await _tryDelete(file);
        return null;
      }
      try {
        // 별도 색인 없이 수정 시각을 "마지막 접근"으로 쓴다 (LRU)
        await file.setLastModified(DateTime.now());
      } catch (e) {
        AppLogger.error('card-cache', '접근 시각 갱신 실패(무시): $e');
      }
      return bytes;
    } catch (e) {
      AppLogger.error('card-cache', '읽기 실패 → 다시 받는다: $e');
      return null;
    }
  }

  /// 저장한다. 저장하지 못해도 호출부는 받은 바이트를 그대로 쓰므로 결과는 참고용이다.
  ///
  /// [generation] 은 다운로드를 시작할 때의 [generation] 이다. 그 사이 [clear] 가 있었으면
  /// 저장하지 않는다.
  Future<bool> write(String imagePath, Uint8List bytes, {int? generation}) {
    final run = _chain.then((_) => _write(imagePath, bytes, generation));
    _chain = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<bool> _write(String imagePath, Uint8List bytes, int? generation) async {
    if (generation != null && generation != _generation) return false;
    if (bytes.length > maxEntryBytes || !looksLikeImage(bytes)) return false;

    File? tmp;
    try {
      final file = await _fileFor(imagePath);
      if (file == null) return false;
      await file.parent.create(recursive: true);

      // 임시 파일에 다 쓴 뒤 rename — 도중에 끊겨도 온전한 파일만 읽힌다
      tmp = File('${file.path}$_tmpSuffix');
      await tmp.writeAsBytes(bytes, flush: true);
      await tmp.rename(file.path);
      tmp = null;
    } catch (e) {
      // 디스크 가득·권한 오류. 그림은 화면에 이미 간다
      AppLogger.error('card-cache', '저장 실패 → 메모리로만 보여준다: $e');
      if (tmp != null) await _tryDelete(tmp);
      return false;
    }
    await _prune();
    return true;
  }

  /// 상한을 넘으면 마지막 접근이 오래된 것부터 지운다.
  Future<void> _prune() async {
    try {
      final dir = await _dir();
      if (dir == null || !await dir.exists()) return;

      final entries = <({File file, int size, DateTime at})>[];
      await for (final e in dir.list(followLinks: false)) {
        if (e is! File) continue;
        // 쓰기는 한 줄로 서 있으므로 남은 .tmp 는 이전 실행이 남긴 찌꺼기다
        if (e.path.endsWith(_tmpSuffix)) {
          await _tryDelete(e);
          continue;
        }
        final stat = await e.stat();
        entries.add((file: e, size: stat.size, at: stat.modified));
      }

      entries.sort((a, b) {
        final byTime = a.at.compareTo(b.at);
        return byTime != 0 ? byTime : a.file.path.compareTo(b.file.path);
      });

      var total = entries.fold<int>(0, (sum, e) => sum + e.size);
      var count = entries.length;
      for (final e in entries) {
        if (total <= maxBytes && count <= maxFiles) break;
        if (await _tryDelete(e.file)) {
          total -= e.size;
          count--;
        }
      }
    } catch (e) {
      AppLogger.error('card-cache', '용량 정리 실패(화면엔 영향 없음): $e');
    }
  }

  /// 폴더째 지운다. 로그아웃·탈퇴·세션 만료 때 부른다.
  Future<void> clear() {
    // 진행 중인 다운로드가 뒤늦게 저장하지 못하게 먼저 표식을 올린다
    _generation++;
    final run = _chain.then((_) async {
      try {
        final dir = await _dir();
        if (dir != null && await dir.exists()) {
          await dir.delete(recursive: true);
        }
      } catch (e) {
        AppLogger.error('card-cache', '캐시 폴더 삭제 실패: $e');
      }
    });
    _chain = run.then((_) {}, onError: (_) {});
    return run;
  }

  Future<bool> _tryDelete(File f) async {
    try {
      await f.delete();
      return true;
    } catch (e) {
      AppLogger.error('card-cache', '파일 삭제 실패: $e');
      return false;
    }
  }

  /// JPEG·PNG·WebP 머리 바이트만 본다. 디코딩은 무거워 하지 않는다.
  @visibleForTesting
  static bool looksLikeImage(Uint8List b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    if (b.length >= 8 &&
        b[0] == 0x89 &&
        b[1] == 0x50 &&
        b[2] == 0x4E &&
        b[3] == 0x47 &&
        b[4] == 0x0D &&
        b[5] == 0x0A &&
        b[6] == 0x1A &&
        b[7] == 0x0A) {
      return true;
    }
    // WebP: "RIFF" + 크기 4바이트 + "WEBP"
    return b.length >= 12 &&
        b[0] == 0x52 &&
        b[1] == 0x49 &&
        b[2] == 0x46 &&
        b[3] == 0x46 &&
        b[8] == 0x57 &&
        b[9] == 0x45 &&
        b[10] == 0x42 &&
        b[11] == 0x50;
  }
}

final cardImageDiskCacheProvider = Provider<CardImageDiskCache>(
  (ref) => CardImageDiskCache(rootProvider: getApplicationSupportDirectory),
);
