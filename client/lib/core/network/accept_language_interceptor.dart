import 'dart:ui';

import 'package:dio/dio.dart';

/// 요청마다 앱 언어를 `Accept-Language` 로 싣는다 (공통 계약 C1).
///
/// 서버는 이 헤더로 에러 문구·폴백 질문·공지·약관의 언어를 고른다. 헤더가 없는 옛 앱은 서버가
/// `ko` 로 응답하므로 이미 배포된 앱은 영향이 없고, 새 앱만 이 값을 보낸다.
class AcceptLanguageInterceptor extends Interceptor {
  AcceptLanguageInterceptor({required this.locale});

  static const headerName = 'Accept-Language';

  /// 요청 시점의 앱 언어. OS 언어가 바뀌어도 다음 요청부터 따라가도록 값이 아니라 함수다.
  final Locale Function() locale;

  /// 내부 코드 → 전송 값. 중국어만 간체 표기(`zh-Hans`)로 보낸다.
  static String headerValue(Locale l) =>
      l.languageCode == 'zh' ? 'zh-Hans' : l.languageCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 호출부가 직접 정한 값(예: 약관을 다른 언어로 미리보기)은 덮지 않는다.
    // Dio 헤더는 대소문자를 가리지 않아 `accept-language` 로 넣은 값도 막아 준다.
    options.headers.putIfAbsent(headerName, () => headerValue(locale()));
    handler.next(options);
  }
}
