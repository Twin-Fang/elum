import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/dio_client.dart';

/// 약관 동의를 서버에 기록한다.
///
/// 동의 시각은 서버가 남긴다 — 기기 시계는 사용자가 바꿀 수 있어 증빙이 되지 않는다.
class ConsentRepository {
  ConsentRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// [version] 은 **화면에 실제로 보여준 약관의 버전**이다 (이슈 #278).
  ///
  /// 서버 최신본을 못 받아 캐시나 앱 기본값을 보여줬다면 그쪽 버전으로 기록해야
  /// 한다. 서버 최신 버전을 적어 버리면 **사용자가 보지 않은 문서에 동의한 것으로**
  /// 남는다.
  ///
  /// @return 저장 성공 여부. 실패해도 예외를 던지지 않는다.
  Future<bool> agree({
    required bool marketingAgreed,
    required String version,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/api/member/consents',
        data: {
          // 필수 항목은 화면에서 이미 전부 체크된 상태로만 넘어온다.
          // 서버도 하나라도 false면 400으로 거절한다.
          'termsAgreed': true,
          'privacyAgreed': true,
          'overseasTransferAgreed': true,
          // 나이 확인은 화면에서 별도 항목이지만 (이슈 #226) 서버 필드는
          // 아직 하나다. 무엇에 동의했는지는 consentVersion이 가른다 —
          // 문구가 바뀌면 버전을 올려 기록이 어긋나지 않게 한다.
          'guardianConfirmed': true,
          'marketingAgreed': marketingAgreed,
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
