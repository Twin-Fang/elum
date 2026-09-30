import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/presentation/widgets/image_style_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 선택하면 테두리가 두꺼워지는데 안쪽 내용이 그만큼 밀리던 것 (#458, 통합 E2E 실측).
///
/// 선택 카드의 그림과 글자가 안 선택된 카드보다 2~3px 어긋나 보였다. 선택 여부와 무관하게
/// 글자 왼쪽 위치가 같아야 한다.
void main() {
  useFigmaViewport();

  testWidgets('선택한 카드와 안 한 카드의 글자 왼쪽 위치가 같다', (tester) async {
    Widget card(ImageStyle style, bool selected) =>
        ImageStyleOptionCard(style: style, isSelected: selected);

    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Column(
              children: [
                card(ImageStyle.cartoon, false),
                card(ImageStyle.realistic, true),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final unselected = tester
        .getTopLeft(find.text(ImageStyle.cartoon.label))
        .dx;
    final selected = tester
        .getTopLeft(find.text(ImageStyle.realistic.label))
        .dx;

    expect(selected, closeTo(unselected, 0.5));
  });
}
