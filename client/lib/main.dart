import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/dev/dev_log_buffer.dart';
import 'core/logger/app_logger.dart';
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
  if (AppConfig.showDevTools) DevLogBuffer.install();

  // 저장소는 앱 시작 시 한 번만 초기화하고 provider로 주입한다.
  final storage = await SharedPrefsStorage.create();
  AppLogger.storageRead('SharedPreferences', 'initialized');

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
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        tokenStoreProvider.overrideWithValue(tokens),
      ],
      child: const ElumApp(),
    ),
  );
}
