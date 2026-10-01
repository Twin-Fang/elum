import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/onboarding/domain/image_style.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/domain/invite_problem.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';
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

  const joinBody = {
    'profile': {
      'id': 'p-9',
      'nickname': '하늘이',
      'character': 'POPO',
      'imageStyle': 'REALISTIC',
    },
    'removedProfileIds': ['p-empty'],
  };

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

    test('응답에 코드가 없으면 앱 오류로 돌려준다 — 빈 코드를 화면에 띄우지 않는다', () async {
      final repo = build({
        'POST /api/profiles/p-1/invites': {'expiresInSeconds': 600},
      });

      final r = await repo.issueInvite('p-1');

      expect(r.isOk, isFalse);
      expect(r.failure!.fault, NetworkFault.app);
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

    test('인터넷이 없으면 오프라인으로 돌려준다 (E47)', () async {
      final repo = build({'POST /api/profiles/p-1/invites': const FakeOffline()});

      final r = await repo.issueInvite('p-1');

      expect(r.failure!.fault, NetworkFault.offline);
      expect(r.failure!.badgeOr('E-INV-NEW'), 'E-NET-OFFLINE');
    });
  });

  group('초대 코드 넣기', () {
    test('소문자·공백·하이픈을 정리해 대문자로 보낸다 (이름은 비면 보내지 않는다)', () async {
      final repo = build({'POST /api/profile-invites/redeem': joinBody});

      await repo.redeemInvite(' a7k-3m9 ');

      expect(adapter.sentBodies['POST /api/profile-invites/redeem'], {'code': 'A7K3M9'});
    });

    test('불릴 이름을 주면 함께 보낸다 (20자 이하)', () async {
      final repo = build({'POST /api/profile-invites/redeem': joinBody});

      await repo.redeemInvite('A7K3M9', displayName: '아빠');

      expect(adapter.sentBodies['POST /api/profile-invites/redeem'], {
        'code': 'A7K3M9',
        'displayName': '아빠',
      });
    });

    test('합류한 이룸이와 지워진 빈 이룸이 id 를 받는다', () async {
      final repo = build({'POST /api/profile-invites/redeem': joinBody});

      final r = await repo.redeemInvite('A7K3M9');

      expect(r.isOk, isTrue);
      final join = r.value!;
      expect(join.profile.id, 'p-9');
      expect(join.profile.nickname, '하늘이');
      expect(join.profile.character, 'POPO');
      expect(join.profile.imageStyle, ImageStyle.realistic);
      expect(join.removedProfileIds, ['p-empty']);
    });

    test('removedProfileIds 가 없거나 모양이 달라도 죽지 않는다', () async {
      final repo = build({
        'POST /api/profile-invites/redeem': {
          'profile': {'id': 'p-9'},
          'removedProfileIds': 'x',
        },
      });

      final r = await repo.redeemInvite('A7K3M9');

      expect(r.isOk, isTrue);
      expect(r.value!.removedProfileIds, isEmpty);
      expect(r.value!.profile.nickname, isNull);
    });

    test('응답에 이룸이 id 가 없으면 실패다 — 어느 이룸이에 합류했는지 모른다', () async {
      final repo = build({
        'POST /api/profile-invites/redeem': {'profile': <String, Object?>{}},
      });

      final r = await repo.redeemInvite('A7K3M9');

      expect(r.isOk, isFalse);
      expect(r.failure!.fault, NetworkFault.app);
    });

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

    test('코드 이름을 몰라도 상태 코드로 갈래를 잡는다 — 프록시가 본문을 지워도', () {
      AppFailure bare(int status) => AppFailure(
        fault: NetworkFault.none,
        server: ServerError(code: ServerErrorCode.unknown, statusCode: status),
      );

      expect(InviteProblem.of(bare(404)), InviteProblem.notFound);
      expect(InviteProblem.of(bare(410)), InviteProblem.expired);
      expect(InviteProblem.of(bare(429)), InviteProblem.tooManyAttempts);
      expect(InviteProblem.of(bare(409)), InviteProblem.alreadyGuardian);
      expect(InviteProblem.of(bare(500)), InviteProblem.other);
    });

    test('인터넷이 없으면 offline 이다 (E47)', () async {
      final repo = build({'POST /api/profile-invites/redeem': const FakeOffline()});

      final r = await repo.redeemInvite('A7K3M9');

      expect(InviteProblem.of(r.failure!), InviteProblem.offline);
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

    test('모르는 구분 값이나 깨진 항목이 섞여도 목록은 산다', () async {
      final repo = build({
        'GET /api/profiles/p-1/guardians': {
          'guardians': [
            {'id': 'g-1', 'me': true, 'kind': 'FUTURE_KIND'},
            'broken',
            {'me': false},
          ],
        },
      });

      final r = await repo.listGuardians('p-1');

      expect(r.value!.map((g) => g.id), ['g-1']);
      expect(r.value!.single.kind, GuardianKind.guardian);
    });

    test('guardians 필드가 없으면 빈 목록이 아니라 앱 오류다 — 빈 상태와 실패를 섞지 않는다', () async {
      final repo = build({'GET /api/profiles/p-1/guardians': <String, Object?>{}});

      final r = await repo.listGuardians('p-1');

      expect(r.isOk, isFalse);
    });

    test('내 이름·구분을 고친다 — 보낸 항목만 실린다', () async {
      final repo = build({
        'PATCH /api/profiles/p-1/guardians/me': {
          'id': 'g-1',
          'me': true,
          'displayName': '센터 선생님',
          'kind': 'CAREGIVER',
          'joinedAt': '2026-10-01T09:00:00',
        },
      });

      final r = await repo.updateMyGuardian(
        'p-1',
        kind: GuardianKind.caregiver,
        displayName: '센터 선생님',
      );

      expect(r.value!.label, '센터 선생님');
      expect(adapter.sentBodies['PATCH /api/profiles/p-1/guardians/me'], {
        'kind': 'CAREGIVER',
        'displayName': '센터 선생님',
      });
    });
  });

  group('이룸이에서 나가기', () {
    test('성공하면 null 이다 (서버는 204 를 준다)', () async {
      final repo = build({'DELETE /api/profiles/p-1/guardians/me': <String, Object?>{}});

      expect(await repo.leave('p-1'), isNull);
    });

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
    test('profiles 를 읽는다 — 먼저 연결된 차례 그대로', () {
      final member = Member.fromJson({
        'nickname': '하늘이',
        'profiles': [
          {'id': 'p-1', 'nickname': '하늘이', 'character': 'LULU', 'imageStyle': 'CARTOON'},
          {'id': 'p-2', 'nickname': null, 'character': null, 'imageStyle': 'PHOTO_ONLY'},
        ],
      });

      expect(member.profiles.map((p) => p.id), ['p-1', 'p-2']);
      expect(member.profiles[1].nickname, isNull);
      expect(member.profiles[1].displayName, '이룸이');
      expect(member.profiles[1].imageStyle, ImageStyle.photoOnly);
    });

    test('목록이 비어 온 것과 목록이 아예 없는 것을 구분한다 — 옛 서버를 이룸이 없음으로 읽지 않는다', () {
      expect(Member.fromJson({'profiles': <Object>[]}).profilesKnown, isTrue);
      expect(Member.fromJson({'nickname': 'a'}).profilesKnown, isFalse);
      expect(Member.fromJson({'profiles': 'x'}).profilesKnown, isFalse);
    });

    test('옛 서버(필드 없음)나 깨진 모양이어도 빈 목록이다', () {
      expect(Member.fromJson({'nickname': 'a'}).profiles, isEmpty);
      expect(Member.fromJson({'profiles': 'x'}).profiles, isEmpty);
      expect(
        Member.fromJson({
          'profiles': [
            {'nickname': 'id 없음'},
            7,
            {'id': 'p-1'},
          ],
        }).profiles.map((p) => p.id),
        ['p-1'],
      );
    });

    test('ProfileSummary 는 id 가 없으면 만들지 않는다', () {
      expect(ProfileSummary.tryParse({'nickname': 'x'}), isNull);
      expect(ProfileSummary.tryParse(null), isNull);
      expect(ProfileSummary.tryParse({'id': ''}), isNull);
    });
  });
}
