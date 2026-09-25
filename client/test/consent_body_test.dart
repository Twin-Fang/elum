import 'dart:io';

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

    test('서비스 이용약관 전문에서 조항 7개가 모두 제목이 된다 (#430)', () {
      final terms = consentItems.firstWhere((d) => d.key == 'termsAgreed');
      final sections = parseConsentBody(terms.body)
          .where((b) => b.kind == ConsentBlockKind.section)
          .map((b) => b.text)
          .toList();

      expect(sections, hasLength(7));
      expect(sections, everyElement(startsWith('제')));
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

  // 이슈 #376 — `이름   값` 처럼 공백 여러 칸으로 맞춘 표 행이 앞 행의 이어지는
  // 문장으로 붙어 한 문단이 됐다. 법적 고지라 항목이 바뀌는 곳이 보여야 한다.
  group('표 행 (#376)', () {
    test('L1 이름 다음 공백이 두 칸 이상이면 표 행이다', () {
      final blocks = parseConsentBody('이전되는 국가  미국');

      expect(blocks, [
        const ConsentBlock(ConsentBlockKind.row, '미국', label: '이전되는 국가'),
      ]);
    });

    test('L1 연달아 오는 표 행은 줄마다 한 항목이다 — 앞 행에 붙지 않는다', () {
      final blocks = parseConsentBody(
        '이전되는 국가  미국\n'
        '이전 일시     카드를 만들 때마다 (네트워크를 통해 전송)\n'
        '이전 방법     HTTPS 암호화 전송',
      );

      expect(blocks, [
        const ConsentBlock(ConsentBlockKind.row, '미국', label: '이전되는 국가'),
        const ConsentBlock(
          ConsentBlockKind.row,
          '카드를 만들 때마다 (네트워크를 통해 전송)',
          label: '이전 일시',
        ),
        const ConsentBlock(ConsentBlockKind.row, 'HTTPS 암호화 전송', label: '이전 방법'),
      ]);
    });

    test('L2 공백 한 칸짜리 문장은 지금처럼 문단으로 잇는다', () {
      final blocks = parseConsentBody('일과 카드를 만들 때 아래 정보가\n국외로 전달됩니다.');

      expect(blocks, [
        const ConsentBlock(
          ConsentBlockKind.paragraph,
          '일과 카드를 만들 때 아래 정보가 국외로 전달됩니다.',
        ),
      ]);
    });

    test('L3 들여쓴 다음 줄은 같은 항목의 다음 값으로 줄을 바꿔 붙는다', () {
      final blocks = parseConsentBody(
        '전달받는 자   Google LLC (policies.google.com/privacy)\n'
        '             OpenAI, L.L.C. (openai.com/policies/privacy-policy)\n'
        '이전되는 국가  미국',
      );

      expect(blocks, [
        const ConsentBlock(
          ConsentBlockKind.row,
          'Google LLC (policies.google.com/privacy)\n'
              'OpenAI, L.L.C. (openai.com/policies/privacy-policy)',
          label: '전달받는 자',
        ),
        const ConsentBlock(ConsentBlockKind.row, '미국', label: '이전되는 국가'),
      ]);
    });

    // 원문은 긴 값도 하드랩한다(`이룸이를 부르는 / 이름(별명)`). 이걸 줄바꿈으로
    // 두면 `이름(별명)`이 따로 떨어져 **다른 값처럼** 읽힌다.
    test('L3 값이 문장 가운데서 끊긴 들여쓴 줄은 띄어 잇는다 — 하드랩', () {
      final blocks = parseConsentBody(
        '- 이전 항목     보호자가 쓴 상황 설명과 추가 질문 답변, 이룸이를 부르는\n'
        '               이름(별명), 선택한 도움 목표',
      );

      expect(blocks, [
        const ConsentBlock(
          ConsentBlockKind.row,
          '보호자가 쓴 상황 설명과 추가 질문 답변, 이룸이를 부르는 이름(별명), 선택한 도움 목표',
          label: '이전 항목',
          bulleted: true,
        ),
      ]);
    });

    test('L3 들여쓰지 않은 다음 줄은 표에 붙지 않고 새 문단이다', () {
      final blocks = parseConsentBody('보내는 방법   앱 알림, 이메일\n이 동의는 선택입니다.');

      expect(blocks, [
        const ConsentBlock(ConsentBlockKind.row, '앱 알림, 이메일', label: '보내는 방법'),
        const ConsentBlock(ConsentBlockKind.paragraph, '이 동의는 선택입니다.'),
      ]);
    });

    test('불릿 안의 표 행도 표 행이다 — 점은 남긴다', () {
      final blocks = parseConsentBody(
        '- 서비스명    이룸(ELUM)\n'
        '- 보호책임자   서새찬',
      );

      expect(blocks, [
        const ConsentBlock(
          ConsentBlockKind.row,
          '이룸(ELUM)',
          label: '서비스명',
          bulleted: true,
        ),
        const ConsentBlock(
          ConsentBlockKind.row,
          '서새찬',
          label: '보호책임자',
          bulleted: true,
        ),
      ]);
    });

    test('이름이 길면 표 행으로 보지 않는다 — 문장 속 두 칸 공백 오탐 방지', () {
      final blocks = parseConsentBody('회사는 서비스 내용을 변경하거나 중단할 수  있습니다.');

      expect(blocks.single.kind, ConsentBlockKind.paragraph);
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

    test('국외 이전 동의서 — 전달받는 자 세 곳이 한 항목의 세 줄이다 (#376)', () {
      final overseas = consentItems.firstWhere((e) => e.key == 'overseasTransferAgreed');
      final rows = parseConsentBody(overseas.body)
          .where((b) => b.kind == ConsentBlockKind.row)
          .toList();

      expect(rows.map((r) => r.label), ['전달받는 자', '이전되는 국가', '이전 일시', '이전 방법']);
      expect(rows.first.text.split('\n'), hasLength(3));
    });

    test('개인정보처리방침 9조·10조도 표 행으로 나뉜다 (#376)', () {
      final privacy = consentItems.firstWhere((e) => e.key == 'privacyAgreed');
      final labels = parseConsentBody(privacy.body)
          .where((b) => b.kind == ConsentBlockKind.row)
          .map((b) => b.label)
          .toList();

      expect(labels, containsAllInOrder(['이전받는 자', '이전되는 국가', '이전 항목']));
      expect(labels, containsAllInOrder(['서비스명', '운영', '보호책임자', '문의']));
    });

    // L5 — 서버본·캐시·번들은 같은 파서를 지나므로, 서버가 떠낸 원본이 번들과
    // 같은 덩이로 나오면 세 경로 모두 같은 모양이다.
    test('L5 서버 원본(resources/consent)도 번들과 같은 덩이로 나뉜다 (#376)', () {
      const files = {
        'termsAgreed': 'terms.txt',
        'privacyAgreed': 'privacy.txt',
        'overseasTransferAgreed': 'overseas.txt',
        'guardianConfirmed': 'age.txt',
        'marketingAgreed': 'marketing.txt',
      };
      for (final MapEntry(:key, :value) in files.entries) {
        final file = File('../server/src/main/resources/consent/$value');
        if (!file.existsSync()) continue; // 클라이언트만 받은 경우
        final bundle = consentItems.firstWhere((e) => e.key == key);
        expect(
          parseConsentBody(file.readAsStringSync()),
          parseConsentBody(bundle.body),
          reason: '$value 가 번들과 다르게 나뉜다',
        );
      }
    });

    test('빈 문자열은 빈 목록이다 — 화면이 죽지 않는다', () {
      expect(parseConsentBody(''), isEmpty);
      expect(parseConsentBody('   \n  \n'), isEmpty);
    });
  });
}
