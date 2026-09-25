import 'package:elum/core/state/provider_retry.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/guardian/data/routine_repository.dart';
import 'package:elum/features/guardian/presentation/draft_routines_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_storage.dart';

/// 실패한 provider 를 저절로 다시 부르지 않는다 (이슈 #429).
///
/// Riverpod 3 은 실패한 provider 를 **기본으로 재시도**한다 (간격을 늘려 가며
/// 여러 번). 요청은 0.02초 만에 실패했는데 화면은 약 40초 동안 로딩을 보여 줬다
/// (실기기 실측). 재시도가 필요하면 화면의 `다시 시도`가 한다.
///
/// 기존 테스트는 `pumpAndSettle()` 이 가상 시간을 끝까지 돌려 이 대기를 가렸다.
/// 여기서는 **실패 직후** 를 본다.
void main() {
  Future<void> pumpDrafts(WidgetTester tester, {required bool appRetry}) async {
    await tester.pumpWidget(
      ProviderScope(
        retry: appRetry ? elumProviderRetry : null,
        overrides: [
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          myRoutinesProvider.overrideWith(
            (ref) async => throw const AppFailure(fault: NetworkFault.offline),
          ),
        ],
        child: ScreenUtilInit(
          designSize: const Size(393, 852),
          builder: (context, _) => MaterialApp.router(
            theme: AppTheme.light,
            routerConfig: GoRouter(
              initialLocation: Routes.guardianDrafts,
              routes: [
                GoRoute(
                  path: Routes.guardianDrafts,
                  builder: (context, state) => const DraftRoutinesScreen(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('앱 설정으로는 실패가 바로 실패 화면이 된다', (tester) async {
    await pumpDrafts(tester, appRetry: true);

    expect(find.text('임시저장을 불러오지 못했어요'), findsOneWidget);
  });

  // 원인을 고정해 둔다 — 기본값이면 같은 순간에 아직 로딩이다.
  testWidgets('Riverpod 기본값이면 같은 순간에 아직 실패 화면이 없다', (tester) async {
    await pumpDrafts(tester, appRetry: false);

    expect(find.text('임시저장을 불러오지 못했어요'), findsNothing);
    // 남은 재시도 타이머를 흘려 보내 테스트가 깔끔히 끝나게 한다.
    await tester.pump(const Duration(minutes: 2));
  });
}
