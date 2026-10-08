import 'dart:async';

import 'package:elum/core/storage/local_storage.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/onboarding/application/onboarding_notifier.dart';
import 'package:elum/features/profile/application/profile_display_name.dart';
import 'package:elum/features/profile/application/profile_session.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:elum/features/member/application/member_providers.dart';
import 'package:elum/core/storage/in_memory_storage.dart';

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

  test('전환 직후 옛 목록만 남으면 방금 선택한 로컬 이름을 유지한다', () {
    expect(
      resolveProfileDisplayName(
        const Member(nickname: '다른 이룸이', profiles: [other]),
        'qa',
        'QA',
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

  test('목록이 없는 구버전과 이룸이 휴대폰은 회원 이름을 사용한다', () {
    expect(
      resolveProfileDisplayName(const Member(nickname: ' QA '), null, '이룸이'),
      'QA',
    );
  });

  test('빈 회원 이름과 조회 실패는 로컬 이름을 유지한다', () {
    expect(
      resolveProfileDisplayName(const Member(nickname: '  '), null, 'QA'),
      'QA',
    );
    expect(resolveProfileDisplayName(null, 'qa', 'QA'), 'QA');
  });

  test('초대 합류 이름은 조회 대기 중에도 표시되고 응답 후에도 유지된다', () async {
    final response = Completer<Member?>();
    final storage = InMemoryStorage(nickname: 'QA', elumiDevice: true);
    await storage.setSelectedProfileId('qa');
    final container = ProviderContainer(
      overrides: [
        localStorageProvider.overrideWithValue(storage),
        memberProvider.overrideWith((ref) => response.future),
      ],
    );
    addTearDown(container.dispose);
    String currentName() => resolveProfileDisplayName(
      container.read(memberProvider).value,
      container.read(profileSessionProvider).selectedId,
      container.read(onboardingProvider).displayName,
    );
    expect(currentName(), 'QA');
    response.complete(const Member(nickname: '이룸이', profiles: [other, qa]));
    await container.read(memberProvider.future);
    expect(currentName(), 'QA');
  });
}
