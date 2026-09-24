import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 약관 상세의 표 행 (#376).
///
/// `전달받는 자   Google LLC …` 같은 표가 앞 문장에 붙어 한 문단으로 보였다.
/// 파서가 행을 나누는 것은 `consent_body_test.dart` 가 보고, 여기서는 **화면에서
/// 줄마다 한 항목으로 보이는지**와 글꼴을 키웠을 때 잘리지 않는지를 본다.
void main() {
  Future<void> pump(
    WidgetTester tester,
    String key, {
    Size size = const Size(393, 852),
    double textScale = 1,
  }) async {
    final view = tester.view;
    view.devicePixelRatio = 1;
    view.physicalSize = size;
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: ConsentDocumentScreen(
            item: consentItems.firstWhere((e) => e.key == key),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Rect rectOf(WidgetTester tester, String text) =>
      tester.getRect(find.text(text));

  group('국외 이전 동의서 표', () {
    testWidgets('이름과 값이 한 줄에 나란히 놓이고 값의 시작선이 맞는다', (tester) async {
      await pump(tester, 'overseasTransferAgreed');

      final country = rectOf(tester, '이전되는 국가');
      final usa = rectOf(tester, '미국');
      final when = rectOf(tester, '이전 일시');
      final whenValue = rectOf(tester, '카드를 만들 때마다 (네트워크를 통해 전송)');

      // 같은 줄 — 값이 이름 오른쪽, 윗선이 같다
      expect(usa.left, greaterThanOrEqualTo(country.right));
      expect(usa.top, moreOrLessEquals(country.top, epsilon: 0.5));
      // 행마다 줄이 바뀐다
      expect(when.top, greaterThanOrEqualTo(country.bottom - 0.5));
      // 원문이 공백으로 맞춘 것처럼 값의 시작선이 같다
      expect(whenValue.left, moreOrLessEquals(usa.left, epsilon: 0.5));
    });

    testWidgets('L3 전달받는 자 세 곳이 한 칸에 줄마다 보인다', (tester) async {
      await pump(tester, 'overseasTransferAgreed');

      expect(
        find.text(
          'Google LLC (policies.google.com/privacy)\n'
          'OpenAI, L.L.C. (openai.com/policies/privacy-policy)\n'
          'Features & Labels Inc. (fal.ai/legal/privacy-policy)',
        ),
        findsOneWidget,
      );
      // 앞 문장에 붙은 덩이가 남아 있지 않다
      expect(find.textContaining('전달받는 자   '), findsNothing);
    });

    // L4 — 360 폭 · 글꼴 2.0 이면 이름이 폭의 절반 가까이 먹어 값이 한두 글자씩
    // 꺾인다. 그때는 이름 아래로 값을 내린다. 넘침은 flutter_test_config 가 잡는다.
    testWidgets('L4 360 폭 · 글꼴 2.0 — 이름 아래로 값이 쌓이고 잘리지 않는다', (tester) async {
      await pump(
        tester,
        'overseasTransferAgreed',
        size: const Size(360, 780),
        textScale: 2,
      );

      final country = rectOf(tester, '이전되는 국가');
      final usa = rectOf(tester, '미국');
      expect(usa.top, greaterThanOrEqualTo(country.bottom - 0.5));
      expect(usa.left, moreOrLessEquals(country.left, epsilon: 0.5));
      // 값이 화면 안에 들어온다
      expect(usa.right, lessThanOrEqualTo(360));
    });

    testWidgets('글꼴 1.3 까지는 나란히 둔다', (tester) async {
      await pump(tester, 'overseasTransferAgreed', textScale: 1.3);

      final country = rectOf(tester, '이전되는 국가');
      final usa = rectOf(tester, '미국');
      expect(usa.left, greaterThanOrEqualTo(country.right));
    });
  });

  testWidgets('개인정보처리방침 10조 — 불릿 안의 표도 줄마다 한 항목이다', (tester) async {
    await pump(tester, 'privacyAgreed');
    await tester.scrollUntilVisible(find.text('보호책임자'), 200);
    await tester.pumpAndSettle();

    final name = rectOf(tester, '보호책임자');
    final value = rectOf(tester, '서새찬');
    expect(value.left, greaterThanOrEqualTo(name.right));
    expect(value.top, moreOrLessEquals(name.top, epsilon: 0.5));
    expect(
      rectOf(tester, 'chan4760@gmail.com').left,
      moreOrLessEquals(value.left, epsilon: 0.5),
    );
  });
}
