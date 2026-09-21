import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';

/// 약관 동의를 서버에 기록한다.
///
/// 동의 시각은 서버가 남긴다 — 기기 시계는 사용자가 바꿀 수 있어 증빙이 되지 않는다.
/// 서버가 받는 동의 필드 전부. 화면에 없는 항목도 `false` 로 명시해서 보낸다 —
/// 빠뜨리면 서버가 기본값으로 채우는데, 그 기본값이 무엇인지에 기록이 기대게 된다.
const consentFields = <String>[
  'termsAgreed',
  'privacyAgreed',
  'overseasTransferAgreed',
  'guardianConfirmed',
  'marketingAgreed',
];

class ConsentRepository {
  ConsentRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// [agreedKeys] 는 **사용자가 실제로 켠 항목**이다 (이슈 #278 QA).
  ///
  /// 전에는 필수 네 항목을 `true` 로 고정해서 보냈다. 화면이 넷을 강제하던 시절엔
  /// 안전했지만, 관리자가 필수를 끌 수 있게 되자 **사용자가 켜지 않은 항목이 동의한
  /// 것으로 기록**됐다. 보낸 값이 곧 증빙이므로 화면에서 켠 것만 `true` 로 보낸다.
  /// 필수를 빠뜨리면 서버가 400 으로 거절한다 — 거짓 기록보다 막히는 편이 낫다.
  ///
  /// [version] 은 **화면에 실제로 보여준 약관의 버전**이다. 서버 최신본을 못 받아
  /// 캐시나 앱 기본값을 보여줬다면 그쪽 버전으로 기록해야 한다.
  ///
  /// @return 저장 성공 여부. 실패해도 예외를 던지지 않는다.
  Future<bool> agree({
    required Set<String> agreedKeys,
    required String version,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/member/consents',
        data: {
          for (final field in consentFields) field: agreedKeys.contains(field),
          'consentVersion': version,
        },
      );
      return true;
    } catch (e) {
      AppLogger.error('약관 동의 저장', e);
      return false;
    }
  }
}

final consentRepositoryProvider = Provider<ConsentRepository>((ref) {
  return ConsentRepository(dio: ref.watch(dioProvider));
});
