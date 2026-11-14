import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/l10n/app_l10n.dart';
import 'core/layout/adaptive_screen_scale.dart';
import 'core/layout/app_text_scale.dart';
import 'core/theme/app_theme.dart';
import 'features/lock_screen/presentation/lock_screen_page.dart';

/// 잠금화면 엔진 진입점 (Android LockScreenEngine 이 서비스 시작 때 실행)
/// 네트워크·로그인·저장소 초기화 없음: 요약은 네이티브 채널로만 읽음 (앱 엔진과 같은 화면 배율·글자 배율·언어)
@pragma('vm:entry-point')
Future<void> lockScreenMain() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: LockScreenApp()));
}

/// 잠금화면 앱: 테마·언어·배율만 앱과 같게, 화면은 카드 하나
class LockScreenApp extends StatelessWidget {
  const LockScreenApp({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppL10n.routerArgs(
      forcedLocale: null,
      devToolsEnabled: false,
      inner: (context, child) => child ?? const SizedBox.shrink(),
    );
    return AdaptiveScreenScale(
      // 앱 엔진과 같은 기준 (Figma iPhone 16)
      baseDesignSize: const Size(393, 852),
      minTextAdapt: true,
      builder: (context, child) => MaterialApp(
        onGenerateTitle: l10n.onGenerateTitle,
        theme: AppTheme.light,
        supportedLocales: l10n.supportedLocales,
        localizationsDelegates: l10n.localizationsDelegates,
        localeListResolutionCallback: l10n.localeListResolutionCallback,
        debugShowCheckedModeBanner: false,
        builder: (context, child) =>
            AppTextScale(child: l10n.builder(context, child)),
        home: const LockScreenPage(),
      ),
    );
  }
}
