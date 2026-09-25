import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/config/client_tuning.dart';
import 'core/dev/dev_log_buffer.dart';
import 'core/dev/dev_log_file.dart';
import 'core/logger/app_logger.dart';
import 'core/state/provider_retry.dart';
import 'core/storage/local_storage.dart';
import 'core/storage/token_store.dart';
import 'features/auth/data/auth_repository.dart';
import 'features/auth/data/oauth_sdk.dart';
import 'features/onboarding/application/onboarding_notifier.dart';

Future<void> main() async {
  AppLogger.appStarted();

  WidgetsFlutterBinding.ensureInitialized();

  // 환경변수를 먼저 읽는다 — 저장소·네트워크가 설정값에 의존한다.
  await AppConfig.load();

  // 실기기·릴리스 빌드에는 콘솔이 없다. 앱 안에서 로그를 보려면 미리 가로채야
  // 하므로 초기화 직후에 건다. (이슈 #13)
  // 개발자 도구를 켠 빌드에서만 로그를 붙잡는다.
  // 파일(2MB 상한)에도 남겨 앱이 죽어도 직전 로그가 남는다 (이슈 #219).
  // 파일 열기가 실패해도 앱 시작을 막지 않는다 — 로그는 보조 수단이다.
  if (AppConfig.showDevTools) {
    await DevLogFile.init();
    DevLogBuffer.install();
  }

  // 저장소는 앱 시작 시 한 번만 초기화하고 provider로 주입한다.
  final storage = await SharedPrefsStorage.create();
  AppLogger.storageRead('SharedPreferences', 'initialized');

  // 지난번 서버에서 받은 시간값으로 시작한다. 서버에 닿기 전 첫 요청(Dio 생성)부터
  // 이 값을 쓴다. 한 번도 받은 적 없으면 코드 기본값 그대로다.
  final cachedTuning = ClientTuning.tryParseJson(storage.cachedClientTuningJson);
  if (cachedTuning != null) {
    AppConfig.applyTuning(cachedTuning, source: TuningSource.cached);
  }

  // 토큰은 보안 저장소에 있어 읽기가 비동기다. 첫 화면이 세션 유무를 바로
  // 판단할 수 있도록 여기서 미리 읽어 메모리에 올린다.
  final tokens = SecureTokenStore();
  await tokens.load();

  // QA 세션 주입 (디버그 빌드 전용). 로그인 뒤 화면을 실기기로 밟기 위한 통로다.
  // 이미 세션이 있으면 건드리지 않는다 — 실제 로그인을 덮어쓰면 안 된다.
  if (!tokens.hasSession && AppConfig.devRefreshToken.isNotEmpty) {
    await tokens.save(
      accessToken: AppConfig.devAccessToken,
      refreshToken: AppConfig.devRefreshToken,
    );
    debugPrint('[QA] .env의 토큰으로 세션을 주입했습니다 (디버그 빌드 전용)');
  }

  // 카카오 SDK는 초기화 전에 로그인을 부르면 예외가 난다.
  // 실패해도 다른 제공자는 동작해야 하므로 앱 시작을 막지 않는다.
  await OAuthSdk.initialize();

  runApp(
    ProviderScope(
      // 실패한 provider 를 저절로 다시 부르지 않는다 — 실패를 40초 늦게 보여 줬다 (#429).
      retry: elumProviderRetry,
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
      child: const ElumApp(),
    ),
  );
}
