import 'package:elum/features/auth/domain/consent_body.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:flutter_test/flutter_test.dart';

/// 약관 전문 파서 (이슈 #235).
///
/// 전문을 통짜 `Text` 하나로 그리던 것을 덩이로 나눴다. **원문은 하드랩되어
/// 있어** 그대로 두면 화면 폭에 맞춰 다시 줄바꿈되며 줄이 들쭉날쭉해진다.
void main() {
  group('덩이 나누기', () {
    test('번호가 붙은 줄은 섹션 제목이다 — 번호를 살린다', () {
      final blocks = parseConsentBody('1. 수집하는 항목');

      expect(blocks, [
        const ConsentBlock(ConsentBlockKind.section, '1. 수집하는 항목'),
      ]);
    });

    test('대괄호로 감싼 줄은 소제목이다', () {
      final blocks = parseConsentBody('[계정]');

      expect(blocks, [
        const ConsentBlock(ConsentBlockKind.subsection, '계정'),
      ]);
    });

    test('대괄호 뒤에 꼬리가 붙어도 소제목이다', () {
      final blocks = parseConsentBody('[이룸이 정보] — 보호자가 직접 입력합니다');

      // 실제 약관에 이런 줄이 있다. 놓치면 소제목이 평범한 문단으로 묻힌다.
      expect(blocks, [
        const ConsentBlock(
          ConsentBlockKind.subsection,
          '이룸이 정보 — 보호자가 직접 입력합니다',
        ),
      ]);
    });

    test('하이픈으로 시작하면 불릿이다', () {
      final blocks = parseConsentBody('- 이메일 주소');

      expect(blocks, [
        const ConsentBlock(ConsentBlockKind.bullet, '이메일 주소'),
      ]);
    });

    test('빈 줄이 덩이를 끊는다', () {
      final blocks = parseConsentBody('첫 문단\n\n둘째 문단');

      expect(blocks, [
        const ConsentBlock(ConsentBlockKind.paragraph, '첫 문단'),
        const ConsentBlock(ConsentBlockKind.paragraph, '둘째 문단'),
      ]);
    });
  });

  group('하드랩 풀기', () {
    test('이어지는 줄을 한 문장으로 잇는다', () {
      final blocks = parseConsentBody('이룸은 보호자가 계정을 만들고,\n정보를 대신 입력합니다.');

      // 원문 줄바꿈을 그대로 두면 화면 폭과 무관하게 거기서 끊긴다.
      expect(blocks, [
        const ConsentBlock(
          ConsentBlockKind.paragraph,
          '이룸은 보호자가 계정을 만들고, 정보를 대신 입력합니다.',
        ),
      ]);
    });

    test('불릿의 다음 줄도 그 불릿에 붙는다', () {
      final blocks = parseConsentBody(
        '- 만 14세 미만인 경우 — 법정대리인입니다.\n'
        '  이 동의가 법이 정한 동의를 갈음합니다.\n'
        '- 다음 항목',
      );

      expect(blocks, [
        const ConsentBlock(
          ConsentBlockKind.bullet,
          '만 14세 미만인 경우 — 법정대리인입니다. 이 동의가 법이 정한 동의를 갈음합니다.',
        ),
        const ConsentBlock(ConsentBlockKind.bullet, '다음 항목'),
      ]);
    });
  });

  group('실제 약관', () {
    test('모든 항목의 전문이 덩이로 나뉜다', () {
      for (final item in consentItems) {
        final blocks = parseConsentBody(item.body);

        expect(blocks, isNotEmpty, reason: '${item.label}이 빈 덩이로 나왔다');
        // 통짜 한 덩이로 남으면 나눈 의미가 없다
        expect(blocks.length, greaterThan(1), reason: '${item.label}이 나뉘지 않았다');
      }
    });

    test('빈 문자열은 빈 목록이다 — 화면이 죽지 않는다', () {
      expect(parseConsentBody(''), isEmpty);
      expect(parseConsentBody('   \n  \n'), isEmpty);
    });
  });
}
