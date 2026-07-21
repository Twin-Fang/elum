import 'package:elum/core/widgets/elum_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// 정렬 판단 규칙을 고정한다.
///
/// 좌측 아이콘은 Figma 개정으로 제거됐다 (이슈 #83). 기본은 중앙 정렬이고,
/// 좌측 정렬이 필요한 화면(카드 수정 시트 등)만 explicitTextAlign을 넘긴다.
void main() {
  group('ElumTextField 정렬 판단', () {
    test('기본은 중앙 정렬이다', () {
      const field = ElumTextField(hintText: '이름을 입력해주세요');

      expect(field.resolvedTextAlign, TextAlign.center);
    });

    test('explicitTextAlign을 넘기면 그 값을 쓴다', () {
      const field = ElumTextField(
        hintText: '이름을 입력해주세요',
        explicitTextAlign: TextAlign.left,
      );

      expect(field.resolvedTextAlign, TextAlign.left);
    });
  });
}
