import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/auth/data/auth_repository.dart';
import 'package:elum/features/onboarding/presentation/name_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/svg_finder.dart';
import 'helpers/test_storage.dart';

/// 이름 화면은 Figma `온보딩_이름` 두 프레임을 따른다.
///
/// - 204:991  빈 상태 (placeholder · CTA disable)
/// - 204:1174 입력 완료 상태 (입력값 · CTA enable)
///
/// 두 프레임은 같은 화면의 상태 전이다. 별도 화면을 만들지 않고
/// 상태가 올바르게 갈리는지를 여기서 고정한다.
void main() {
  /// 이름 입력 = 로그인이다. 실서버를 타지 않도록 결과를 정해 넣는다. (이슈 #19)
  Widget buildSubject({AuthOutcome outcome = AuthOutcome.created}) {
    final router = GoRouter(
      initialLocation: Routes.onboardingName,
      routes: [
        GoRoute(
          path: Routes.onboardingName,
          builder: (context, state) => const NameScreen(),
        ),
        GoRoute(
          path: Routes.onboardingGoals,
          builder: (context, state) => const Scaffold(body: Text('목표 화면')),
        ),
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('보호자 홈')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        testStorageOverride(),
        authRepositoryProvider.overrideWithValue(_FakeAuth(outcome)),
      ],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, child) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// CTA 활성 여부는 onPressed가 null인지로 판정한다.
  /// 색상값을 직접 비교하면 토큰이 바뀔 때마다 테스트가 깨진다.
  bool isNextButtonEnabled(WidgetTester tester) {
    final button = tester.widget<ElumButton>(find.byType(ElumButton));
    return button.onPressed != null;
  }

  group('빈 상태 (204:991)', () {
    testWidgets('Figma 문구 3종이 보인다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('아이를 어떻게\n불러드릴까요?'), findsOneWidget);
      expect(find.text('정확한 실명이 아니어도 괜찮아요'), findsOneWidget);
      expect(find.text('이름을 입력해주세요'), findsOneWidget);
    });

    testWidgets('필드 아이콘은 직접 그리지 않고 SVG 에셋으로 렌더링한다', (tester) async {
      // 노란 원과 아이콘이 SVG 안에 함께 있다.
      // Container + BoxDecoration으로 흉내내면 형태가 어긋난다.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.inputFieldIconChildName), findsOneWidget);
    });

    testWidgets('입력 전에는 다음 버튼이 비활성이다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      expect(find.text('다음'), findsOneWidget);
      expect(isNextButtonEnabled(tester), isFalse);
    });
  });

  group('입력 완료 상태 (204:1174)', () {
    testWidgets('한 글자 입력하면 다음 버튼이 활성된다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      expect(isNextButtonEnabled(tester), isTrue);
    });

    testWidgets('입력값이 화면에 보이고 notifier에도 반영된다', (tester) async {
      // placeholder Text는 트리에 남는다 — Flutter가 opacity로 숨기지 언마운트하지 않는다.
      // 그래서 "hint가 사라졌는가"가 아니라 "입력값이 렌더링되는가"를 본다.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      expect(find.text('하늘이'), findsOneWidget);

      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.controller?.text, '하늘이');
    });

    testWidgets('입력 후에도 필드 아이콘은 그대로 있다', (tester) async {
      // 204:1174에도 같은 아이콘(Group 4)이 있다.
      // 상태가 바뀌었다고 아이콘이 사라지면 안 된다.
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      expect(svgWithAsset(AppAssets.inputFieldIconChildName), findsOneWidget);
    });

    testWidgets('공백만 입력하면 활성되지 않는다', (tester) async {
      // canProceedFromName이 trim()으로 판단한다
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '   ');
      await tester.pumpAndSettle();

      expect(isNextButtonEnabled(tester), isFalse);
    });

    testWidgets('입력 후 다음을 누르면 목표 화면으로 간다', (tester) async {
      await tester.pumpWidget(buildSubject());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();

      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('목표 화면'), findsOneWidget);
    });

    testWidgets('이미 있는 이름이면 보호자 홈으로 바로 간다', (tester) async {
      // 아이 이름이 곧 아이디다. 기존 계정이면 온보딩을 다시 받지 않는다.
      await tester.pumpWidget(buildSubject(outcome: AuthOutcome.restored));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이별');
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('보호자 홈'), findsOneWidget);
    });

    testWidgets('로그인에 실패하면 화면에 머물고 에러 코드를 보여준다', (tester) async {
      await tester.pumpWidget(buildSubject(outcome: AuthOutcome.failed));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이');
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.text('목표 화면'), findsNothing);
      // 제보를 추적하려면 화면에 식별자가 있어야 한다
      expect(find.textContaining('E-AUTH'), findsOneWidget);
    });

    testWidgets('네트워크가 끊기면 이름이 아니라 연결을 안내한다', (tester) async {
      // 이름 문제로 안내하면 사용자가 이름만 계속 고치게 된다.
      await tester.pumpWidget(buildSubject(outcome: AuthOutcome.offline));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), '하늘이별');
      await tester.pumpAndSettle();
      await tester.tap(find.text('다음'));
      await tester.pumpAndSettle();

      expect(find.textContaining('E-NET'), findsOneWidget);
      expect(find.textContaining('E-AUTH'), findsNothing);
    });
  });
}

/// 네트워크를 타지 않는 인증 대역.
class _FakeAuth implements AuthRepository {
  _FakeAuth(this.outcome);

  final AuthOutcome outcome;

  @override
  Future<AuthOutcome> signInWithName(String childName) async => outcome;

  @override
  bool get hasToken =>
      outcome != AuthOutcome.failed && outcome != AuthOutcome.offline;

  @override
  Future<String?> reauthenticate() async => null;

  @override
  Future<void> deleteAccount() async {}
}
