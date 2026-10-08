import 'dart:ui';

import 'package:dio/dio.dart';

import '../l10n/region_code.dart';

/// 요청마다 앱 언어를 `Accept-Language` 로 싣는다 (공통 계약 C1).
///
/// 서버는 이 헤더로 에러 문구·폴백 질문·공지·약관의 언어를 고른다. 헤더가 없는 구버전 앱은 서버가
/// `ko` 로 응답하므로 이미 배포된 앱은 영향이 없고, 새 앱만 이 값을 보낸다.
class AcceptLanguageInterceptor extends Interceptor {
  AcceptLanguageInterceptor({required this.locale, this.region});

  static const headerName = 'Accept-Language';

  /// 휴대폰 지역을 싣는 헤더. 서버 `CurrentRegion` 이 읽는다.
  static const regionHeaderName = 'X-Elum-Region';

  /// 요청 시점의 앱 언어. OS 언어가 바뀌어도 다음 요청부터 따라가도록 값이 아니라 함수다.
  final Locale Function() locale;

  /// 요청 시점의 지역 코드. 주지 않으면(기존 생성 방식) 지역 헤더를 붙이지 않는다.
  /// 테스트가 값을 고정할 수 있도록 함수로 주입한다.
  final String? Function()? region;

  /// 내부 코드 → 전송 값. 중국어만 간체 표기(`zh-Hans`)로 보낸다.
  static String headerValue(Locale l) =>
      l.languageCode == 'zh' ? 'zh-Hans' : l.languageCode;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // 호출부가 직접 정한 값(예: 약관을 다른 언어로 미리보기)은 덮지 않는다.
    // Dio 헤더는 대소문자를 가리지 않아 `accept-language` 로 넣은 값도 막아 준다.
    options.headers.putIfAbsent(headerName, () => headerValue(locale()));

    // 지역 코드가 없거나 형식이 틀리면 헤더만 뺀다 — 서버는 헤더 없음을 구버전 앱으로 본다.
    // 여기서 다시 검사하는 이유: 주입된 함수가 정규화를 안 거친 값을 줘도 깨진 헤더가 나가지 않게.
    final code = normalizeRegionCode(region?.call());
    if (code != null) {
      options.headers.putIfAbsent(regionHeaderName, () => code);
    }
    handler.next(options);
  }
}
