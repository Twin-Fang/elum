import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/dio_provider.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';

/// 보호자가 적은 의견을 보낸다.
///
/// 의견 원문과 앱 상태 기록은 **로그에 남기지 않는다** — [guarded] 에는 저장소·메서드 이름만 넘긴다.
class FeedbackRepository {
  FeedbackRepository(this._dio);

  final Dio _dio;

  /// 화면 실패 팝업에 서버 코드가 없을 때 쓰는 자리 코드.
  static const failureCode = 'E-FEEDBACK';

  /// 의견을 보낸다. 성공하면 서버가 준 id, 실패하면 [AppFailure].
  ///
  /// [appLog]·[appVersion]·[os] 는 비었으면 본문에서 뺀다.
  Future<Attempt<String>> send({
    required String message,
    String? appLog,
    String? appVersion,
    String? os,
  }) {
    return guarded<String>('FeedbackRepository', 'send', () async {
      final res = await _dio.post<Object?>(
        '/api/feedback',
        data: {
          'message': message,
          if (appLog != null && appLog.isNotEmpty) 'appLog': appLog,
          if (appVersion != null && appVersion.isNotEmpty)
            'appVersion': appVersion,
          if (os != null && os.isNotEmpty) 'os': os,
        },
      );
      // 응답 모양이 달라도 앱이 죽지 않고 실패 팝업으로 간다
      final data = res.data;
      final id = data is Map ? data['id'] : null;
      if (id is! String || id.isEmpty) {
        throw const FormatException('의견 응답에 id 가 없다');
      }
      return id;
    });
  }
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>(
  (ref) => FeedbackRepository(ref.watch(dioProvider)),
);
