import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

/// 환경변수 접근 단일 창구.
///
/// 위젯이나 repository가 `dotenv.env['...']`를 직접 읽지 않는다.
/// 키 이름이 코드 곳곳에 흩어지면 오타를 잡을 수 없고, 기본값도 제각각이 된다.
///
/// **새 환경변수를 추가할 때는 반드시 `.env.example`도 함께 수정한다.**
/// 그 파일이 "어떤 키가 필요한지"의 유일한 문서다.
abstract final class AppConfig {
  /// main에서 runApp 전에 한 번 호출한다.
  ///
  /// .env가 없어도 앱은 떠야 한다 — 신규 개발자가 파일을 만들기 전에
  /// 앱이 죽으면 원인을 찾기 어렵다. 기본값으로 동작하고 경고만 남긴다.
  static Future<void> load() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      debugPrint('[config] .env 없음 → 기본값으로 동작한다. '
          '.env.example을 복사해 .env를 만들 것. ($e)');
    }
  }

  // --- 서버 ---

  static String get apiBaseUrl =>
      _string('ELUM_API_BASE_URL', 'https://api.elum.chuseok22.com');

  static Duration get connectTimeout =>
      Duration(milliseconds: _int('ELUM_API_CONNECT_TIMEOUT_MS', 10000));

  static Duration get receiveTimeout =>
      Duration(milliseconds: _int('ELUM_API_RECEIVE_TIMEOUT_MS', 60000));

  // --- 데모 연출 ---

  /// AI DLP 처리 최소 노출 시간.
  /// 응답이 빨라도 보안 처리를 체감시키기 위해 유지한다.
  static Duration get dlpMinDelay =>
      Duration(milliseconds: _int('ELUM_DLP_MIN_DELAY_MS', 1500));

  // --- 개발 ---

  /// 네트워크 로깅. 릴리스 빌드에서는 값과 무관하게 항상 꺼진다.
  static bool get enableNetworkLog =>
      kDebugMode && _bool('ELUM_ENABLE_NETWORK_LOG', true);

  /// 서버 대신 mock 데이터를 쓸지. 서버 준비 전 개발·데모용.
  static bool get useMock => _bool('ELUM_USE_MOCK', true);

  /// 개발자 도구 오버레이(플로팅 버튼)를 띄울지.
  ///
  /// ⚠️ [enableNetworkLog]와 달리 `kDebugMode`를 걸지 않는다. 목적이 다르다 —
  /// 네트워크 로깅은 운영에서 절대 켜지면 안 되는 값이고, 개발자 도구는
  /// 심사자·테스터가 **릴리스 빌드로** 확인해야 하는 값이다.
  /// debug 게이트를 걸면 정작 필요한 사람이 쓰지 못한다.
  ///
  /// 정식 출시 전 `.env`와 GitHub Secret에서 false로 바꾼다. (이슈 #13)
  static bool get showDevTools => _bool('ELUM_SHOW_DEV_TOOLS', false);

  // --- 파싱 헬퍼 ---
  // 값이 없거나 형식이 틀려도 예외를 던지지 않는다.
  // 설정 하나 때문에 앱이 뜨지 않으면 데모가 막힌다.

  static String _string(String key, String fallback) {
    final value = dotenv.env[key];
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static int _int(String key, int fallback) {
    final raw = dotenv.env[key];
    if (raw == null) return fallback;
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      debugPrint('[config] $key 값이 숫자가 아니다("$raw") → 기본값 $fallback 사용');
      return fallback;
    }
    return parsed;
  }

  static bool _bool(String key, bool fallback) {
    final raw = dotenv.env[key]?.toLowerCase();
    return switch (raw) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => fallback,
    };
  }
}
