@Tags(['golden'])
library;

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:elum/features/auth/presentation/widgets/consent_all_agree_button.dart';
import 'package:elum/features/auth/presentation/widgets/consent_row.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/core/widgets/elum_header.dart';
import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 약관 동의 화면 두 상태 (Figma 739:3747 · 726:5056 · 이슈 #226).
///
/// 문구만 바꾼 게 아니라 **레이아웃이 통째로 바뀐** 화면이라, 눈으로 볼 수 있는
/// 기준을 남긴다. 다음에 누가 간격을 건드리면 여기서 걸린다.
void main() {
  Widget wrap({required bool allChecked}) => ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          home: ElumScaffold(
            bottomButton: ElumButton(
              label: '다음',
              onPressed: allChecked ? () {} : null,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElumHeader(
                    title: '약관에 동의해주세요',
                    description: allChecked
                        ? '항목을 눌러 상세 내용을 볼 수 있어요'
                        : '서비스 사용을 위해 약관 동의가 필요해요',
                  ),
                  SizedBox(height: 30.h),
                  ConsentAllAgreeButton(checked: allChecked, onTap: () {}),
                  SizedBox(height: 17.h),
                  for (final item in consentItems) ...[
                    ConsentRow(
                      item: item,
                      isChecked: allChecked,
                      onToggle: () {},
                      onOpen: () {},
                    ),
                    SizedBox(height: ConsentRow.gap.h),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  testWidgets('약관 동의 — 미동의', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(allChecked: false));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ElumScaffold),
      matchesGoldenFile('goldens/consent_unchecked.png'),
    );
  });

  testWidgets('약관 동의 — 전체 동의', (tester) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(wrap(allChecked: true));
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(ElumScaffold),
      matchesGoldenFile('goldens/consent_checked.png'),
    );
  });
}
