import 'dart:io';

import 'package:elum/core/theme/app_colors.dart';
import 'package:elum/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 디자인 토큰 규칙을 고정한다.
///
/// 이 테스트가 존재하는 이유 — 규칙을 문서에만 적어두면 지켜지지 않는다.
/// 실제로 색을 하나로 묶었다가 목표 칩에 여우색이 들어간 사고가 있었고(이슈 #11),
/// 화면에서 `copyWith(fontSize:)`로 크기를 덮어써 Figma 변경을 추적할 수 없던 적도 있다.
///
/// 규칙: client/CLAUDE.md §3 · docs/design-system.md
void main() {
  group('토큰 하드코딩 금지', () {
    /// 화면 코드에서 색·크기를 직접 쓰면 토큰이 무의미해진다.
    /// theme/ 아래는 토큰 정의부라 당연히 제외한다.
    List<File> screenFiles() => Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where((f) => !f.path.contains('lib/core/theme/'))
        // 개발자 도구는 디버그 전용 오버레이라 디자인 대상이 아니다
        .where((f) => !f.path.contains('lib/core/dev/'))
        .toList();

    test('화면에서 Color(0x...)를 직접 쓰지 않는다', () {
      final offenders = <String>[];

      for (final file in screenFiles()) {
        // 인덱스로 배정하는 순환 팔레트는 예외다. 항목 수가 가변이라
        // 전역 토큰으로 고정할 수 없다. (이슈 #36)
        //
        // - 추천 타일: 서버가 주는 추천 개수만큼 순환
        // - 카드 팔레트: AI가 만드는 카드 장수만큼 순환 (실측 9장까지 나왔다)
        if (file.path.contains('widgets/recommended_routine_strip.dart') ||
            file.path.contains('domain/card_palette.dart')) {
          continue;
        }

        final lines = file.readAsLinesSync();
        for (final (index, line) in lines.indexed) {
          if (line.contains('Color(0x')) {
            offenders.add('${file.path}:${index + 1}  ${line.trim()}');
          }
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: '색은 AppColors를 경유한다. 값이 같아도 쓰임이 다르면 새 토큰을 추가한다.\n'
            '${offenders.join('\n')}',
      );
    });

    test('화면에서 fontSize를 직접 지정하지 않는다', () {
      final offenders = <String>[];

      for (final file in screenFiles()) {
        final lines = file.readAsLinesSync();
        for (final (index, line) in lines.indexed) {
          if (!line.contains('fontSize:')) continue;
          // 시스템 이모지는 앱 폰트가 아니라 OS 폰트로 렌더링되므로
          // AppTypography를 태우지 않는다. 위젯 상수로 둔다.
          if (line.contains('_emojiSize')) continue;
          // ScreenUtil로 스케일하는 절대좌표 화면(시작 화면)은 예외다
          if (line.contains('.sp')) continue;
          // 위젯 내부 private 상수 정의는 크기의 출처가 한 곳이라 허용한다
          if (line.contains('_titleSize')) continue;

          offenders.add('${file.path}:${index + 1}  ${line.trim()}');
        }
      }

      expect(
        offenders,
        isEmpty,
        reason: 'Figma에 새 크기가 나오면 AppTypography에 토큰을 추가한다.\n'
            'copyWith(fontSize:)로 덮어쓰면 Figma 변경을 grep으로 찾을 수 없다.\n'
            '${offenders.join('\n')}',
      );
    });
  });

  group('AppColors', () {
    /// 값이 같아도 쓰임이 다르면 토큰을 나눈다는 규칙의 실제 사례.
    /// 누군가 "중복이네" 하고 합치면 이 테스트가 막는다.
    test('homeCardTitle과 catSelectedBorder는 값이 같아도 별개 토큰이다', () {
      const colors = AppColors.light;

      expect(colors.homeCardTitle, const Color(0xFF9CADF1));
      expect(colors.catSelectedBorder, const Color(0xFF9CADF1));

      // 홈 카드 제목만 바꿔도 캐릭터 선택 테두리는 그대로여야 한다.
      final changed = colors.copyWith(homeCardTitle: const Color(0xFF000000));
      expect(changed.catSelectedBorder, const Color(0xFF9CADF1),
          reason: '토큰을 합치면 한쪽만 바꿀 수 없다');
    });

    /// lerp 누락은 컴파일러가 못 잡고 테마 전환에서만 드러난다.
    /// 가장 놓치기 쉬운 자리라 테스트로 고정한다.
    test('lerp가 보호자 홈 토큰을 빠뜨리지 않는다', () {
      const from = AppColors.light;
      final to = from.copyWith(
        homeCardGradientStart: const Color(0xFF000000),
        homeCardGradientEnd: const Color(0xFF000000),
        homeCardTitle: const Color(0xFF000000),
        homeCardShadow: const Color(0xFF000000),
      );

      final mid = from.lerp(to, 1.0);

      expect(mid.homeCardGradientStart, const Color(0xFF000000));
      expect(mid.homeCardGradientEnd, const Color(0xFF000000));
      expect(mid.homeCardTitle, const Color(0xFF000000));
      expect(mid.homeCardShadow, const Color(0xFF000000));
    });
  });

  group('AppTypography — Figma 217:2655 실측값', () {
    const typo = AppTypography.standard;

    test('보호자 홈 토큰이 Figma 크기와 일치한다', () {
      expect(typo.greeting.fontSize, 24);
      expect(typo.cardTitle.fontSize, 17);
      expect(typo.cardBody.fontSize, 15);
      expect(typo.sectionTitle.fontSize, 14);
      expect(typo.tileLabel.fontSize, 13);
      expect(typo.caption.fontSize, 12);
    });

    test('굵기가 Figma와 일치한다', () {
      expect(typo.greeting.fontWeight, FontWeight.w800);
      expect(typo.cardTitle.fontWeight, FontWeight.w800);
      expect(typo.sectionTitle.fontWeight, FontWeight.w800);
      expect(typo.cardBody.fontWeight, FontWeight.w400);
      expect(typo.tileLabel.fontWeight, FontWeight.w400);
      expect(typo.caption.fontWeight, FontWeight.w400);
    });

    test('모든 토큰이 앱 폰트를 쓴다', () {
      for (final style in [
        typo.greeting,
        typo.cardTitle,
        typo.cardBody,
        typo.sectionTitle,
        typo.tileLabel,
        typo.caption,
      ]) {
        expect(style.fontFamily, AppTypography.fontFamily);
      }
    });

    test('lerp가 보호자 홈 토큰을 빠뜨리지 않는다', () {
      final to = typo.copyWith(
        greeting: const TextStyle(fontSize: 99),
        cardTitle: const TextStyle(fontSize: 99),
        cardBody: const TextStyle(fontSize: 99),
        sectionTitle: const TextStyle(fontSize: 99),
        tileLabel: const TextStyle(fontSize: 99),
        caption: const TextStyle(fontSize: 99),
      );

      final mid = typo.lerp(to, 1.0);

      expect(mid.greeting.fontSize, 99);
      expect(mid.cardTitle.fontSize, 99);
      expect(mid.cardBody.fontSize, 99);
      expect(mid.sectionTitle.fontSize, 99);
      expect(mid.tileLabel.fontSize, 99);
      expect(mid.caption.fontSize, 99);
    });
  });
}
