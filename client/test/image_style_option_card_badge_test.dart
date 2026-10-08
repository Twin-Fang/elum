import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/presentation/widgets/image_style_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 그림 방식 카드의 이름 옆 배지 — 크레딧이 드는 방식인지 보인다.
void main() {
  useFigmaViewport();

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  for (final s in ImageStyle.values)
                    ImageStyleOptionCard(style: s, isSelected: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('만화·실사는 크레딧 사용, 기본 그림은 무료 배지가 붙는다', (tester) async {
    await pump(tester);

    expect(find.text('크레딧 사용'), findsNWidgets(2));
    expect(find.text('무료'), findsOneWidget);
    expect(ImageStyle.cartoon.badge, '크레딧 사용');
    expect(ImageStyle.realistic.badge, '크레딧 사용');
    expect(ImageStyle.photoOnly.badge, '무료');
  });

  testWidgets('글자를 2배로 키워도 넘치지 않고 배지가 그려진다', (tester) async {
    await pump(tester, textScale: 2);

    expect(tester.takeException(), isNull);
    expect(find.text('크레딧 사용'), findsNWidgets(2));
    expect(find.text('무료'), findsOneWidget);
  });

  testWidgets('낭독 라벨은 이름, 배지, 설명 순서다', (tester) async {
    for (final s in ImageStyle.values) {
      expect(
        ImageStyleOptionCard.semanticLabel(s),
        '${s.label}, ${s.badge}, ${s.description}',
      );
    }
    expect(
      ImageStyleOptionCard.semanticLabel(ImageStyle.cartoon),
      startsWith('만화, 크레딧 사용, '),
    );
  });
}
