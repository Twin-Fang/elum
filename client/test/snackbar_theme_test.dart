@Tags(['golden'])
library;

import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/device_viewport.dart';

/// 스낵바 임시 테마 (#543).
///
/// 띄우는 곳(7곳)은 문구만 넘기므로 테마가 빠지면 조용히 기본 갈색 직사각형으로
/// 돌아간다. 화면을 하나씩 열지 않고 여기서 모양을 붙잡는다.
void main() {
  useFigmaViewport();

  Widget app({double textScale = 1}) => ScreenUtilInit(
        designSize: const Size(393, 852),
        useInheritedMediaQuery: true,
        builder: (context, _) => MaterialApp(
          theme: AppTheme.light,
          // 앱에 없는 리본이라 골든을 디자이너에게 보여줄 때 헷갈린다
          debugShowCheckedModeBanner: false,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
            ),
            child: child!,
          ),
          home: Scaffold(
            backgroundColor: AppTheme.light.scaffoldBackgroundColor,
            body: Builder(
              builder: (context) => Center(
                child: TextButton(
                  onPressed: () {},
                  child: const Text('본문'),
                ),
              ),
            ),
          ),
        ),
      );

  Future<void> show(WidgetTester tester, String message) async {
    final context = tester.element(find.text('본문'));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    // 올라오는 움직임이 끝난 자리에서 본다. 저절로 닫히기 전(4초)에 멈춘다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('떠 있고 둥글며 본문색 바탕에 흰 글자다', (tester) async {
    await tester.pumpWidget(app());
    await show(tester, '그림 방식을 바꿨어요');

    final bar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(bar.behavior, isNull, reason: '화면이 덧쓰지 않고 테마를 따른다');

    final material = tester.widget<Material>(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first,
    );
    expect(material.color, AppColors.light.textPrimary);
    expect(material.shape, isA<RoundedRectangleBorder>());

    // 실제로 그려진 글자의 색을 읽는다 — Text 위젯의 style 은 비어 있고 테마에서 내려온다.
    final rich = tester.widget<RichText>(
      find.descendant(of: find.text('그림 방식을 바꿨어요'), matching: find.byType(RichText)),
    );
    expect(rich.text.style?.color, AppColors.light.surface);

    // floating 이라 좌우가 화면 끝에 붙지 않는다.
    // SnackBar 위젯 자체는 화면 폭 전체라 안쪽 Material(실제 상자)을 잰다.
    final rect = tester.getRect(
      find.descendant(of: find.byType(SnackBar), matching: find.byType(Material)).first,
    );
    expect(rect.left, 16);
    expect(rect.right, 393 - 16);
  });

  testWidgets('짧은 문구', (tester) async {
    await tester.pumpWidget(app());
    await show(tester, '그림 방식을 바꿨어요');
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/snackbar_short.png'),
    );
  });

  testWidgets('이름이 길어 두 줄이 되는 문구', (tester) async {
    await tester.pumpWidget(app());
    await show(tester, '아침에 일어나서 씻고 옷 입고 학교 가기을(를) 오늘 일과에 담았어요');
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/snackbar_long.png'),
    );
  });

  testWidgets('글자 크기를 키워도 넘치지 않는다', (tester) async {
    await tester.pumpWidget(app(textScale: 1.6));
    await show(tester, '하늘이에서 나왔어요');
    expect(tester.takeException(), isNull);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/snackbar_large_text.png'),
    );
  });
}
