import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/guarded_call.dart';
import '../../../core/network/server_error_code.dart';
import '../../onboarding/domain/image_style.dart';
import '../../profile/domain/profile_summary.dart';

/// 보호자 회원 정보 — 서버 `MemberResponse`에 대응한다.
///
/// 출처: server/.../member/application/dto/response/MemberResponse.java
@immutable
class Member {
  const Member({
    this.nickname,
    this.totalStars = 0,
    this.supportGoals = const [],
    this.imageStyle = ImageStyle.cartoon,
    this.profiles = const [],
    this.adsRemoved = false,
    bool? profilesKnown,
  }) : _profilesKnown = profilesKnown;

  /// 아이 호칭. 미설정이면 null이다 (서버가 null을 준다).
  final String? nickname;

  /// 누적 획득 별 개수
  final int totalStars;

  /// 선택한 도움 목표의 서버 enum 값
  final List<String> supportGoals;

  /// 카드 그림 방식 (#458). 필드가 없거나 모르는 값이면 만화다 —
  /// 옛 서버·새 값이 와도 화면이 죽지 않는다.
  final ImageStyle imageStyle;

  /// 연결된 이룸이 목록 — 먼저 연결된 차례 (다중 보호자 #360 · `MemberResponse.profiles`).
  ///
  /// 옛 서버(필드 없음)나 모양이 달라도 빈 목록이다. 위 [nickname] 등은 `X-Profile-Id` 로
  /// 짚은 이룸이(없으면 첫 이룸이)의 값이다.
  final List<ProfileSummary> profiles;

  /// 이 계정의 요금제가 광고를 없애는가 (`entitlements.adsRemoved` · 요금제별 `*_ADS_REMOVED`).
  ///
  /// 필드가 없거나 모양이 달라도 false(광고 표시)다. 광고 게이트가 이 값으로 Pro 의 광고를 끈다.
  final bool adsRemoved;

  final bool? _profilesKnown;

  /// 응답에 이룸이 목록이 **있었는가.** 옛 서버(다중 보호자 이전)는 필드가 없다 — 그때 빈
  /// [profiles] 는 "이룸이가 없다"가 아니라 "모른다"다. 둘을 섞으면 옛 서버를 만난 앱이 이룸이
  /// 정보를 비우고 온보딩으로 돌려보낸다.
  ///
  /// 직접 만들 때 정하지 않으면 **목록이 비어 있지 않을 때만** 안다고 본다 — 비어 있는 것을
  /// "없다"로 읽는 쪽은 서버 응답을 읽은 [Member.fromJson] 뿐이다.
  bool get profilesKnown => _profilesKnown ?? profiles.isNotEmpty;

  /// 화면에 쓰이는 값이 모두 같은가. 주기 갱신이 같은 값으로 구독자를 다시 그리지 않게 하려는 비교다.
  bool sameAs(Member other) {
    if (nickname != other.nickname ||
        totalStars != other.totalStars ||
        imageStyle != other.imageStyle ||
        adsRemoved != other.adsRemoved ||
        profilesKnown != other.profilesKnown ||
        !listEquals(supportGoals, other.supportGoals) ||
        profiles.length != other.profiles.length) {
      return false;
    }
    for (var i = 0; i < profiles.length; i++) {
      final a = profiles[i];
      final b = other.profiles[i];
      if (a.id != b.id ||
          a.nickname != b.nickname ||
          a.character != b.character ||
          a.imageStyle != b.imageStyle) {
        return false;
      }
    }
    return true;
  }

  /// 서버 응답 파싱. 필드가 비거나 타입이 달라도 예외를 던지지 않는다.
  factory Member.fromJson(Map<String, dynamic> json) {
    return Member(
      nickname: json['nickname']?.toString(),
      totalStars: switch (json['totalStars']) {
        final int v => v,
        final String v => int.tryParse(v) ?? 0,
        _ => 0,
      },
      supportGoals: switch (json['supportGoals']) {
        final List<dynamic> list => list.map((e) => e.toString()).toList(),
        _ => const <String>[],
      },
      imageStyle: ImageStyle.fromApiValue(
        json['imageStyle'] is String ? json['imageStyle'] as String : null,
      ),
      profiles: switch (json['profiles']) {
        final List<dynamic> list =>
          list.map(ProfileSummary.tryParse).whereType<ProfileSummary>().toList(),
        _ => const <ProfileSummary>[],
      },
      adsRemoved: switch (json['entitlements']) {
        final Map<dynamic, dynamic> e => e['adsRemoved'] == true,
        _ => false,
      },
      profilesKnown: json['profiles'] is List,
    );
  }
}

/// 회원 정보 저장소.
///
/// **절대 throw하지 않는다.** 서버가 죽어도 홈 화면은 떠야 한다
/// (docs 원칙 6번). 실패하면 null을 돌려주고 화면이 로컬 값으로 fallback한다.
class MemberRepository {
  MemberRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _repo = 'MemberRepository';

