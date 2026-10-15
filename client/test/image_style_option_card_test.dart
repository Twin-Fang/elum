import 'package:elum/core/assets/app_assets.dart';
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


  });
}
