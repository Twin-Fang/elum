import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'client_tuning.dart';

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
      debugPrint(
        '[config] .env 없음 → 기본값으로 동작한다. '
        '.env.example을 복사해 .env를 만들 것. ($e)',
      );
    }
  }

  // --- 서버 ---

  static String get apiBaseUrl =>
      _string('ELUM_API_BASE_URL', 'https://api.elum.chuseok22.com');

  // --- 대기·연출 시간값 ---
  // `.env` 에서 읽지 않는다. 서버가 주고 관리자 화면에서 고친다 ([ClientTuning]).
  // 코드에는 기본값만 있다. 서버 주소처럼 서버에 닿기 전에 필요한 값만 `.env` 에 남는다.

  static ClientTuning _tuning = ClientTuning.defaults;
  static TuningSource _tuningSource = TuningSource.defaults;

  /// 지금 쓰는 시간값이 어디서 왔나 (개발자 도구 표시용).
  static TuningSource get tuningSource => _tuningSource;

  /// 시간값을 바꾼다. main 에서 저장해 둔 값으로 한 번, 서버에서 받으면 또 한 번 부른다.
  static void applyTuning(ClientTuning tuning, {required TuningSource source}) {
    _tuning = tuning;
    _tuningSource = source;
  }

  /// 테스트가 끝나면 기본값으로 되돌린다. 정적 값이라 테스트끼리 새어 나간다.
  @visibleForTesting
  static void resetTuning() => applyTuning(ClientTuning.defaults, source: TuningSource.defaults);

  static Duration get connectTimeout => _tuning.connectTimeout;

  static Duration get receiveTimeout => _tuning.receiveTimeout;

  /// 동의 화면이 약관을 기다리는 상한 (#278). 넘기면 캐시·앱 기본값으로 떨어진다.
  static Duration get consentFetchTimeout => _tuning.consentFetchTimeout;

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

  /// 문의를 받는 주소. 설정 화면의 `문의하기`가 보여준다 (이슈 #289).
  ///
  /// 게시된 도움말 페이지·개인정보처리방침의 보호책임자 주소와 **같은 값이어야 한다.**
  /// 두 곳에 다른 주소를 두면 사용자가 어디로 보내야 하는지 헷갈리고,
  /// 한쪽만 고쳤을 때 조용히 어긋난다.
  static String get supportEmail =>
      _string('ELUM_SUPPORT_EMAIL', 'chan4760@gmail.com');

  // --- 스토어 (강제 업데이트 화면이 보낸다 — #279) ---
  // `.env` 에 두지 않는다. 환경마다 달라지는 값이 아니라 앱 자체의 식별자라서,
  // Secret 을 빠뜨려 빈 값이 배포돼도 증상이 없는 길을 만들 이유가 없다.

  /// Play 스토어 패키지명. `android/app/build.gradle.kts` 의 `applicationId` 와 같아야 한다.
  static const androidPackageId = 'kr.twinfang.elum';

  /// App Store Connect 의 Apple ID(숫자). 첫 출시 후 받은 값이다
  /// (https://apps.apple.com/kr/app/id6792970508).
  ///
  /// 비우면 iOS 강제 업데이트 화면은 스토어 버튼을 숨긴다. 검색 주소로 대신
  /// 보내지 않는다 — 같은 이름의 다른 앱으로 보낼 수 있다.
  static const iosAppStoreId = '6792970508';

  /// 플랫폼별 스토어 상세 주소. 보낼 곳을 모르면 null 이다.
  ///
  /// [serverUrl] 이 그 플랫폼의 공식 스토어 주소면 그것을 먼저 쓴다 (#416).
  /// 강제 업데이트 화면은 옛 버전 앱에서 뜨므로, 서버에서 바꿀 수 있어야 이미 깔린 앱도
  /// 보낼 곳을 고칠 수 있다. 비었거나 스토어 주소가 아니면 앱에 넣어 둔 주소로 돌아간다 —
  /// 서버 설정이 잘못돼도 막힌 사용자를 엉뚱한 곳으로 보내지 않는다.
  static Uri? storeUrl(TargetPlatform platform, {String serverUrl = ''}) {
    final fromServer = _allowedStoreUrl(platform, serverUrl);
    if (fromServer != null) return fromServer;
    return _builtInStoreUrl(platform);
  }

  /// 서버 값이 그 플랫폼의 공식 스토어 주소면 Uri, 아니면 null.
  /// 서버 `StoreUrlPolicy` 와 같은 규칙이다 — 서버가 저장할 때 한 번, 앱이 열 때 한 번 거른다.
  static Uri? _allowedStoreUrl(TargetPlatform platform, String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final uri = Uri.tryParse(value);
    if (uri == null) return null;
    final scheme = uri.scheme.toLowerCase();
    // 호스트는 정확히 같아야 한다 — endsWith 로 보면 apps.apple.com.evil.com 이 통과한다
    final host = uri.host.toLowerCase();
    final allowed = switch (platform) {
      TargetPlatform.iOS =>
        (scheme == 'https' || scheme == 'itms-apps') && host == 'apps.apple.com',
      // market://details?id=... 는 호스트 자리에 details 가 온다
      TargetPlatform.android => (scheme == 'https' && host == 'play.google.com') ||
          (scheme == 'market' && host == 'details'),
      _ => false,
    };
    return allowed ? uri : null;
  }

  static Uri? _builtInStoreUrl(TargetPlatform platform) => switch (platform) {
        TargetPlatform.android => Uri.https(
            'play.google.com',
            '/store/apps/details',
            {'id': androidPackageId},
          ),
        // itms-apps 는 브라우저를 거치지 않고 App Store 앱을 바로 연다
        TargetPlatform.iOS when iosAppStoreId.isNotEmpty =>
          Uri.parse('itms-apps://apps.apple.com/app/id$iosAppStoreId'),
        _ => null,
      };

  // --- 소셜 로그인 ---
  // 콘솔에서 앱을 등록하고 받은 값이다. 받는 절차는
  // docs/setup/소셜로그인_설정가이드.md 참조.
  //
  // ⚠️ 여기 값만으로는 부족하다. 카카오·구글은 로그인 후 앱으로 돌아오는 URL 스킴을
  // AndroidManifest.xml·Info.plist에도 등록해야 한다. 그 값들은 빌드 타임에 필요해서
  // .env로 주입할 수 없다.

  /// 카카오 네이티브 앱 키. 앱에 포함되는 공개 값이다(비밀은 Admin 키뿐).
  static String get kakaoNativeAppKey =>
      _string('ELUM_KAKAO_NATIVE_APP_KEY', '');

  static String get naverClientId => _string('ELUM_NAVER_CLIENT_ID', '');

  /// 네이버는 모바일 SDK가 시크릿을 요구한다. 앱에 들어갈 수밖에 없는 구조다.
  static String get naverClientSecret =>
      _string('ELUM_NAVER_CLIENT_SECRET', '');

  /// 네이버 로그인 동의 화면에 표시되는 서비스 이름.
  static String get naverClientName => _string('ELUM_NAVER_CLIENT_NAME', '이룸');

  /// 구글 **웹** 클라이언트 ID. 안드로이드 클라이언트 ID가 아니다.
  /// 안드로이드에서 ID 토큰을 받으려면 serverClientId에 웹 ID를 넘겨야 한다.
  static String get googleServerClientId =>
      _string('ELUM_GOOGLE_SERVER_CLIENT_ID', '');

  /// 구글 iOS 클라이언트 ID.
  static String get googleIosClientId =>
      _string('ELUM_GOOGLE_IOS_CLIENT_ID', '');

  // --- 데모 연출 ---

  /// AI DLP 처리 최소 노출 시간. 서버가 준다 ([ClientTuning]).
  /// 응답이 빨라도 보안 처리를 체감시키기 위해 유지한다.
  static Duration get dlpMinDelay => _tuning.dlpMinDelay;

  /// 로딩 화면이 결과를 기다리는 최대 시간 (#276). 서버가 준다 ([ClientTuning]).
  ///
  /// 이만큼 지나도 응답이 없으면 기다리기를 그만두고 에러 코드와 재시도를
  /// 보여준다. `receiveTimeout`(60초)보다 짧게 둔 것은, 네트워크가 끝까지
  /// 버티는 동안 사용자를 1분 내내 붙잡아 두지 않기 위해서다.
  static Duration get loadingMaxWait => _tuning.loadingMaxWait;

  // --- 빌드 종류 ---

  /// 개발용 빌드인지. **컴파일 타임에 결정되며 `.env`로는 바꿀 수 없다.**
  ///
  /// ```bash
  /// flutter build apk --release                                       # 제출·배포용 (기본)
  /// flutter build apk --release --dart-define=APP_FLAVOR=dev  # 내부 테스트용
  /// ```
  ///
  /// **왜 `.env`가 아니라 dart-define인가** — 개발 플래그를 `.env`로 제어하면
  /// GitHub Secret에 잘못된 값이 들어가는 순간 mock 데이터로 도는 APK가 배포된다.
  /// 심사위원이 설치했을 때 가짜 데이터가 나오는 사고를 코드로 막는다. (이슈 #130)
  ///
  /// **왜 `APP_FLAVOR`인가** — 앱 이름이 안 들어가는 중립적인 이름이라 CI 템플릿이
  /// 앱을 몰라도 된다. 전에는 `ELUM_BUILD`를 썼는데 레포마다 이름이 달랐다 (이슈 #220).
  ///
  /// Flutter 표준인 `FLUTTER_APP_FLAVOR`(SDK의 `appFlavor`)를 쓰려 했으나
  /// **CLI가 예약어로 막는다** — `--flavor`로만 설정되고, 그건 Gradle productFlavors와
  /// Xcode scheme을 갖춰야 한다.
  ///
  /// ```
  /// FLUTTER_APP_FLAVOR is used by the framework and cannot be set using --dart-define
  /// ```
  ///
  /// 나중에 `--flavor`를 갖추게 되면 이 getter만 `appFlavor == 'dev'`로 바꾸면 된다.
  static const String _flavor = String.fromEnvironment('APP_FLAVOR');

  /// 개발용 빌드에서만 true. 제출용 APK에서는 어떤 설정을 넣어도 false다.
  static bool get isDevBuild => _flavor == 'dev';

  // --- 개발 ---

  /// 네트워크 로깅.
  ///
  /// **개발자 도구를 켰으면 함께 켜진다** (이슈 #219). 디버깅 도구를 열어 두고도
  /// 백엔드가 무슨 값을 보냈는지 못 보면 도구를 쓸 이유가 없다. QA가 받는
  /// 개발용 APK는 릴리스 빌드라, `kDebugMode`만 보면 늘 꺼져 있었다.
  static bool get enableNetworkLog =>
      (kDebugMode || showDevTools) && _bool('ELUM_ENABLE_NETWORK_LOG', true);

  /// 개발자 도구 오버레이(플로팅 버튼)를 띄울지.
  ///
  /// 심사자·테스터가 **릴리스 빌드로** 확인해야 하는 값이라 `kDebugMode`를 걸지 않는다.
  /// 대신 **개발용 빌드**에서만 켜지게 한다 — 확인이 필요한 사람에게는
  /// 플레이버를 `dev`로 넘겨 만든 APK를 따로 전달한다.
  ///
  /// 🔴 **게이트가 둘이다.** `.env`의 이 값만 켜도 보이지 않는다 —
  /// 플레이버(`--dart-define=APP_FLAVOR=dev`)를 함께 넘겨야 한다.
  /// `client/tool/apply_build_profile.sh`가 두 층을 한 번에 맞춰 준다 (이슈 #220).
  static bool get showDevTools =>
      (kDebugMode || isDevBuild) && _bool('ELUM_SHOW_DEV_TOOLS', false);

  /// 온보딩을 건너뛸지. 개발·시연용. SharedPreferences에서 런타임 토글 가능.
  ///
  /// ⚠️ 제출용 빌드에서는 항상 false다. 온보딩을 건너뛰면 PIN이 설정되지 않아
  /// 아이가 보호자 모드로 들어갈 수 있다 (이슈 #61).
  static bool skipOnboarding =
      (kDebugMode || isDevBuild) && _bool('ELUM_SKIP_ONBOARDING', false);

  /// QA 세션 주입 — **디버그 빌드에서만** 동작한다.
  ///
  /// 로그인 뒤에 있는 화면(역할 선택·온보딩·보호자 홈)을 실기기로 확인하려면
  /// 소셜 로그인을 통과해야 하는데, 계정 입력은 사람 손을 탄다. 그래서 검수할 때
  /// 서버에서 받은 토큰을 `.env`에 넣어 세션이 있는 상태로 앱을 띄운다.
  ///
  /// ⚠️ **`isDevBuild`를 쓰지 않고 `kDebugMode`만 본다.** 개발용 APK는 심사자에게
  /// 전달되지만 디버그 빌드는 배포되지 않는다. 남의 토큰으로 앱이 열리는 길은
  /// 배포물에 절대 있으면 안 된다.
  static String get devRefreshToken =>
      kDebugMode ? _string('ELUM_DEV_REFRESH_TOKEN', '') : '';

  static String get devAccessToken =>
      kDebugMode ? _string('ELUM_DEV_ACCESS_TOKEN', '') : '';

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

  static bool _bool(String key, bool fallback) {
    final raw = _raw(key)?.toLowerCase();
    return switch (raw) {
      'true' || '1' || 'yes' => true,
      'false' || '0' || 'no' => false,
      _ => fallback,
    };
  }
}
