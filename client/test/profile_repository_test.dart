import 'package:dio/dio.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/features/member/data/member_repository.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/domain/invite_problem.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/fake_dio.dart';

/// 초대·함께하는 사람·나가기 API 호출 (#362 · 서버 #361).
///
/// 응답은 서버 DTO(`ProfileInviteResponse` · `ProfileJoinResponse` · `GuardianResponse`)
/// 모양 그대로 둔다 — 가짜가 편한 모양이면 앱이 실제 서버 앞에서 깨진다.
void main() {
  late FakeAdapter adapter;

  ProfileRepository build(Map<String, Object?> routes) {
    adapter = FakeAdapter(routes);
    final dio = Dio(BaseOptions(baseUrl: 'https://test.local'))
      ..httpClientAdapter = adapter;
    return ProfileRepository(dio: dio);
  }

  group('초대 코드 발급', () {
    test('코드와 남은 초를 받는다 — 시계 차이를 피하려고 남은 초로 만료를 계산한다', () async {
      final repo = build({
        'POST /api/profiles/p-1/invites': {
          'code': 'A7K3M9',
          'expiresAt': '2026-10-01T10:40:00',
          'expiresInSeconds': 600,
        },
      });

      final r = await repo.issueInvite('p-1');

      expect(r.isOk, isTrue);
      expect(r.value!.code, 'A7K3M9');
      expect(r.value!.remaining().inSeconds, inInclusiveRange(598, 600));
    });

    test('서버 실패는 코드와 문구를 그대로 담는다 (이룸이 휴대폰·연결 안 됨·시도 한도)', () async {
      for (final (status, code) in [
        (403, 'DEVICE_LINK_FORBIDDEN_FOR_ELUMI'),
        (403, 'PROFILE_ACCESS_DENIED'),
        (429, 'PROFILE_INVITE_TOO_MANY_ATTEMPTS'),
      ]) {
        final repo = build({
          'POST /api/profiles/p-1/invites': FakeHttpError(
            status,
            errorCode: code,
            errorMessage: '서버 문구 $code',
          ),
        });

        final r = await repo.issueInvite('p-1');

        expect(r.isOk, isFalse);
        expect(r.failure!.server!.code.wire, code);
        expect(r.failure!.serverMessage, '서버 문구 $code');
      }
    });

  });

  group('초대 코드 넣기', () {
    test('실패 코드마다 화면이 쓸 갈래로 나뉜다 (E1·E2·E5·E6·E7·E8)', () async {
      final cases = <(int, String, InviteProblem)>[
        (404, 'PROFILE_INVITE_NOT_FOUND', InviteProblem.notFound),
        (410, 'PROFILE_INVITE_EXPIRED', InviteProblem.expired),
        (429, 'PROFILE_INVITE_TOO_MANY_ATTEMPTS', InviteProblem.tooManyAttempts),
        (409, 'PROFILE_ALREADY_GUARDIAN', InviteProblem.alreadyGuardian),
        (403, 'CONSENT_REQUIRED', InviteProblem.consentRequired),
        (403, 'DEVICE_LINK_FORBIDDEN_FOR_ELUMI', InviteProblem.forbiddenForElumi),
        (400, 'INVALID_INPUT_VALUE', InviteProblem.invalidInput),
      ];
      for (final (status, code, expected) in cases) {
        final repo = build({
          'POST /api/profile-invites/redeem': FakeHttpError(
            status,
            errorCode: code,
            errorMessage: '서버 문구',
          ),
        });

        final r = await repo.redeemInvite('A7K3M9');

        expect(r.isOk, isFalse, reason: code);
        expect(InviteProblem.of(r.failure!), expected, reason: code);
      }
    });

  });

  group('함께하는 사람', () {
    test('서버 응답 모양 그대로 읽는다 — 계정 ID 없이 관계 ID·me·이름·구분', () async {
      final repo = build({
        'GET /api/profiles/p-1/guardians': {
          'guardians': [
            {
              'id': 'g-1',
              'me': true,
              'displayName': '엄마',
              'kind': 'GUARDIAN',
              'joinedAt': '2026-10-01T09:00:00',
            },
            {
              'id': 'g-2',
              'me': false,
              'displayName': null,
              'kind': 'CAREGIVER',
              'joinedAt': '2026-10-01T09:30:00',
            },
          ],
        },
      });

      final r = await repo.listGuardians('p-1');

      final list = r.value!;
      expect(list.map((g) => g.id), ['g-1', 'g-2']);
      expect(list[0].me, isTrue);
      expect(list[0].label, '엄마');
      expect(list[0].kind, GuardianKind.guardian);
      // 이름이 비면 앱이 "보호자"로 부른다 (서버 문서)
      expect(list[1].label, '보호자');
      expect(list[1].kind, GuardianKind.caregiver);
      expect(list[1].joinedAt, DateTime(2026, 10, 1, 9, 30));
    });

    test('guardians 필드가 없으면 빈 목록이 아니라 앱 오류다 — 빈 상태와 실패를 섞지 않는다', () async {
      final repo = build({'GET /api/profiles/p-1/guardians': <String, Object?>{}});

      final r = await repo.listGuardians('p-1');

      expect(r.isOk, isFalse);
    });

  });

  group('이룸이에서 나가기', () {
    test('실패하면 서버가 준 이유를 돌려준다 (E20)', () async {
      final repo = build({
        'DELETE /api/profiles/p-1/guardians/me': const FakeHttpError(
          403,
          errorCode: 'PROFILE_ACCESS_DENIED',
          errorMessage: '이 이룸이의 정보를 볼 수 없어요.',
        ),
      });

      final failure = await repo.leave('p-1');

      expect(failure, isNotNull);
      expect(failure!.server!.code, ServerErrorCode.profileAccessDenied);
    });
  });

  group('회원 정보의 이룸이 목록 (서버 #360 · MemberResponse.profiles)', () {
    test('목록이 비어 온 것과 목록이 아예 없는 것을 구분한다 — 옛 서버를 이룸이 없음으로 읽지 않는다', () {
      expect(Member.fromJson({'profiles': <Object>[]}).profilesKnown, isTrue);
      expect(Member.fromJson({'nickname': 'a'}).profilesKnown, isFalse);
      expect(Member.fromJson({'profiles': 'x'}).profilesKnown, isFalse);
    });

  });
}
