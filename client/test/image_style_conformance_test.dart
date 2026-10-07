@Tags(['golden'])
library;

import 'package:dio/dio.dart';
import 'package:elum/core/network/dio_client.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/domain/character.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/presentation/image_style_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/precache_images.dart';

/// 온보딩 그림 방식의 **시안 대조용** 렌더 (#494).
///
/// 시안 `그림방식` 1274:9883(만화 선택) · 1274:10129(직접 찍은 사진 선택). 골든은 앱 렌더이고
/// 시안 export 와는 `tool/figma_diff.py` 로 맞댄다 (`settings_conformance_test.dart` 와 같은 방식).
///
/// ⚠️ 지금 앱은 시안과 일부러 다르다 — 기본 그림이 맨 위(기본값)이고 건너뛰기가 없으며 세 번째
/// 이름·예시가 `기본 그림`·픽토그램이다. 시안이 갱신되면 다시 맞댄다.
///
/// 시안 만화 예시는 포포(여우)다. 앱은 온보딩에서 고른 친구를 그리므로 여우를 골라 맞춘다.
const _deviceInsets = EdgeInsets.only(top: 59, bottom: 21);

Future<void> _pump(WidgetTester tester, ImageStyle selected) async {
  final storage = InMemoryStorage();
  final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
    ..httpClientAdapter = FakeAdapter(const {});
  final container = ProviderContainer(
    overrides: [
      localStorageProvider.overrideWithValue(storage),
      dioProvider.overrideWithValue(dio),
    ],
  );
  addTearDown(container.dispose);
  container.read(onboardingProvider.notifier)
    ..setCharacter(CardCharacter.fox)
    ..setImageStyle(selected);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(padding: _deviceInsets),
            child: child!,
          ),
          routerConfig: GoRouter(
            initialLocation: '/x',
            routes: [
              GoRoute(
                path: '/x',
                builder: (context, state) => const ImageStyleScreen(),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await precacheAllImages(tester);
  await tester.pumpAndSettle();
}

void main() {
  useFigmaViewport();

  testWidgets('그림 방식 — 만화 선택 (Figma 1274:9883)', (tester) async {
    await _pump(tester, ImageStyle.cartoon);
    await expectLater(
      find.byType(ImageStyleScreen),
      matchesGoldenFile('figma/imagestyle_cartoon_1274-9883.png'),
    );
  });

  testWidgets('그림 방식 — 직접 찍은 사진 선택 (Figma 1274:10129)', (tester) async {
    await _pump(tester, ImageStyle.photoOnly);
    await expectLater(
      find.byType(ImageStyleScreen),
      matchesGoldenFile('figma/imagestyle_photo_1274-10129.png'),
    );
  });
}
