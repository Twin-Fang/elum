import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/presentation/pin_screen.dart';
import 'package:elum/features/onboarding/presentation/widgets/pin_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/device_viewport.dart';
import 'helpers/test_storage.dart';
import 'package:elum/core/router/routes.dart';

/// Figma `온보딩_비밀번호`(238:1909) / `_입력`(238:1997) / `_재확인`(238:2767) 정합 테스트.
///
/// PIN 불일치는 아동도 볼 수 있는 화면이라 경고색·에러 아이콘을 쓰지 않는다.
/// 그 규칙을 테스트로 고정한다.
///
/// 자동 전환(이슈 #101): 1단계 4자리 → 자동으로 재입력 단계. 2단계 4자리 →
/// 자동 검증(불일치면 1단계 리셋). 저장만 CTA 버튼으로 확정한다.
void main() {
  // .w/.h 검증에는 Figma 기준 뷰포트가 필요하다 (기본 800×600이면 스케일이 어긋난다)
  useFigmaViewport();

  /// CTA가 **화면에 있는가**. 시안은 완료 전에 버튼 자리를 비워 둔다 (이슈 #231).
  bool hasCta(WidgetTester tester) =>
      find.byType(ElumButton).evaluate().isNotEmpty;

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.onboardingPin,
      routes: [
        GoRoute(
          path: Routes.onboardingPin,
          builder: (context, state) => const PinScreen(),
        ),
        // PIN 완료 후 실제 목적지는 보호자 홈이다 (pin_screen.dart의 context.go).
        // 예전에는 SetupDoneScreen을 거쳤으나 제거됐다 (fc9e5a5).
        GoRoute(
          path: Routes.guardian,
          builder: (context, state) => const Scaffold(body: Text('완료 화면')),
        ),
      ],
    );

    return ProviderScope(
      overrides: [testStorageOverride()],
      child: ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (context, _) => MaterialApp.router(
          theme: AppTheme.light,
          routerConfig: router,
        ),
      ),
    );
  }

  /// 시스템 키패드로 PIN을 입력한다.
  /// 자체 키패드가 아니라 OS 키패드를 쓰므로 숨은 필드에 직접 입력한다.
  Future<void> enterPin(WidgetTester tester, String pin) async {
    await tester.enterText(find.byType(TextField), pin);
    await tester.pumpAndSettle();
  }

  /// 최종 확정 — 2단계 일치 후 CTA를 눌러 저장·완료한다
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();
    // 시험에는 서버가 없어 프로필 저장이 실패한다. 실패 팝업을 닫아야 다음 화면으로
    // 넘어간다 — 팝업을 띄운 채 넘어가면 팝업이 홈 위에 남는다 (#433).
    if (find.text('확인').evaluate().isNotEmpty) {
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
    }
  }

  /// 채워진 점 개수를 센다
  int filledDots(WidgetTester tester) {
    final dots = tester.widgetList<Container>(
      find.descendant(
        of: find.byType(PinDots),
        matching: find.byType(Container),
      ),
    );
    return dots
        .where(
          (d) =>
              (d.decoration! as BoxDecoration).color ==
              AppColors.light.textPrimary,
        )
        .length;
  }

  group('온보딩_비밀번호 화면', () {
    testWidgets('아무것도 입력하지 않으면 CTA가 아예 없다 (이슈 #231)', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // 눌리지 않는 버튼을 깔아두면 "이걸 눌러야 하나" 하고 멈춘다.
      expect(hasCta(tester), isFalse);
    });

    testWidgets('재입력 일치 후 CTA를 눌러야 완료 화면으로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await enterPin(tester, '1234'); // 자동 전환
      await enterPin(tester, '1234'); // 일치 → CTA 활성
      await submit(tester); // 사용자가 최종 확정

      expect(find.text('완료 화면'), findsOneWidget);
    });

    testWidgets('재입력이 다르면 재입력만 다시 받고 정한 암호는 살린다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await enterPin(tester, '1234'); // 자동 전환
      await enterPin(tester, '9999'); // 불일치

      // 완료로 넘어가지 않는다
      expect(find.text('완료 화면'), findsNothing);
      // 입력칸만 비운다
      expect(filledDots(tester), 0);
      // 확인 단계에 머무른다 — 1단계로 돌아가면 암호를 처음부터 다시 만들어야 한다
      expect(find.textContaining('한번 더'), findsOneWidget);
      expect(find.textContaining('비밀암호를 만들어주세요'), findsNothing);

      // 아동 모드 규칙 — 빨강·경고 아이콘 금지
      expect(find.byIcon(Icons.error), findsNothing);
      expect(find.byIcon(Icons.warning), findsNothing);

      final texts = tester.widgetList<Text>(find.byType(Text));
      for (final t in texts) {
        expect(t.style?.color, isNot(Colors.red));
      }
    });

  });

  group('PIN 점 (Figma 실측)', () {
  });

  group('OnboardingProfile', () {
  });

  /// PIN 입력은 autofocus라 **화면에 들어가면 키패드가 항상 뜬다.**
  /// 즉 키보드가 올라온 상태가 예외가 아니라 기본이다.
  group('키보드', () {
  });

  group('누를 수 있는 것에 읽을 이름이 있다 (#339)', () {
  });
}
