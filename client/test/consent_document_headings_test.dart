import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 약관 상세의 조항 제목·번호 항목·소제목 (#475).
///
/// 파서가 덩이를 나누는 것은 `consent_body_test.dart` 가 보고, 여기서는 **화면에서
/// 제목은 제목 글씨로, 번호 항목은 본문 글씨로, 소제목은 따로 한 줄로** 보이는지 본다.
void main() {
  Future<void> pump(WidgetTester tester, String key) async {
    final view = tester.view;
    view.devicePixelRatio = 1;
    view.physicalSize = const Size(393, 852);
    addTearDown(view.resetPhysicalSize);
    addTearDown(view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          home: ConsentDocumentScreen(
            item: consentItems.firstWhere((e) => e.key == key),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextStyle styleOf(WidgetTester tester, Finder f) =>
      tester.widget<Text>(f).style!;

  Future<void> reveal(WidgetTester tester, Finder f) async {
    await tester.scrollUntilVisible(f, 200);
    await tester.pumpAndSettle();
  }

  testWidgets('이용약관 — 제5조의3 이 제목 글씨이고 번호 항목은 본문 글씨다', (tester) async {
    await pump(tester, 'termsAgreed');

    final article = find.text('제5조의3 (그림 출처)');
    final first = find.textContaining('1. 서비스의 카드 그림 중 일부는');
    await reveal(tester, first);

    final head = styleOf(tester, article);
    final item = styleOf(tester, first);
    // 제목이 번호 항목보다 크다 — 번호 항목이 제목처럼 보이지 않는다
    expect(head.fontSize!, greaterThan(item.fontSize!));
    // 제5조의2 도 같은 제목 글씨다
    expect(styleOf(tester, find.text('제5조의2 (광고)')).fontSize, head.fontSize);
    // 번호 항목 1~4 가 항목마다 따로 서고, 같은 본문 글씨다
    for (final n in ['2. 표기:', '3. Copyright', '4. 라이선스 전문은']) {
      final f = find.textContaining(n);
      expect(f, findsOneWidget);
      expect(styleOf(tester, f).fontSize, item.fontSize);
      expect(styleOf(tester, f).fontWeight, item.fontWeight);
    }
    // URL 이 잘리지 않고 한 항목 안에 이어 있다
    expect(
      find.textContaining('https://creativecommons.org/licenses/by-sa/4.0/ 에서 볼 수 있습니다.'),
      findsOneWidget,
    );
  });

  testWidgets('국외 이전 동의서 — 소제목이 굵은 한 줄로 서고 본문이 아래 따로 있다', (tester) async {
    await pump(tester, 'overseasTransferAgreed');

    final sub = find.text('보유 및 이용 기간');
    await reveal(tester, sub);
    final body = find.text(
      '전달받는 업체의 정책에 따라 처리되며, 이룸은 응답을 받은 뒤 원본 요청을 보관하지 않습니다.',
    );
    expect(body, findsOneWidget);
    // 본문이 소제목 아래에 놓인다 — 한 문단에 붙어 있지 않다
    expect(tester.getRect(body).top, greaterThanOrEqualTo(tester.getRect(sub).bottom));
    expect(styleOf(tester, sub).fontWeight, FontWeight.w700);
    expect(styleOf(tester, body).fontWeight, isNot(FontWeight.w700));

    // 나머지 소제목도 굵은 글씨
    for (final t in ['이전되는 항목', '이전 목적', '동의를 거부할 권리']) {
      final f = find.text(t);
      await reveal(tester, f);
      expect(styleOf(tester, f).fontWeight, FontWeight.w700, reason: t);
    }
  });
}
