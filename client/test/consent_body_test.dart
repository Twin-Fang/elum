
import 'package:elum/features/auth/domain/consent_body.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:flutter_test/flutter_test.dart';

/// 약관 전문 파서 (이슈 #235).
///
/// 전문을 통짜 `Text` 하나로 그리던 것을 덩이로 나눴다. **원문은 하드랩되어
/// 있어** 그대로 두면 화면 폭에 맞춰 다시 줄바꿈되며 줄이 들쭉날쭉해진다.
void main() {
  group('덩이 나누기', () {

    // 서비스 이용약관은 `제N조`가 제목이고 그 아래 `1.` 은 본문 항목이다 (#430).
    // `1.` 을 제목으로 보면 들여쓴 다음 줄이 떨어져 문장이 중간에서 끊겼고,
    // `제N조`는 제목이 되지 못해 앞 문단에 붙었다 (실기기 실측).
    test('제N조가 있는 문서는 제N조가 제목이고 번호 줄은 본문 항목이다 (#430)', () {
      final blocks = parseConsentBody('''
제3조 (계정)
1. 계정은 카카오·네이버·구글·애플 로그인으로 만듭니다.
2. 로그인 수단마다 별개의 계정이 만들어집니다. 다른 수단으로 로그인하면
   이전 계정의 정보가 보이지 않습니다.

제5조 (서비스의 변경·중단)
회사는 서비스 내용을 변경하거나 중단할 수 있습니다.''');

      expect(blocks, [
        const ConsentBlock(ConsentBlockKind.section, '제3조 (계정)'),
        const ConsentBlock(
          ConsentBlockKind.paragraph,
          '1. 계정은 카카오·네이버·구글·애플 로그인으로 만듭니다.',
        ),
        const ConsentBlock(
          ConsentBlockKind.paragraph,
          '2. 로그인 수단마다 별개의 계정이 만들어집니다. 다른 수단으로 로그인하면 '
          '이전 계정의 정보가 보이지 않습니다.',
        ),
        const ConsentBlock(ConsentBlockKind.section, '제5조 (서비스의 변경·중단)'),
        const ConsentBlock(
          ConsentBlockKind.paragraph,
          '회사는 서비스 내용을 변경하거나 중단할 수 있습니다.',
        ),
      ]);
    });

    test('서비스 이용약관 전문에서 조항 9개(제5조의2·의3 포함)가 모두 제목이 된다 (#430 #475)', () {
      final terms = consentItems.firstWhere((d) => d.key == 'termsAgreed');
      final sections = parseConsentBody(terms.body)
          .where((b) => b.kind == ConsentBlockKind.section)
          .map((b) => b.text)
          .toList();

      expect(sections, hasLength(9));
      expect(sections, everyElement(startsWith('제')));
      expect(sections, containsAll(['제5조의2 (광고)', '제5조의3 (그림 출처)']));
    });

  });


  // 이슈 #376 — `이름   값` 처럼 공백 여러 칸으로 맞춘 표 행이 앞 행의 이어지는
  // 문장으로 붙어 한 문단이 됐다. 법적 고지라 항목이 바뀌는 곳이 보여야 한다.

  group('실제 약관', () {

    // 표 행이 앞 문장에 붙으면 원문의 맞춤 공백(두 칸 이상)이 덩이 안에 남는다.
    // 그게 남아 있으면 어딘가에서 또 붙었다는 뜻이다.
    test('어느 문서에도 맞춤 공백이 덩이 안에 남지 않는다 (#376)', () {
      for (final item in consentItems) {
        for (final block in parseConsentBody(item.body)) {
          expect(
            block.text.contains(RegExp(r'\S {2,}\S')),
            isFalse,
            reason: '${item.label}: "$block" 에 맞춤 공백이 남았다 — 표 행이 붙었다',
          );
        }
      }
    });

    test('빈 문자열은 빈 목록이다 — 화면이 죽지 않는다', () {
      expect(parseConsentBody(''), isEmpty);
      expect(parseConsentBody('   \n  \n'), isEmpty);
    });
  });

  // 이슈 #475 — 조항 제목은 `제N조` 뿐 아니라 `제N조의M` 도 있다. 이걸 놓치면
  // 제5조의2·의3 이 평범한 문단 글씨로 나온다. 대괄호 없는 소제목은 다음 문단에 붙었다.
}
