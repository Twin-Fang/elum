
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/profile/application/profile_display_name.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const qa = ProfileSummary(id: 'qa', nickname: 'QA');
  const other = ProfileSummary(id: 'other', nickname: '다른 이룸이');

  test('선택한 QA 이름이 회원 응답의 다른 이름보다 우선한다', () {
    expect(
      resolveProfileDisplayName(
        const Member(nickname: '이룸이', profiles: [other, qa]),
        'qa',
        '로컬 이름',
      ),
      'QA',
    );
  });

  test('선택한 프로필 이름이 비어도 다른 프로필 이름으로 바꾸지 않는다', () {
    expect(
      resolveProfileDisplayName(
        const Member(
          nickname: '다른 이룸이',
          profiles: [
            ProfileSummary(id: 'qa', nickname: '  '),
            other,
          ],
        ),
        'qa',
        'QA',
      ),
      'QA',
    );
  });

}
