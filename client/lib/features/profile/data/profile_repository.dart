import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../link/domain/link_code.dart';
import '../../link/domain/link_status.dart';
import '../domain/guardian_member.dart';
import '../domain/profile_summary.dart';
import '../../../app/dio_provider.dart';

/// 초대 코드로 합류한 결과 — 서버 `ProfileJoinResponse`.
@immutable
class ProfileJoin {
  const ProfileJoin({required this.profile, this.removedProfileIds = const []});

  /// 합류한 이룸이. 이 id 를 `X-Profile-Id` 로 쓴다.
  final ProfileSummary profile;

  /// 합류하면서 서버가 지운 빈 이룸이. 가입 때 자동으로 생긴 것 중 이름도 일과도 없던 것이다.
  /// 앱이 이 id 를 들고 있었다면 버린다.
  final List<String> removedProfileIds;
}

/// 초대·함께하는 사람·나가기.
///
/// **절대 throw하지 않는다.** 실패는 [Attempt]·[AppFailure] 로 돌려준다 — 서버가 알려준
/// 코드·문구를 화면이 그대로 띄울 수 있어야 하고, 호출부마다 catch 가 흩어지면
/// 빠뜨린 곳에서 화면이 죽는다.
class ProfileRepository {
  ProfileRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  /// 초대 코드를 만든다. 이전에 만든 미사용 코드는 서버가 폐기한다 (E9).
  Future<Attempt<IssuedLinkCode>> issueInvite(String profileId) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/profiles/$profileId/invites',
      );
      final code = res.data?['code']?.toString();
      // 서버의 절대 시각이 아니라 **남은 초**를 쓴다 — 두 시계가 어긋나면 남은 시간이
      // 실제보다 길게 나온다 (연결 암호와 같은 이유).
      final seconds = (res.data?['expiresInSeconds'] as num?)?.toInt();
      if (code == null || code.isEmpty || seconds == null || seconds <= 0) {
        // 코드 원문은 로그에 남기지 않는다. 있고 없고만 적는다.
        AppLogger.error('초대 코드 발급', '응답에 code/expiresInSeconds가 없습니다');
        return const Attempt.failed(AppFailure(fault: NetworkFault.app));
      }
      return Attempt.ok(
        IssuedLinkCode.fromNow(code: code, expiresInSeconds: seconds),
      );
    } catch (e) {
      AppLogger.error('초대 코드 발급', e);
      return Attempt.failed(AppFailure.of(e));
    }
  }

  /// 초대 코드를 넣어 이룸이에 합류한다.
  ///
  /// [rawCode] 는 소문자·공백·하이픈이 섞여도 된다 — 서버도 받아 주지만 여기서 한 번 더
  /// 정리해 보낸다. [displayName] 은 이 이룸이 안에서 불릴 이름이다(선택, 20자 이하).
  ///
  /// ⚠️ 코드는 자격증명이다. **로그에 남기지 않는다.**
  Future<Attempt<ProfileJoin>> redeemInvite(
    String rawCode, {
    String? displayName,
  }) async {
    final name = displayName?.trim();
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/profile-invites/redeem',
        data: {
          'code': LinkCode.normalize(rawCode),
          if (name != null && name.isNotEmpty) 'displayName': name,
        },
      );
      final profile = ProfileSummary.tryParse(res.data?['profile']);
      if (profile == null) {
        // 합류는 됐을 수 있지만 어느 이룸이인지 모르면 이어 갈 수 없다.
        AppLogger.error('초대 코드 넣기', '응답에 profile.id가 없습니다');
        return const Attempt.failed(AppFailure(fault: NetworkFault.app));
      }
      final removed = switch (res.data?['removedProfileIds']) {
        final List<dynamic> list => list.map((e) => e.toString()).toList(),
        _ => const <String>[],
      };
      return Attempt.ok(ProfileJoin(profile: profile, removedProfileIds: removed));
    } catch (e) {
      AppLogger.error('초대 코드 넣기', AppFailure.of(e));
      return Attempt.failed(AppFailure.of(e));
    }
  }

  /// 이 이룸이를 함께 돌보는 사람 목록. 합류한 차례다.
  ///
  /// **`guardians` 필드가 없으면 빈 목록이 아니라 실패다.** 서버는 이룸이에 보호자가 한 명
  /// 이상 있어야 이 응답을 주므로, 비어 오는 것은 형식이 다른 것이다 — 빈 상태와 실패를
  /// 같게 그리면 나가기 확인이 "마지막 보호자"를 잘못 판단한다.
  Future<Attempt<List<Guardian>>> listGuardians(String profileId) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/api/profiles/$profileId/guardians',
      );
      final raw = res.data?['guardians'];
      if (raw is! List) {
        AppLogger.error('함께하는 사람', '응답에 guardians가 없습니다');
        return const Attempt.failed(AppFailure(fault: NetworkFault.app));
      }
      return Attempt.ok(
        raw.map(Guardian.tryParse).whereType<Guardian>().toList(),
      );
    } catch (e) {
      AppLogger.error('함께하는 사람', e);
      return Attempt.failed(AppFailure.of(e));
    }
  }

  /// 내 이름·구분을 고친다. 보낸 항목만 바뀐다. 대상은 항상 나다 — 남의 표시는 못 고친다.
  Future<Attempt<Guardian>> updateMyGuardian(
    String profileId, {
    GuardianKind? kind,
    String? displayName,
  }) async {
    try {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/profiles/$profileId/guardians/me',
        data: {
          if (kind != null) 'kind': kind.apiValue,
          if (displayName != null) 'displayName': displayName.trim(),
        },
      );
      final guardian = Guardian.tryParse(res.data);
      if (guardian == null) {
        AppLogger.error('내 이름 고치기', '응답에 id가 없습니다');
        return const Attempt.failed(AppFailure(fault: NetworkFault.app));
      }
      return Attempt.ok(guardian);
    } catch (e) {
      AppLogger.error('내 이름 고치기', e);
      return Attempt.failed(AppFailure.of(e));
    }
  }

  /// 이 이룸이에서 나간다. null 이면 나갔다(서버는 204). 실패하면 서버가 알려준 이유가 담긴다.
  ///
  /// 서버는 **한 트랜잭션**으로 처리한다 — 중간에 실패하면 아무것도 지워지지 않았다.
  Future<AppFailure?> leave(String profileId) async {
    try {
      await _dio.delete<dynamic>('/api/profiles/$profileId/guardians/me');
      return null;
    } catch (e) {
      AppLogger.error('이룸이에서 나가기', e);
      return AppFailure.of(e);
    }
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>(
  (ref) => ProfileRepository(dio: ref.watch(dioProvider)),
);
