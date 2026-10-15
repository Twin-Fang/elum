import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_motion.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/domain/routine_suggestion.dart';
import 'package:elum/features/guardian/presentation/reward_setup_screen.dart';
import 'package:elum/features/guardian/presentation/routine_input_screen.dart';
import 'package:elum/features/guardian/presentation/widgets/aurora_background.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/aurora_probe.dart';
import 'helpers/fake_reward_api.dart';
import 'helpers/test_storage.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/core/router/routes.dart';

/// 일과 만들기 흐름의 배경이 화면을 넘어갈 때 **부드럽게 번지는가** (이슈 #380).
///
/// 보상 설정(`1082:4709`)은 입력(`238:1643`)과 같은 두 원을 **분홍으로** 칠했다.
/// 화면마다 배경을 따로 그리면 새 화면이 밀려 들어오며 색 경계선이 화면을
/// 가로지른다. 흐름 전체가 배경 **하나**를 쓰고 그 색만 옮겨 가는지 본다.
///
/// 정지 골든으로는 안 보이는 것이라 **전환 중간 프레임의 색**을 숫자로 잰다.
void main() {
  useFigmaViewport();

  final light = AppColors.light;
  final inputTone = AuroraPalette.of(light, AuroraTone.input);
  /// 앱과 **같은 라우터**로 띄운다. 흐름을 감싸는 자리가 빠지면 여기서 잡힌다.
  Future<GoRouter> pumpFlow(
    WidgetTester tester, {
    bool reduceMotion = false,
    String start = Routes.routineInput,
  }) async {
    final router = createRouter()..go(start);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(_Repo()),
          routineSuggestionsProvider.overrideWith(
            (ref) async => RoutineSuggestion.fallback,
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(disableAnimations: reduceMotion),
              child: child!,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    return router;
  }

  /// 지금 화면에 깔린 오로라의 세 색 — Eclipse 시작 · Eclipse 끝 · Planet 시작.
  /// 흐름에 배경이 하나뿐이어야 하므로 원도 한 벌만 있어야 한다.
  List<Color> auroraColors(WidgetTester tester) => readAuroraColors(tester);

  /// 두 색 사이 값인가 — 채널마다 [a]와 [b] 사이에 있고 둘 다와 다르다.
  group('배경은 흐름 전체에 하나다', () {
  });

  group('흐름 순서대로 — 화면마다 색이 툭 바뀌지 않는다 (#380 결정 4)', () {
    /// 흐름 순서 (Figma 섹션 1049:4654). 로딩·추가질문도 이제 자기 색이 있다.
    const order = [
      AuroraTone.input,
      AuroraTone.reward,
      AuroraTone.preparing,
      AuroraTone.question,
      AuroraTone.generating,
      AuroraTone.none,
    ];

    /// 배경 한 장만 띄우고 색만 바꾼다 — 화면·라우터 없이 전환 자체를 잰다.
    for (var i = 0; i + 1 < order.length; i++) {
    }

  });

  group('색이 번진다', () {
  });

  group('전환', () {
  });

  group('흐름 안에서 빠져나가기', () {
    testWidgets('시스템 뒤로가기는 흐름째 닫지 않고 안에서 한 칸 돌아간다 (E3)', (tester) async {
      final router = await pumpFlow(tester);
      router.push(Routes.routineReward);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      // 안드로이드 뒤로 단추. 흐름이 ShellRoute 로 한 겹 들어가도 안쪽 화면이
      // 먼저 받아야 한다 — 흐름째 닫히면 만들던 일과가 말없이 사라진다.
      // 보상의 뒤로는 입력으로 한 칸이라 묻지 않는다 — 적은 것이 남는다 (#387 D3).
      await tester.binding.handlePopRoute();
      await tester.pump();
      await tester.pump(AppMotion.ambient + const Duration(milliseconds: 100));
      expect(find.text('일과 만들기를 그만둘까요?'), findsNothing);

      expect(find.byType(RoutineInputScreen), findsOneWidget);
      expect(find.byType(RewardSetupScreen), findsNothing);
      expect(auroraColors(tester), inputTone.visibleColors);
    });

  });

}

class _Repo with FakeRewardApi implements RoutineRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