  Future<Member?> getMyInfo() async {
    try {
      return await logged<Member?>(_repo, 'getMyInfo', () async {
        final res = await _dio.get<Map<String, dynamic>>('/api/member/me');
        final body = res.data;
        if (body == null) return null;
        return Member.fromJson(body);
      });
    } catch (_) {
      // 실패 로그는 logged 가 남겼다. 홈은 로컬 온보딩 값으로 뜬다.
      return null;
    }
  }

  /// 내 몫의 새 이룸이를 만든다 (`POST /api/member/profile` · 서버 #361·#362).
  ///
  /// 마지막 이룸이에서 나간 보호자가 이룸이를 다시 등록하려면 저장 API 보다 먼저 불러야 한다 —
  /// 이룸이가 없으면 서버가 저장을 `404 PROFILE_NOT_FOUND` 로 막는다. 서버는 **멱등**이라 이미
  /// 이룸이가 있으면 아무것도 만들지 않고 지금 상태를 200 으로 준다.
  ///
  /// 응답은 [getMyInfo] 와 같은 모양이다. **이룸이 목록이 없는 응답은 성공으로 읽지 않는다** —
  /// 어느 이룸이가 생겼는지 모르면 이어서 저장할 수 없다.
  Future<Attempt<Member>> createProfile() async {
    return guarded(_repo, 'createProfile', () async {
      final res = await _dio.post<Map<String, dynamic>>('/api/member/profile');
      final body = res.data;
      final member = body == null ? null : Member.fromJson(body);
      if (member == null || member.profiles.isEmpty) {
        // 목록이 없으면 어느 이룸이가 생겼는지 몰라 실패로 본다
        throw const AppFailure(fault: NetworkFault.app);
      }
      return member;
    });
  }

  /// 이 경로를 모르는 서버(다중 보호자 이전)가 준 실패인가.
  ///
  /// 서버가 코드를 붙인 404(예: `PROFILE_NOT_FOUND`)는 해당하지 않는다 — 그건 경로가 있는
  /// 서버가 한 말이다. 코드 없는 404·405 만 "그런 API 가 없다"로 읽는다.
  static bool isRouteMissing(AppFailure failure) {
    final s = failure.server;
    if (s == null || s.code != ServerErrorCode.unknown) return false;
    return s.statusCode == 404 || s.statusCode == 405;
  }

  /// 아이 호칭 저장. 온보딩 결과를 서버와 맞춘다.
  Future<AppFailure?> updateNickname(String nickname) async {
    // 서버에는 없고 로컬에만 남은 상태라, 실패를 호출부에 돌려줘 사용자에게 알리게 한다
    final r = await guarded<void>(
      _repo,
      'updateNickname',
      () => _dio.patch<dynamic>(
        '/api/member/nickname',
        data: {'nickname': nickname},
      ),
    );
    return r.failure;
  }

  /// 도움 목표 저장 (전체 교체).
  ///
  /// ⚠️ [goals]는 서버 enum 값이어야 한다
  /// (`STEP_BY_STEP` / `PREPARE_ITEMS` / `PREPARE_NEW` / `INDEPENDENT`).
  /// 없는 값을 보내면 서버가 400을 준다.
  Future<AppFailure?> updateSupportGoals(List<String> goals) async {
    // 서버에는 없고 로컬에만 남은 상태라, 실패를 호출부에 돌려줘 사용자에게 알리게 한다
    final r = await guarded<void>(
      _repo,
      'updateSupportGoals',
      () => _dio.patch<dynamic>(
        '/api/member/support-goals',
        data: {'supportGoals': goals},
      ),
    );
    return r.failure;
  }

  /// 캐릭터 저장. 온보딩 결과를 서버와 맞춘다.
  ///
  /// ⚠️ [character]는 서버 `CharacterType` enum 값이어야 한다 (`LULU` / `POPO`).
  /// `CardCharacter.apiValue`를 그대로 넘긴다. 없는 값을 보내면 서버가 400을 준다.
  Future<AppFailure?> updateCharacter(String character) async {
    // 서버에는 없고 로컬에만 남은 상태라, 실패를 호출부에 돌려줘 사용자에게 알리게 한다
    final r = await guarded<void>(
      _repo,
      'updateCharacter',
      () => _dio.patch<dynamic>(
        '/api/member/character',
        data: {'character': character},
      ),
    );
    return r.failure;
  }

  /// 카드 그림 방식 저장 (#458).
  ///
  /// ⚠️ [imageStyle]은 서버 enum 값이어야 한다 (`CARTOON` / `REALISTIC` /
  /// `PHOTO_ONLY`). `ImageStyle.apiValue`를 그대로 넘긴다.
  /// 대상 프로필은 캐릭터 저장과 같은 방식으로 정해진다(인증 인터셉터).
  Future<AppFailure?> updateImageStyle(String imageStyle) async {
    // 서버에는 없고 로컬에만 남은 상태라, 실패를 호출부에 돌려줘 사용자에게 알리게 한다
    final r = await guarded<void>(
      _repo,
      'updateImageStyle',
      () => _dio.patch<dynamic>(
        '/api/member/image-style',
        data: {'imageStyle': imageStyle},
      ),
    );
    return r.failure;
  }
}

/// 회원 정보 저장소. 인증 인터셉터가 붙은 [dioProvider]를 쓴다.
final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(dio: ref.watch(dioProvider)),
);
