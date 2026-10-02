import 'package:elum/core/l10n/app_l10n.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 번역 delegate·Figma 기준 화면 크기(393×852)·`appL10n` 동기화를 갖춘 앱으로 [home] 을 띄운다.
///
/// 기존 테스트는 `MaterialApp` 을 제각각 만들고 `context.l10n` 의 `ko` 대체로 돈다. 이 헬퍼는
/// **다른 언어로 띄워야 하는 새 테스트**(넘침 검사 등)를 위한 것이다.
///
/// 언어 배선(delegate·`syncAppL10n`·글꼴 테마)은 앱과 같은 `AppL10n.routerArgs` 를 그대로 써서
/// 복제하지 않는다. 다만 앱은 `MaterialApp.router` 이고 이 헬퍼는 `MaterialApp(home:)` 이다.
///
/// - [locale]: 앱 언어. 기본 `ko`. `routerArgs` 의 강제 언어로 넘기므로 항상 이 언어가 이긴다.
/// - [theme]: 기본은 [locale] 에 맞는 `AppTheme.lightFor`. 넘기면 비 ko 언어에서도 이 테마가 이긴다.
///   **보통은 넘기지 않는다** - 기본 경로(`MaterialApp.theme` + 앱과 같은 `themed`)가 앱과 가장 가깝다.
/// - [textScale]: 글자 배율. 기본 1.0. 안 쓰는 테스트는 그대로 돈다(가산). 넘침 검사가 1.5·2.0 을
///   각 테스트에서 직접 걸다 `addTearDown` 을 빼먹어 다음 테스트로 새는 것을 막으려고 헬퍼가 걸고 원복한다.
/// - [wrap]: `ProviderScope` 같은 바깥 껍질을 씌울 때. `(app) => ProviderScope(overrides: [...], child: app)`
///
/// 화면 크기는 호출 쪽이 `useFigmaViewport()` 로 맞춘다 (`test/helpers/device_viewport.dart`).
Future<void> pumpWithLocale(
  WidgetTester tester,
  Widget home, {
  Locale locale = const Locale('ko'),
  ThemeData? theme,
  double textScale = 1.0,
  Widget Function(Widget app)? wrap,
}) async {
  if (textScale != 1.0) {
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
  final l10n = AppL10n.routerArgs(
    forcedLocale: locale,
    // 개발자 도구 빌드 설정과 무관하게 테스트는 항상 [locale] 을 강제한다
    devToolsEnabled: true,
    // 앱 고유 래퍼는 없다. [theme] 가 있으면 글꼴 테마(바깥층)보다 안쪽에서 덮어쓴다
    inner: (context, child) {
      final body = child ?? const SizedBox.shrink();
      return theme == null ? body : Theme(data: theme, child: body);
    },
  );

  Widget app = ScreenUtilInit(
    designSize: const Size(393, 852),
    minTextAdapt: true,
    builder: (context, _) => MaterialApp(
      theme: theme ?? AppTheme.lightFor(locale),
      locale: l10n.locale,
      supportedLocales: l10n.supportedLocales,
      localizationsDelegates: l10n.localizationsDelegates,
      localeListResolutionCallback: l10n.localeListResolutionCallback,
      onGenerateTitle: l10n.onGenerateTitle,
      builder: l10n.builder,
      home: home,
    ),
  );
  if (wrap != null) app = wrap(app);
  await tester.pumpWidget(app);
  await tester.pump();
}
