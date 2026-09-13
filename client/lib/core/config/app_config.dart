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

  // --- TTS (카드 읽어주기) ---
  // 기기 내장 음성이 우선이고, 실패할 때만 이 서버를 쓴다.
  // 키가 없으면 서버 폴백만 꺼지고 기기 음성은 그대로 동작한다.

  static String get ttsBaseUrl =>
      _string('ELUM_TTS_BASE_URL', 'https://ai.suhsaechan.kr/api/flask');

  /// ⚠️ 유출되면 안 되는 값이다. `.env.example`에는 빈 값으로 둔다.
  static String get ttsApiKey => _string('ELUM_TTS_API_KEY', '');

  /// AI DLP 요청 암호화 마스터 시크릿. 서버 application-dev.yml의 elum.aidlp.secret와 동일 값.
  /// 비면 암호화를 건너뛴다(평문 전송 → 서버도 통과, 데모 안전).
  static String get aidlpSecret => _string('ELUM_AIDLP_SECRET', '');

  // --- 데모 연출 ---

  /// AI DLP 처리 최소 노출 시간.
  /// 응답이 빨라도 보안 처리를 체감시키기 위해 유지한다.
  static Duration get dlpMinDelay =>
      Duration(milliseconds: _int('ELUM_DLP_MIN_DELAY_MS', 1500));

  // --- 빌드 종류 ---

  /// 개발용 빌드인지. **컴파일 타임에 결정되며 `.env`로는 바꿀 수 없다.**
  ///
  /// ```bash
  /// flutter build apk --release                              # 제출·배포용 (기본)
  /// flutter build apk --release --dart-define=ELUM_BUILD=dev  # 내부 테스트용
  /// ```
  ///
  /// **왜 `.env`가 아니라 dart-define인가** — 개발 플래그를 `.env`로 제어하면
  /// GitHub Secret에 잘못된 값이 들어가는 순간 mock 데이터로 도는 APK가 배포된다.
  /// 심사위원이 설치했을 때 가짜 데이터가 나오는 사고를 코드로 막는다. (이슈 #130)
  static const String _buildFlavor =
      String.fromEnvironment('ELUM_BUILD', defaultValue: 'prod');

  /// 개발용 빌드에서만 true. 제출용 APK에서는 어떤 설정을 넣어도 false다.
  static bool get isDevBuild => _buildFlavor == 'dev';

  // --- 개발 ---

  /// 네트워크 로깅. 릴리스 빌드에서는 값과 무관하게 항상 꺼진다.
  static bool get enableNetworkLog =>
      kDebugMode && _bool('ELUM_ENABLE_NETWORK_LOG', true);

  /// 서버 대신 mock 데이터를 쓸지. 서버 준비 전 개발·데모용.
  ///
  /// ⚠️ **릴리스 빌드에서는 `.env` 값과 무관하게 꺼진다** (개발용 빌드 제외).
  /// 기본값이 `true`라서, 설정이 누락되면 mock으로 도는 APK가 나갈 수 있었다.
  ///
  /// `kDebugMode`를 함께 허용하는 이유는 **개발과 테스트를 막지 않기 위해서**다.
  /// 차단해야 하는 것은 "릴리스로 빌드된 제출·배포용 APK"뿐이다.
  static bool get useMock =>
      (kDebugMode || isDevBuild) && _bool('ELUM_USE_MOCK', true);

  /// 개발자 도구 오버레이(플로팅 버튼)를 띄울지.
  ///
  /// 심사자·테스터가 **릴리스 빌드로** 확인해야 하는 값이라 `kDebugMode`를 걸지 않는다.
  /// 대신 **개발용 빌드**에서만 켜지게 한다 — 확인이 필요한 사람에게는
  /// `ELUM_BUILD=dev`로 만든 APK를 따로 전달한다.
  static bool get showDevTools =>
      (kDebugMode || isDevBuild) && _bool('ELUM_SHOW_DEV_TOOLS', false);

  /// 온보딩을 건너뛸지. 개발·시연용. SharedPreferences에서 런타임 토글 가능.
  ///
  /// ⚠️ 제출용 빌드에서는 항상 false다. 온보딩을 건너뛰면 PIN이 설정되지 않아
  /// 아이가 보호자 모드로 들어갈 수 있다 (이슈 #61).
  static bool skipOnboarding =
      (kDebugMode || isDevBuild) && _bool('ELUM_SKIP_ONBOARDING', false);

  // --- 파싱 헬퍼 ---
  // 값이 없거나 형식이 틀려도 예외를 던지지 않는다.
  // 설정 하나 때문에 앱이 뜨지 않으면 데모가 막힌다.

  /// 환경변수 원본 읽기.
  ///
  /// `dotenv.env`는 [load]를 부르기 전에 접근하면 예외를 던진다. 위젯 테스트는
  /// main을 타지 않아 load가 호출되지 않으므로, 여기서 흡수하지 않으면
  /// 네트워크 계층을 건드리는 모든 테스트가 죽는다.
  static String? _raw(String key) {
    if (!dotenv.isInitialized) return null;
    return dotenv.env[key];
  }

  static String _string(String key, String fallback) {
    final value = _raw(key);
    if (value == null || value.isEmpty) return fallback;
    return value;
  }

  static int _int(String key, int fallback) {
    final raw = _raw(key);
    if (raw == null) return fallback;
    final parsed = int.tryParse(raw);
    if (parsed == null) {
      debugPrint('[config] $key 값이 숫자가 아니다("$raw") → 기본값 $fallback 사용');
      return fallback;
    }
    return parsed;
  }

  static bool _bool(String key, bool fallback) {
    final raw = _raw(key)?.toLowerCase();
    return switch (raw) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => fallback,
    };
  }
}
