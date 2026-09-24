import 'package:elum/features/auth/domain/consent_body.dart';
import 'package:elum/features/auth/domain/consent_documents.dart';
import 'package:flutter_test/flutter_test.dart';

/// 탈퇴 뒤 보관 조항 (이슈 #372).
///
/// 서버가 탈퇴 계정을 1년 남기게 바뀌었으므로 번들 방침도 같은 말을 해야 한다.
/// 번들은 네트워크가 없을 때 가입 화면이 보여주는 최후의 원본이다.
void main() {
  final privacy = consentItems.firstWhere((i) => i.key == 'privacyAgreed').body;
  // 하드랩된 원문이라 줄바꿈을 공백으로 펴서 본다.
  final flat = privacy.replaceAll(RegExp(r'\s+'), ' ');

  test('번들 버전은 보관 조항을 넣은 판이다', () {
    expect(consentVersion, '2026-09-24');
  });

  test('보관 기간 1년과 보관 항목·목적·복원·즉시 삭제를 적는다', () {
    expect(flat, contains('탈퇴일로부터 1년간 보관한 뒤 파기합니다'));
    expect(flat, contains('소셜 로그인 제공자와 그 회원 식별번호, 서비스 아이디'));
    expect(flat, contains('AI 기능 이용 기록(이용 일시·횟수)'));
    expect(flat, contains('부정 이용 방지 외의 목적으로 이용하지 않습니다'));
    expect(flat, contains('이전 계정이 빈 상태로 복원되어'));
    expect(flat, contains('즉시 삭제를 요구하시면 지체 없이 파기합니다'));
    // 탈퇴하면 계정까지 곧바로 지운다는 옛 약속이 남으면 동작과 어긋난다.
    expect(flat, isNot(contains('계정·이룸이 정보·일과·로그인 토큰을 지체 없이 삭제합니다')));
  });

  test('시행일은 10월 1일이고 두 번의 변경이 모두 보인다', () {
    expect(flat, contains('이 방침은 2026년 10월 1일부터 적용됩니다.'));
    expect(flat, contains('2026년 9월 23일 공고, 9월 30일 시행'));
    expect(flat, contains('2026년 9월 24일 공고, 10월 1일 시행'));
  });

  test('줄바꿈 자리가 조항 제목으로 잘못 읽히지 않는다', () {
    // "4. 보유 기간" 같은 말이 줄 맨 앞에 오면 파서가 새 조항으로 읽는다.
    final sections = parseConsentBody(privacy)
        .where((b) => b.kind == ConsentBlockKind.section)
        .map((b) => b.text)
        .toList();

    expect(sections, [
      '0. 누가 입력하고, 누가 동의하나',
      '1. 수집하는 항목',
      '2. 수집하지 않는 항목',
      '3. 이용 목적',
      '4. 보유 기간',
      '5. 보호자의 권리',
      '6. 동의를 거부할 권리',
      '7. 안전성 확보 조치',
      '8. 처리 위탁',
      '9. 국외 이전',
      '10. 개인정보 보호책임자',
      '11. 시행일',
    ]);
  });
}
