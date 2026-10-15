import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {

  group('언어별 대체 글꼴 목록', () {
    test('en·es 는 라틴 전체를 가진 Pretendard 다 — TmoneyRoundWind 에 악센트 문자가 없다', () {
      expect(AppTypography.fontFamilyFallbackFor(const Locale('en')), ['Pretendard']);
      expect(AppTypography.fontFamilyFallbackFor(const Locale('es')), ['Pretendard']);
    });

  });

  group('테마', () {
    testWidgets('es 테마는 위젯이 직접 넘긴 TextStyle 에도 대체 글꼴을 입힌다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.lightFor(const Locale('es')),
          home: Scaffold(
            // 81곳이 이렇게 fontFamily 를 직접 박는다 — 상속되는지가 핵심이다
            body: Text('Ñandú', style: AppTypography.standard.title),
          ),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(find.text('Ñandú'));
      expect(
        (paragraph.text as TextSpan).style!.fontFamilyFallback,
        ['Pretendard'],
      );
      expect((paragraph.text as TextSpan).style!.fontFamily, AppTypography.fontFamily);
    });

  });
}
