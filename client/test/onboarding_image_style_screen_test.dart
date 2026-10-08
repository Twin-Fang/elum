import 'package:dio/dio.dart';
import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/presentation/image_style_screen.dart';
import 'package:elum/features/onboarding/presentation/widgets/image_style_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/fake_dio.dart';
import 'helpers/semantics_audit.dart';
import 'package:elum/app/dio_provider.dart';
import 'package:elum/core/storage/in_memory_storage.dart';
import 'package:elum/core/router/routes.dart';

/// 온보딩의 그림 방식 단계.
///
/// 캐릭터 → **그림 방식** → 비밀암호. 기본 그림이 처음부터 골라져 있고 건너뛰기는 없다.
/// 선택은 온보딩이 끝날 때 한꺼번에 저장한다 — 이 화면은 상태에만 담는다.
void main() {
  useFigmaViewport();

  late InMemoryStorage storage;
  late FakeAdapter adapter;
  late ProviderContainer container;

  Widget wrap({double textScale = 1.0}) {
    storage = InMemoryStorage();
    adapter = FakeAdapter(const {});
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;

    final router = GoRouter(
      initialLocation: Routes.onboardingCharacter,
      routes: [
        GoRoute(
          path: Routes.onboardingCharacter,
          builder: (context, state) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => context.push(Routes.onboardingImageStyle),
                child: const Text('캐릭터 화면'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: Routes.onboardingImageStyle,
          builder: (context, state) => const ImageStyleScreen(),
        ),
        GoRoute(
          path: Routes.onboardingPin,
          builder: (context, state) => const Scaffold(body: Text('PIN 화면')),
        ),
      ],
    );

    container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        dioProvider.overrideWithValue(dio),
      ],
    );
    addTearDown(container.dispose);

    return UncontrolledProviderScope(
      container: container,
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

  Future<void> open(WidgetTester tester) async {
    await tester.pumpAndSettle();
    await tester.tap(find.text('캐릭터 화면'));
    await tester.pumpAndSettle();
  }

  testWidgets('제목·설명·선택지·다음이 보이고 건너뛰기는 없다', (tester) async {
    await tester.pumpWidget(wrap());
    await open(tester);

    expect(find.text('카드 그림은 어떤 방식으로\n만들까요?'), findsOneWidget);
    expect(find.text('나중에 설정에서 바꿀 수 있어요'), findsOneWidget);
    for (final s in ImageStyle.values) {
      expect(find.text(s.label), findsOneWidget);
    }
    expect(find.text('다음'), findsOneWidget);
    expect(find.text('건너뛰기'), findsNothing);
  });

  testWidgets('기본 그림이 맨 위에 있고 만화·실사 순이다', (tester) async {
    await tester.pumpWidget(wrap());
    await open(tester);

    final ys = ImageStyle.values
        .map((s) => tester.getTopLeft(find.text(s.label)).dy)
        .toList();
    expect(ImageStyle.values.first, ImageStyle.photoOnly);
    expect(ys, [...ys]..sort());
  });

  testWidgets('처음부터 기본 그림이 골라져 있어 바로 다음으로 갈 수 있다', (tester) async {
    await tester.pumpWidget(wrap());
    await open(tester);

    expect(container.read(onboardingProvider).imageStyle, ImageStyle.photoOnly);
    expect(tester.widget<ElumButton>(find.byType(ElumButton)).onPressed, isNotNull);
  });

  testWidgets('실사를 고르고 다음을 누르면 비밀암호로 가고 고른 값이 남는다', (tester) async {
    await tester.pumpWidget(wrap());
    await open(tester);

    await tester.tap(find.text('실사'));
    await tester.pumpAndSettle();
    expect(container.read(onboardingProvider).imageStyle, ImageStyle.realistic);
    // 온보딩에서는 서버·로컬에 바로 쓰지 않는다 — 끝날 때 한꺼번에 저장한다
    expect(adapter.calls, isEmpty);
    expect(storage.imageStyle, isNull);

    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('PIN 화면'), findsOneWidget);
    expect(container.read(onboardingProvider).imageStyle, ImageStyle.realistic);
  });

  // E7 — 뒤로 갔다 와도 고른 값이 남는다.
  testWidgets('E7 뒤로가기로 캐릭터 화면에 돌아갔다 다시 와도 고른 값이 남는다', (tester) async {
    await tester.pumpWidget(wrap());
    await open(tester);

    await tester.tap(find.text('실사'));
    await tester.pumpAndSettle();
    await tester.tap(find.bySemanticsLabel('뒤로 가기'));
    await tester.pumpAndSettle();
    expect(find.text('캐릭터 화면'), findsOneWidget);
    expect(adapter.calls, isEmpty);

    await tester.tap(find.text('캐릭터 화면'));
    await tester.pumpAndSettle();
    final realistic = find.byWidgetPredicate(
      (w) => w is ImageStyleOptionCard && w.style == ImageStyle.realistic,
    );
    expect(tester.widget<ImageStyleOptionCard>(realistic).isSelected, isTrue);
  });

  testWidgets('낭독기가 라디오 선택 상태를 읽는다', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(wrap());
    await open(tester);

    expect(
      tester.getSemantics(
        find.bySemanticsLabel('기본 그림, 간단한 그림 기호가 들어가요. 사진으로 바꿀 수 있어요'),
      ),
      containsSemantics(isChecked: true, isInMutuallyExclusiveGroup: true),
    );
    expect(unnamedTapTargets(tester), isEmpty);
    handle.dispose();
  });

  testWidgets('E8 글자를 200% 로 키워도 넘치지 않고 다음이 남는다', (tester) async {
    await tester.pumpWidget(wrap(textScale: 2.0));
    await open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('다음'), findsOneWidget);
  });

  testWidgets('E9 작은 폰(320×568)에서도 넘치지 않는다', (tester) async {
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpWidget(wrap());
    await open(tester);

    expect(tester.takeException(), isNull);
    expect(find.text('다음'), findsOneWidget);
  });
}
