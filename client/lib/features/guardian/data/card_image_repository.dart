import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// 카드 이미지를 받아온다.
///
/// 서버가 AI로 만든 그림을 인증된 요청에만 준다.
/// `GET /api/routines/{routineId}/steps/{stepId}/image` → `image/png`
///
/// **`Image.network`를 쓸 수 없어 여기가 필요하다.** 그 위젯은 Authorization
/// 헤더를 붙이지 못해 401을 받는다. 바이트를 직접 받아 화면에 넘긴다.
///
/// **절대 throw하지 않는다.** 이미지 한 장 때문에 카드가 사라지면 안 된다.
class CardImageRepository {
  CardImageRepository({Dio? dio}) : _dio = dio ?? DioClient.create();

  final Dio _dio;

  /// 실패하면 null. 화면은 캐릭터 일러스트로 대체한다.
  Future<Uint8List?> fetch({
    required String routineId,
    required String stepId,
  }) async {
    try {
      final res = await _dio.get<List<int>>(
        '/api/routines/$routineId/steps/$stepId/image',
        options: Options(responseType: ResponseType.bytes),
      );
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;
      return Uint8List.fromList(bytes);
    } catch (e) {
      debugPrint('[card] 이미지 조회 실패 → 대체 일러스트 사용: $e');
      return null;
    }
  }
}

final cardImageRepositoryProvider = Provider<CardImageRepository>(
  (ref) => CardImageRepository(dio: ref.watch(dioProvider)),
);

/// 카드 한 장의 이미지.
///
/// 같은 카드를 여러 화면(카드확인·아이 홈)에서 보여주므로 캐시가 필요하다.
/// family provider가 인자별로 결과를 들고 있어 **재요청하지 않는다** —
/// 1MB가 넘는 이미지를 화면마다 다시 받으면 느리고 비싸다.
final cardImageProvider =
    FutureProvider.family<Uint8List?, ({String routineId, String stepId})>(
  (ref, key) {
    // 화면을 벗어나도 잠시 유지한다. 카드를 넘겼다 돌아올 때 다시 받지 않는다.
    ref.keepAlive();

    return ref.watch(cardImageRepositoryProvider).fetch(
          routineId: key.routineId,
          stepId: key.stepId,
        );
  },
);
