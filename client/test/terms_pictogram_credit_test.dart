import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:flutter_test/flutter_test.dart';

/// 그림 출처 표기를 이용약관에 둔다 (이슈 #477).
///
/// Mulberry Symbols(CC BY-SA 4.0)는 저작자와 라이선스를 밝혀야 한다. 설정의 별도
/// 화면을 없애고 약관 제5조의3으로 옮겼으므로, 이 조항이 빠지면 표기 의무가 사라진다.
/// 번들은 네트워크가 없을 때 약관 화면이 보여주는 최후의 원본이다.
void main() {
  final terms = consentItems.firstWhere((i) => i.key == 'termsAgreed').body;
  final flat = terms.replaceAll(RegExp(r'\s+'), ' ');

  test('제5조의3(그림 출처)에 저작자가 권장한 표기문을 원문 그대로 적는다', () {
    expect(flat, contains('제5조의3 (그림 출처)'));
    expect(
      flat,
      contains(
        'Mulberry Symbols by Steve Lee are licenced under the Creative Commons '
        'Attribution-ShareAlike 4.0 License. See https://mulberrysymbols.org for details',
      ),
    );
  });

  test('저작권·원본 사이트·라이선스 전문 주소를 적는다', () {
    expect(flat, contains('Copyright 2018-2026 Steve Lee'));
    expect(flat, contains('https://mulberrysymbols.org'));
    expect(flat, contains('https://creativecommons.org/licenses/by-sa/4.0/'));
  });

  test('색이나 모양을 바꾸지 않고 그대로 쓴다고 밝힌다', () {
    expect(flat, contains('색이나 모양을 바꾸지 않고 그대로 사용합니다'));
  });

  test('부칙에 공고·시행일을 적는다', () {
    expect(flat, contains('그림 출처에 관한 제5조의3을 더했습니다'));
  });
}
