import 'package:elum/core/router/routes.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/presentation/example_category_screen.dart';
import 'package:elum/shared/models/routine_example_category.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';

/// 온보딩 예시 분류 화면 (#803) — 목표 화면 자리
void main() {
  useFigmaViewport();

  bool isNextEnabled(WidgetTester tester) =>
      tester.widget<ElumButton>(find.byType(ElumButton)).onPressed != null;

  late ProviderContainer container;

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.onboardingExampleCategories,
      routes: [
        GoRoute(
          path: Routes.onboardingExampleCategories,
          builder: (context, state) => const ExampleCategoryScreen(),
        ),
        GoRoute(
          path: Routes.onboardingCharacter,
          builder: (context, state) => const Scaffold(body: Text('캐릭터 화면')),
        ),
      ],
    );
    container = ProviderContainer(overrides: [testStorageOverride()]);
    return UncontrolledProviderScope(
      container: container,
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) =>
            MaterialApp.router(theme: AppTheme.light, routerConfig: router),
      ),
    );
  }

  testWidgets('하나도 고르지 않으면 다음이 비활성이다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(isNextEnabled(tester), isFalse);
  });

  testWidgets('여러 개 고를 수 있고 다음으로 캐릭터 화면에 간다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('아침·저녁 준비'));
    // 칩이 색을 바꾸는 동안에는 다음 탭이 먹지 않는다
    await tester.pumpAndSettle();
    await tester.tap(find.text('밖에서 해 보기'));
    await tester.pumpAndSettle();

    expect(isNextEnabled(tester), isTrue);
    expect(container.read(onboardingProvider).exampleCategories, {
      RoutineExampleCategory.morningEvening,
      RoutineExampleCategory.outside,
    });

    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();
    expect(find.text('캐릭터 화면'), findsOneWidget);
  });

  testWidgets('건너뛰기는 고른 것을 비우고 캐릭터 화면에 간다 — 예시를 만들지 않는다', (tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('학교·공부'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();

    expect(find.text('캐릭터 화면'), findsOneWidget);
    expect(container.read(onboardingProvider).exampleCategories, isEmpty);
  });

  group('complete() 가 예시 대기값을 남긴다', () {
    test('고른 분류가 저장소에 남는다 — 홈이 이것을 보고 예시를 만든다', () async {
      final container = ProviderContainer(overrides: [testStorageOverride()]);
      addTearDown(container.dispose);
      final notifier = container.read(onboardingProvider.notifier);
      notifier.setExampleCategories({RoutineExampleCategory.houseSelf});

      await notifier.complete();

      final storage = container.read(localStorageProvider);
      expect(storage.pendingExampleCategories, ['HOUSE_SELF']);
      // 저장 시점에 선택된 이룸이에만 만든다
      expect(storage.pendingExampleProfileId, storage.selectedProfileId);
      expect(storage.exampleSeedAttempts, 0);
    });

    test('건너뛰었으면 빈 목록 — 홈이 예시를 요청하지 않는다', () async {
      final container = ProviderContainer(overrides: [testStorageOverride()]);
      addTearDown(container.dispose);

      await container.read(onboardingProvider.notifier).complete();

      expect(
        container.read(localStorageProvider).pendingExampleCategories,
        isEmpty,
      );
    });
  });
}
