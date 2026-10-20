import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/logger/app_logger.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../../../core/storage/card_image_disk_cache.dart';

/// 이야기 글의 카드 그림: 디스크 캐시 > 네트워크 (인증 Dio 라야 받는다)
/// `GET /api/talk/posts/{postId}/steps/{stepOrder}/image`
/// 절대 throw 하지 않는다 (그림 한 장 때문에 글이 사라지면 안 됨, 실패는 null)
class TalkImageRepository {
  TalkImageRepository({required Dio dio, required CardImageDiskCache diskCache})
    : _dio = dio,
      _disk = diskCache;

  final Dio _dio;
  final CardImageDiskCache _disk;

  /// 진행 중인 요청: 같은 그림을 동시에 달라고 해도 받기·쓰기는 한 번
  final Map<String, Future<Uint8List?>> _inFlight = {};

  /// 캐시 열쇠: talk/{postId}/{stepOrder}
  static String cacheKeyOf(String postId, int stepOrder) =>
      'talk/$postId/$stepOrder';

  Future<Uint8List?> fetch(String postId, int stepOrder) {
    final cacheKey = cacheKeyOf(postId, stepOrder);
    return _inFlight[cacheKey] ??= _load(postId, stepOrder, cacheKey)
        .whenComplete(() {
          // 값을 돌려주면 whenComplete 가 그 Future 를 기다려 자기 자신을 물고 멈춘다 — 블록으로 쓴다
          _inFlight.remove(cacheKey);
        });
  }

  Future<Uint8List?> _load(
    String postId,
    int stepOrder,
    String cacheKey,
  ) async {
    // 다운로드 도중 로그아웃(캐시 삭제)이 있었는지 알아보려고 시작 시점을 적어 둔다
    final generation = _disk.generation;

    final cached = await _disk.read(cacheKey);
    if (cached != null) return cached;

    final bytes = await _download(postId, stepOrder);
    if (bytes == null) return null;

    await _disk.write(cacheKey, bytes, generation: generation);
    return bytes;
  }

  Future<Uint8List?> _download(String postId, int stepOrder) async {
    try {
      final response = await _dio.get<List<int>>(
        '/api/talk/posts/${Uri.encodeComponent(postId)}/steps/$stepOrder/image',
        options: Options(
          responseType: ResponseType.bytes,
          extra: {ProfileHeaderInterceptor.skipKey: true},
        ),
      );
      final bytes = response.data;
      if (bytes == null || bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (e) {
      AppLogger.error('talk', 'image fetch failed -> fallback picture : $e');
      return null;
    }
  }
}

final talkImageRepositoryProvider = Provider<TalkImageRepository>(
  (ref) => TalkImageRepository(
    dio: ref.watch(dioProvider),
    diskCache: ref.watch(cardImageDiskCacheProvider),
  ),
);
