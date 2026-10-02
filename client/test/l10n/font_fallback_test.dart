import 'package:elum/core/theme/app_theme.dart';
import 'package:elum/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const zhHans = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hans');

  group('언어별 대체 글꼴 목록', () {
    test('ko 는 비어 있다 — 기존 화면이 한 픽셀도 달라지지 않는다', () {
      expect(AppTypography.fontFamilyFallbackFor(const Locale('ko')), isEmpty);
    });

    test('en·es 는 라틴 전체를 가진 Pretendard 다 — TmoneyRoundWind 에 악센트 문자가 없다', () {
      expect(AppTypography.fontFamilyFallbackFor(const Locale('en')), ['Pretendard']);
      expect(AppTypography.fontFamilyFallbackFor(const Locale('es')), ['Pretendard']);
    });

    test('ja·zh 는 Pretendard 다음에 시스템 글꼴이 온다', () {
      final ja = AppTypography.fontFamilyFallbackFor(const Locale('ja'));
      final zh = AppTypography.fontFamilyFallbackFor(zhHans);
      expect(ja.first, 'Pretendard');
      expect(zh.first, 'Pretendard');
      expect(ja, containsAll(['Hiragino Sans', 'Noto Sans CJK JP']));
      expect(zh, containsAll(['PingFang SC', 'Noto Sans CJK SC']));
      // 일본어 자형이 중국어 화면에 섞이면 안 된다
      expect(zh, isNot(contains('Hiragino Sans')));
    });
  });

  group('테마', () {
    test('AppTheme.light 는 ko 테마다 — 대체 글꼴이 없다', () {
      expect(AppTheme.light.textTheme.bodyMedium!.fontFamilyFallback, isNull);
      expect(
        AppTheme.lightFor(const Locale('ko')).textTheme.bodyMedium!.fontFamilyFallback,
        isNull,
      );
    });

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

    testWidgets('ko 테마는 같은 위젯에 대체 글꼴을 입히지 않는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(body: Text('가', style: AppTypography.standard.title)),
        ),
      );

      final paragraph = tester.renderObject<RenderParagraph>(find.text('가'));
      expect((paragraph.text as TextSpan).style!.fontFamilyFallback, isNull);
    });
  });
}
