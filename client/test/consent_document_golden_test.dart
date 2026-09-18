@Tags(['golden'])
library;

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/consent_document_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 약관 전문 화면 (이슈 #235).
///
/// **회색으로 묻히던 것을 고쳤다.** 골든이 그 색과 구조를 함께 붙잡는다 —
/// 색을 다시 빼먹으면 여기서 드러난다.
void main() {
  useFigmaViewport();

  Widget wrap(ConsentItem item) => ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          home: ConsentDocumentScreen(item: item),
        ),
      );

  testWidgets('개인정보 처리방침 — 섹션·소제목·불릿이 나뉜다', (tester) async {
    final privacy =
        consentItems.firstWhere((e) => e.key == 'privacyAgreed');

    await tester.pumpWidget(wrap(privacy));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ConsentDocumentScreen),
      matchesGoldenFile('goldens/consent_document.png'),
    );
  });
}
