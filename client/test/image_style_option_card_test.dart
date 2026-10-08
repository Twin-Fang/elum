import 'package:elum/core/assets/app_assets.dart';
import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/onboarding/presentation/widgets/image_style_option_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';
import 'helpers/svg_finder.dart';

/// 그림 방식 선택 카드의 시안 값 (Figma `그림방식` 1274:9883 · 1274:10129, 이슈 #494).
void main() {
  useFigmaViewport();

  Future<void> pump(WidgetTester tester, Widget child) async {
    await tester.pumpWidget(
      ScreenUtilInit(
        designSize: const Size(393, 852),
        builder: (_, _) => MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: child,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('카드 모양', () {
    testWidgets('카드는 344×94 이고 예시 70×70, 라디오 20×20 이다', (tester) async {
      await pump(
        tester,
        const ImageStyleOptionCard(style: ImageStyle.cartoon, isSelected: true),
      );

      final card = tester.getSize(find.byType(ImageStyleOptionCard));
      expect(card.width, closeTo(345, 1), reason: '시안 344 (화면 좌우 24)');
      expect(card.height, closeTo(94, 0.6));
    });

    testWidgets('고른 만화는 민트 면, 안 고르면 바탕색 위에 캐릭터를 그린다', (tester) async {
      final colors = AppTheme.light.extension<AppColors>()!;

      await pump(
        tester,
        const ImageStyleOptionCard(style: ImageStyle.cartoon, isSelected: true),
      );
      // 예시 자리는 둥글게 자른(ClipRRect) 70×70 상자 안의 면이다
      ColoredBox thumb() => tester.widget<ColoredBox>(
        find.descendant(
          of: find.byType(ClipRRect),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(thumb().color, colors.goalSelectedBorder);

      await pump(
        tester,
        const ImageStyleOptionCard(
          style: ImageStyle.cartoon,
          isSelected: false,
        ),
      );
      expect(thumb().color, colors.background);
    });

    testWidgets('실사는 시안의 사진 에셋, 기본 그림은 실제 카드의 픽토그램을 쓴다', (tester) async {
      await pump(
        tester,
        const Column(
          children: [
            ImageStyleOptionCard(
              style: ImageStyle.realistic,
              isSelected: false,
            ),
            ImageStyleOptionCard(
              style: ImageStyle.photoOnly,
              isSelected: false,
            ),
          ],
        ),
      );

      expect(imageWithAsset(AppAssets.imageStyleRealistic), findsOneWidget);
      expect(svgWithAsset(AppAssets.imageStyleBasic), findsOneWidget);
    });

    testWidgets('한 문장 설명은 줄을 나누지 않고 낭독 이름은 원문이다', (tester) async {
      await pump(
        tester,
        const ImageStyleOptionCard(
          style: ImageStyle.photoOnly,
          isSelected: false,
        ),
      );

      final text = tester.widget<Text>(
        find.byWidgetPredicate(
          (w) =>
              w is Text &&
              w.semanticsLabel == ImageStyle.photoOnly.description,
        ),
      );
      expect(text.data, isNot(contains('\n')));
      expect(text.semanticsLabel, ImageStyle.photoOnly.description);
    });

    testWidgets('카드 제목은 기본 그림이다', (tester) async {
      await pump(
        tester,
        const ImageStyleOptionCard(
          style: ImageStyle.photoOnly,
          isSelected: true,
        ),
      );

      expect(find.text('기본 그림'), findsOneWidget);
    });
  });
}
