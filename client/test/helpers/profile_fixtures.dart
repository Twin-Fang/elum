import 'package:dio/dio.dart';
import 'package:elum/core/network/app_failure.dart';
import 'package:elum/core/network/server_error.dart';
import 'package:elum/core/network/server_error_code.dart';
import 'package:elum/features/guardian/data/member_repository.dart';
import 'package:elum/features/link/domain/link_status.dart';
import 'package:elum/features/profile/data/profile_repository.dart';
import 'package:elum/features/profile/domain/guardian_member.dart';
import 'package:elum/features/profile/domain/profile_summary.dart';

/// 다중 보호자 화면 테스트가 같이 쓰는 이룸이 둘.
const kProfileA = ProfileSummary(id: 'p-a', nickname: '하늘이', character: 'LULU');
const kProfileB = ProfileSummary(id: 'p-b', nickname: '바다', character: 'POPO');

/// 서버가 코드와 문구를 준 실패. 문구는 서버가 준 것을 화면이 그대로 띄우는지 보려고 코드마다 다르게 둔다.
AppFailure serverFailure(int status, ServerErrorCode code, [String? message]) =>
    AppFailure(
      fault: NetworkFault.none,
      server: ServerError(
        code: code,
        message: message ?? '서버 문구 ${code.wire}',
        statusCode: status,
      ),
    );

Member memberWith(List<ProfileSummary> profiles, {String? nickname}) =>
    Member(
      nickname: nickname ?? profiles.firstOrNull?.nickname,
      profiles: profiles,
      // 서버가 목록을 줬다 — 비어 있으면 "연결된 이룸이가 없다"는 뜻이다
      profilesKnown: true,
    );

/// 서버를 흉내 내지 않는 가짜 — 화면이 **무엇을 불렀는지**와 **어떻게 실패하는지**만 본다.
///
/// 서버 응답 모양 자체는 `profile_repository_test.dart` 가 실제 DTO 모양으로 고정한다.
class FakeProfileRepository extends ProfileRepository {
  FakeProfileRepository() : super(dio: Dio());

  final calls = <String>[];

  /// 다음 호출이 돌려줄 값. 비우면 성공이다.
  Attempt<IssuedLinkCode> issueResult = Attempt.ok(
    IssuedLinkCode.fromNow(code: 'A7K3M9', expiresInSeconds: 600),
  );
  Attempt<ProfileJoin>? redeemResult;
  Attempt<List<Guardian>> guardiansResult = const Attempt.ok([
    Guardian(id: 'g-1', me: true, displayName: '엄마'),
    Guardian(id: 'g-2', me: false, kind: GuardianKind.caregiver),
  ]);
  AppFailure? leaveFailure;
  Attempt<Guardian>? updateResult;

  final sentCodes = <String>[];
  final sentNames = <String?>[];
  Map<String, Object?>? lastUpdate;

  @override
  Future<Attempt<IssuedLinkCode>> issueInvite(String profileId) async {
    calls.add('issue:$profileId');
    return issueResult;
  }

  @override
  Future<Attempt<ProfileJoin>> redeemInvite(
    String rawCode, {
    String? displayName,
  }) async {
    calls.add('redeem');
    sentCodes.add(rawCode);
    sentNames.add(displayName);
    return redeemResult ??
        Attempt.ok(ProfileJoin(profile: kProfileB, removedProfileIds: const []));
  }

  @override
  Future<Attempt<List<Guardian>>> listGuardians(String profileId) async {
    calls.add('list:$profileId');
    return guardiansResult;
  }

  @override
  Future<Attempt<Guardian>> updateMyGuardian(
    String profileId, {
    GuardianKind? kind,
    String? displayName,
  }) async {
    calls.add('update:$profileId');
    lastUpdate = {'kind': kind, 'displayName': displayName};
    return updateResult ??
        Attempt.ok(Guardian(id: 'g-1', me: true, displayName: displayName));
  }

  @override
  Future<AppFailure?> leave(String profileId) async {
    calls.add('leave:$profileId');
    return leaveFailure;
  }
}
