import 'package:elum/core/layout/adaptive_screen_scale.dart';
import 'package:elum/core/router/routes.dart';
import 'package:elum/core/router/routes_guardian.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/ads/application/ad_gate.dart';
import 'package:elum/features/ads/data/ad_banner_loader.dart';
import 'package:elum/features/ads/data/ad_strip_loader.dart';
import 'package:elum/features/ads/presentation/ad_bottom_strip_slot.dart';
import 'package:elum/core/config/ad_ids.dart';
import 'package:elum/features/guardian/application/routine_providers.dart';
import 'package:elum/features/guardian/presentation/navigation/guardian_bottom_nav.dart';
import 'package:elum/features/guardian/presentation/navigation/guardian_side_nav.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/shared/models/action_card.dart';
import 'package:elum/shared/models/routine.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/adaptive_test_app.dart';
import 'helpers/stub_routine_repository.dart';
import 'helpers/test_storage.dart';

/// 보호자 하단 바(폰)·옆 메뉴(태블릿) 4칸 (#798).
///
/// 깨지면: 칸을 눌러도 다른 칸으로 안 가거나, 내정보에 뒤로가기가 남아 앱이 갇히거나,
/// 설정 칸에 광고 띠가 떠 회원탈퇴 줄 옆에서 오탭이 난다.
void main() {
  const phone = Size(393, 852);
  const tablet = Size(1024, 768);

  Routine routine(String id) => Routine(
    id: id,
    title: '일과 $id',
    status: 'CONFIRMED',
    progressPercent: 0,
    steps: const [ActionCard(id: 'c', stepOrder: 1, description: '단계')],
  );

  /// 일과 [count]개를 오늘 목록으로 준다. 5개 이상이어야 광고 띠가 나온다.
  Future<GoRouter> pumpShell(
    WidgetTester tester, {
    required Size size,
    int routineCount = 0,
    String start = Routes.guardian,
  }) async {
    setTestWindowSize(tester, size);
    // 태블릿 홈 장면의 끝없는 움직임이 pumpAndSettle 을 막는다
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(binding.platformDispatcher.clearAccessibilityFeaturesTestValue);
    final routines = [for (var i = 0; i < routineCount; i++) routine('$i')];
    final router = GoRouter(initialLocation: start, routes: guardianRoutes());
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 일과관리 칸이 서버 없이 빈 목록을 받게
          routineLibraryProvider.overrideWith((ref) async => const <Routine>[]),
          testStorageOverride(onboardingCompleted: true, nickname: '하늘이'),
          routineRepositoryProvider.overrideWithValue(StubRoutineRepository()),
          todayRoutinesProvider.overrideWith((ref) async => routines),
          pastRoutinesProvider.overrideWith((ref) async => const []),
          myRoutinesProvider.overrideWith((ref) async => routines),
          memberProvider.overrideWith((ref) async => null),
          adsEnabledProvider.overrideWithValue(true),
          adStripLoaderProvider.overrideWithValue(_NoAdStrip()),
        ],
        child: AdaptiveScreenScale(
          baseDesignSize: const Size(393, 852),
          builder: (context, _) =>
              MaterialApp.router(theme: AppTheme.light, routerConfig: router),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return router;
  }

  String topOf(GoRouter router) =>
      router.routerDelegate.currentConfiguration.last.matchedLocation;

  group('폰', () {
    testWidgets('하단 바에 칸 넷이 있고 홈이 고른 칸이다', (tester) async {
      await pumpShell(tester, size: phone);

      expect(find.byType(GuardianBottomNav), findsOneWidget);
      expect(find.byType(GuardianSideNav), findsNothing);
      for (final label in ['홈', '일과관리', '이야기', '내정보']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    });

    testWidgets('칸을 누르면 그 칸으로 가고 고른 칸 아이콘이 꽉 찬다', (tester) async {
      final router = await pumpShell(tester, size: phone);

      await tester.tap(find.bySemanticsLabel('일과관리'));
      await tester.pumpAndSettle();
      expect(topOf(router), Routes.guardianManage);
      expect(find.text('아직 만든 일과가 없어요'), findsOneWidget);
      expect(find.byIcon(Icons.folder_rounded), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('이야기'));
      await tester.pumpAndSettle();
      expect(topOf(router), Routes.guardianTalk);

      await tester.tap(find.bySemanticsLabel('홈'));
      await tester.pumpAndSettle();
      expect(topOf(router), Routes.guardian);
    });

    testWidgets('내정보 칸은 설정 첫 화면이라 뒤로가기가 없다', (tester) async {
      final router = await pumpShell(tester, size: phone);

      await tester.tap(find.bySemanticsLabel('내정보'));
      await tester.pumpAndSettle();

      expect(topOf(router), Routes.guardianSettings);
      expect(find.bySemanticsLabel('뒤로 가기'), findsNothing);
      expect(find.byType(GuardianBottomNav), findsOneWidget);
    });

    testWidgets('일과가 5개 이상이면 하단 바 아래에 광고 띠 자리가 열리고 내정보에는 없다', (tester) async {
      final router = await pumpShell(tester, size: phone, routineCount: 5);
      expect(find.byType(AdBottomStripSlot), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('내정보'));
      await tester.pumpAndSettle();
      expect(
        find.byType(AdBottomStripSlot),
        findsNothing,
        reason: '설정은 회원탈퇴 줄과 가까워 광고를 두지 않는다',
      );
      expect(topOf(router), Routes.guardianSettings);
    });

    testWidgets('일과가 4개 이하면 광고 띠 자리가 없다', (tester) async {
      await pumpShell(tester, size: phone, routineCount: 4);
      expect(find.byType(AdBottomStripSlot), findsNothing);
    });
  });

  group('태블릿', () {
    testWidgets('왼쪽 옆 메뉴에 칸 넷과 이룸이 화면 버튼이 있다', (tester) async {
      await pumpShell(tester, size: tablet);

      expect(find.byType(GuardianSideNav), findsOneWidget);
      expect(find.byType(GuardianBottomNav), findsNothing);
      for (final label in ['홈', '일과관리', '이야기', '내정보']) {
        expect(find.text(label), findsWidgets, reason: label);
      }
      expect(find.text('이룸이 화면'), findsOneWidget);
      // 화면 낭독기로도 칸과 이룸이 화면 입구를 찾을 수 있다
      for (final label in ['홈', '일과관리', '이야기', '내정보']) {
        expect(find.bySemanticsLabel(label), findsOneWidget, reason: label);
      }
      expect(find.bySemanticsLabel('이룸이 화면으로 가기'), findsOneWidget);
    });

    testWidgets('옆 메뉴 칸을 누르면 그 칸으로 간다', (tester) async {
      final router = await pumpShell(tester, size: tablet);

      await tester.tap(
        find.descendant(
          of: find.byType(GuardianSideNav),
          matching: find.text('일과관리'),
        ),
      );
      await tester.pumpAndSettle();

      expect(topOf(router), Routes.guardianManage);
    });

    testWidgets('창이 좁아지면(분할 화면) 하단 바로 바뀐다', (tester) async {
      await pumpShell(tester, size: const Size(500, 800));

      expect(find.byType(GuardianBottomNav), findsOneWidget);
      expect(find.byType(GuardianSideNav), findsNothing);
    });
  });
}

/// 광고가 없는 환경: 띠 자리(위젯)만 보고 실제 광고는 받지 않는다
class _NoAdStrip implements AdStripLoader {
  @override
  Future<LoadedBanner?> load(
    AdPlacement placement,
    AdStripColors colors,
  ) async => null;
}
