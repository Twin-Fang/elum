import 'dart:io';

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


}
