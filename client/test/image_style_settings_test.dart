import 'package:dio/dio.dart';
import 'package:elum/core/app_status/app_status_repository.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/data/consent_document_repository.dart';
import 'package:elum/features/auth/domain/consent_bundle.dart';
import 'package:elum/features/guardian/presentation/guardian_settings_screen.dart';
import 'package:elum/features/guardian/presentation/image_style_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 보호자 설정의 `그림 방식` 줄과 선택 화면 (이슈 #458 · 임시 시안 opt1_A).
///
/// 서버 계약(#457): `PATCH /api/member/image-style` `{"imageStyle": "..."}`.
/// 엣지케이스 번호(E1…)는 이슈 #458 설계표와 같다.
void main() {
  useFigmaViewport();

  const patch = 'PATCH /api/member/image-style';

  late InMemoryStorage storage;
  late FakeAdapter adapter;

  /// 설정 화면 → 그림 방식 화면으로 들어가는 라우터를 통째로 올린다.
  Widget wrap({
    Object? patchResponse = const <String, Object?>{},
    Duration delay = Duration.zero,
    double textScale = 1.0,
    String? savedStyle,
  }) {
    storage = InMemoryStorage();
    // 설정 화면은 온보딩을 마친 뒤에만 열린다
    storage.setOnboardingCompleted(true);
    if (savedStyle != null) storage.setImageStyle(savedStyle);
    adapter = FakeAdapter({patch: patchResponse}, delay: delay);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;

    final router = GoRouter(
      initialLocation: Routes.guardianSettings,
      routes: [
        GoRoute(
          path: Routes.guardianSettings,
          builder: (context, state) => const GuardianSettingsScreen(),
        ),
        GoRoute(
          path: Routes.guardianImageStyle,
          builder: (context, state) => const ImageStyleSettingsScreen(),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        dioProvider.overrideWithValue(dio),
        consentBundleProvider.overrideWith((ref) async => ConsentBundle.bundled),
        appVersionProvider.overrideWith((ref) async => '1.47.0'),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    );
  }

  Future<void> openScreen(WidgetTester tester) async {
    await tester.tap(find.text('그림 방식'));
    await tester.pumpAndSettle();
  }



  group('설정 줄', () {


    testWidgets('E13 기존 설치 앱(로컬 값 없음)은 만화로 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.text('만화'), findsOneWidget);
    });




  });


  group('선택 화면', () {



    testWidgets('실사를 고르면 서버·로컬에 저장하고 설정으로 돌아가 알린다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('실사'));
      await tester.pumpAndSettle();

      expect(adapter.sentBodies[patch], {'imageStyle': 'REALISTIC'});
      expect(storage.imageStyle, 'REALISTIC');
      // 설정으로 돌아왔고 줄의 값이 바뀌었다
      expect(find.byType(ImageStyleSettingsScreen), findsNothing);
      expect(find.text('실사'), findsOneWidget);
      // 성공은 스낵바다 (실패만 팝업)
      expect(find.text('그림 방식을 바꿨어요'), findsOneWidget);
    });



    // E3 — 서버가 거절해도 화면은 살아 있고, 이전 값으로 되돌아가고, 에러 코드가 보인다.
    testWidgets('E3 서버가 실패하면 팝업(에러 코드)을 띄우고 이전 값으로 되돌린다', (tester) async {
      await tester.pumpWidget(wrap(patchResponse: const FakeHttpError(500)));
      await tester.pumpAndSettle();
      await openScreen(tester);

      await tester.tap(find.text('실사'));
      await tester.pumpAndSettle();

      // 서버가 코드를 주지 않으면 화면 코드에 상태가 붙는다 (E-STYLE/500)
      expect(find.textContaining('E-STYLE'), findsOneWidget);
      expect(find.textContaining('그림 방식을 저장하지 못했어요'), findsOneWidget);
      expect(storage.imageStyle, isNot('REALISTIC'));
      // 스낵바는 성공에만 쓴다
      expect(find.text('그림 방식을 바꿨어요'), findsNothing);

      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      // 선택 화면에 그대로 있고 고른 값이 표시된다
      expect(find.byType(ImageStyleSettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });



    // 실패 팝업이 "다시 시도해주세요"라고 하는데 같은 방식을 다시 누르면 아무 일도
    // 없으면 막다른 길이다.



  });
}
