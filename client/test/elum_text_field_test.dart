import 'package:elum/core/widgets/elum_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 정렬 자동 판단 규칙을 고정한다.
///
/// 아이콘은 왼쪽에 붙는데 텍스트만 가운데 뜨는 조합은 디자인상 존재하지 않는다.
/// 호출부가 정렬을 매번 넘기지 않아도 되도록 위젯이 스스로 판단한다.
///
/// Figma 204:991 명세와의 정합성을 검증한다.
/// - 필드 높이: 68px
/// - 상하 패딩: 각 24px (Figma: 텍스트 y=600은 배경 y=576에서 24px 아래)
/// - 좌우 패딩: 각 16px (space.md)
void main() {

  group('ElumTextField 정렬 판단', () {
    test('아이콘이 있으면 좌측 정렬이다', () {
      const field = ElumTextField(
        hintText: '이름을 입력해주세요',
        leadingIconAssetPath: 'assets/images/icon_child_head.svg',
      );

      expect(field.resolvedTextAlign, TextAlign.left);
    });

    test('아이콘이 없으면 중앙 정렬이다', () {
      const field = ElumTextField(hintText: '이름을 입력해주세요');

      expect(field.resolvedTextAlign, TextAlign.center);
    });

    test('explicitTextAlign을 넘기면 자동 판단을 이긴다', () {
      // 아이콘이 있어도 호출부가 명시하면 그 값을 쓴다
      const field = ElumTextField(
        hintText: '이름을 입력해주세요',
        leadingIconAssetPath: 'assets/images/icon_child_head.svg',
        explicitTextAlign: TextAlign.center,
      );

      expect(field.resolvedTextAlign, TextAlign.center);
    });
  });
}
