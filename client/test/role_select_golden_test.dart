@Tags(['golden'])
library;

import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/widgets/app_pressable.dart';
import 'package:elum/core/widgets/elum_button.dart';
import 'package:elum/core/widgets/elum_header.dart';
import 'package:elum/core/widgets/elum_scaffold.dart';
import 'package:elum/features/auth/domain/app_role.dart';
import 'package:elum/features/auth/presentation/widgets/role_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

/// 역할 선택 두 상태 (Figma 732:5176 · 732:5258 · 이슈 #229).
void main() {
  Widget wrap({AppRole? selected}) => ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, child) => MaterialApp(
          theme: AppTheme.light,
          home: ElumScaffold(
            onBack: () {},
            bottomButton: ElumButton(
              label: '다음',
              onPressed: selected != null ? () {} : null,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ElumHeader(
                    title: '이 휴대폰은 누가\n사용하나요?',
                    description: '보호자모드와 이룸이모드가 나눠져 있어요',
                    hasBackButton: true,
                  ),
                  SizedBox(height: 52.h),
                  for (final role in AppRole.values) ...[
                    AppPressable(
                      onTap: () {},
                      child: RoleCard(role: role, selected: selected == role),
                    ),
                    if (role != AppRole.values.last) SizedBox(height: 16.h),
                  ],
                ],
              ),
            ),
          ),
        ),
      );

  Future<void> shoot(WidgetTester tester, Widget w, String name) async {
    tester.view.physicalSize = const Size(393 * 3, 852 * 3);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(w);
    await tester.pumpAndSettle();
    await expectLater(
      find.byType(ElumScaffold),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('역할 선택 — 미선택', (t) async => shoot(t, wrap(), 'role_none'));

  testWidgets('역할 선택 — 보호자',
      (t) async => shoot(t, wrap(selected: AppRole.guardian), 'role_guardian'));
}
