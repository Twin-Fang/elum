
import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'app_log_interceptor.dart';
// 비활성 상태지만 되살릴 때 바로 쓰도록 남겨둔다
// ignore: unused_import
import 'encryption_interceptor.dart';

/// Dio 인스턴스 생성. 설정값은 전부 [AppConfig]에서 온다 — 하드코딩하지 않는다.
abstract final class DioClient {
  /// [attachLog] 가 true 면 의견 첨부용 기록 인터셉터를 붙인다.
  /// 다른 인터셉터를 더 붙일 호출부는 false 로 받아 **맨 뒤에** 직접 붙인다 —
  /// 앞에 붙으면 인증 갱신 전의 중간 결과와 나중에 붙는 헤더를 못 본다.
  static Dio create({bool attachLog = true}) {
    final dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.connectTimeout,
        receiveTimeout: AppConfig.receiveTimeout,
        contentType: 'application/json',
      ),
    );

    // ⚠️ AI DLP 요청 암호화 — 현재 비활성.
    //
    // 서버 시크릿이 비면 서버 필터가 복호화를 건너뛰어 암호문 봉투가 그대로 역직렬화되고,
    // 카드 생성이 500 으로 죽는다. 다시 켜려면 **양쪽 시크릿을 먼저 맞춘다**
    // (서버 elum.aidlp.secret = 클라이언트 ELUM_AIDLP_SECRET, 값은 같기만 하면 된다) 뒤 주석을 푼다.
    // 로깅보다 먼저 등록해야 봉투로 바뀐 본문만 로그에 남아 원문이 새지 않는다.
    // dio.interceptors.add(EncryptionInterceptor(secret: AppConfig.aidlpSecret));

    if (attachLog) dio.interceptors.add(AppLogInterceptor());

    return dio;
  }
}
