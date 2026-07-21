import 'package:elum/core/router/app_router.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/features/onboarding/domain/onboarding_profile.dart';
import 'package:elum/features/onboarding/presentation/pin_screen.dart';
import 'package:elum/features/onboarding/presentation/widgets/pin_keypad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'helpers/test_storage.dart';

/// Figma `온보딩_비밀번호`(238:1909) / `_입력`(238:1997) / `_재확인`(238:2767) 정합 테스트.
///
/// PIN 불일치는 아동도 볼 수 있는 화면이라 경고색·에러 아이콘을 쓰지 않는다.
/// 그 규칙을 테스트로 고정한다.
void main() {
  bool isCtaEnabled(WidgetTester tester) {
    return tester.widget<ElumButton>(find.byType(ElumButton)).onPressed != null;
  }

  Widget wrap() {
    final router = GoRouter(
      initialLocation: Routes.onboardingPin,
      routes: [
        GoRoute(
          path: Routes.onboardingPin,
          builder: (context, state) => const PinScreen(),
        ),
        GoRoute(
          path: Routes.onboardingDone,
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

  /// 입력 후 CTA를 눌러 다음 단계로 넘어간다
  Future<void> submit(WidgetTester tester) async {
    await tester.tap(find.byType(ElumButton));
    await tester.pumpAndSettle();
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
    testWidgets('Figma 문구가 보인다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('보호자모드로 변경할 때 사용하는 암호예요'), findsOneWidget);
      // CTA는 "다음"이 아니라 "맞춤 설정하기"다
      expect(find.text('맞춤 설정하기'), findsOneWidget);
    });

    testWidgets('아무것도 입력하지 않으면 CTA가 비활성이다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(isCtaEnabled(tester), isFalse);
    });

    testWidgets('점 4개가 자릿수를 보여준다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(filledDots(tester), 0);

      await enterPin(tester, '12');
      expect(filledDots(tester), 2);
    });

    testWidgets('지우면 점도 함께 줄어든다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await enterPin(tester, '123');
      expect(filledDots(tester), 3);

      // 지우기는 OS 키패드가 처리한다. 결과가 점에 반영되는지만 본다.
      await enterPin(tester, '12');
      expect(filledDots(tester), 2);
    });

    testWidgets('OS 시스템 숫자 키패드를 쓴다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // 자체 키패드를 그리지 않는다 — 각 OS의 입력 관습을 다시 구현하지 않기 위함
      final field = tester.widget<TextField>(find.byType(TextField));
      expect(field.keyboardType, TextInputType.number);
    });

    testWidgets('4자리를 넘겨 입력할 수 없다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await enterPin(tester, '123456');
      expect(filledDots(tester), OnboardingProfile.pinLength);
    });

    testWidgets('숫자가 아닌 입력은 무시한다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await enterPin(tester, 'ab12');
      expect(filledDots(tester), 2);
    });

    testWidgets('4자리를 채워야 CTA가 활성된다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // enterText는 전체를 덮어쓴다. 누적 입력이 아니라 최종 상태를 본다.
      await enterPin(tester, '123');
      expect(isCtaEnabled(tester), isFalse);

      await enterPin(tester, '1234');
      expect(isCtaEnabled(tester), isTrue);
    });

    testWidgets('4자리를 채우면 재입력 단계로 넘어간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await enterPin(tester, '1234');
      await submit(tester);

      // Figma 238:2767의 제목
      expect(find.textContaining('한번 더'), findsOneWidget);
      // 재입력 단계에서는 점이 비어 있다
      expect(filledDots(tester), 0);
    });

    testWidgets('두 번 같은 값을 넣으면 완료 화면으로 간다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await enterPin(tester, '1234');
      await submit(tester);
      await enterPin(tester, '1234');
      await submit(tester);

      expect(find.text('완료 화면'), findsOneWidget);
    });

    testWidgets('값이 다르면 처음부터 다시 받되 경고색을 쓰지 않는다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await enterPin(tester, '1234');
      await submit(tester);
      await enterPin(tester, '9999');
      await submit(tester);

      // 완료로 넘어가지 않는다
      expect(find.text('완료 화면'), findsNothing);
      // 1단계로 되돌아왔다
      expect(filledDots(tester), 0);

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
    testWidgets('점은 20×20이다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // Figma Group 22 — 20×20 4개, x=109부터 52 간격
      final size = tester.getSize(
        find
            .descendant(
              of: find.byType(PinDots),
              matching: find.byType(Container),
            )
            .first,
      );
      expect(size.width, 20);
      expect(size.height, 20);
    });

    testWidgets('입력 전 점 색은 Figma 회색이다', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final dot = tester.widget<Container>(
        find
            .descendant(
              of: find.byType(PinDots),
              matching: find.byType(Container),
            )
            .first,
      );
      // #CDC8C3
      expect(
        (dot.decoration! as BoxDecoration).color,
        AppColors.light.pinDotEmpty,
      );
    });
  });

  group('OnboardingProfile', () {
    test('PIN은 4자리다', () {
      expect(OnboardingProfile.pinLength, 4);
    });
  });
}
