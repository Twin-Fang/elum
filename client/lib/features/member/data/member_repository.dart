import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/guarded_call.dart';
import '../../../core/network/profile_header_interceptor.dart';
import '../../../core/network/server_error_code.dart';
import '../../../shared/models/image_style.dart';
import '../../profile/domain/profile_summary.dart';
import '../domain/guardian_account.dart';
import '../domain/member_subscription.dart';
import '../../../app/dio_provider.dart';

/// 보호자 회원 정보 — 서버 `MemberResponse`에 대응한다.
///
/// 출처: server/.../member/application/dto/response/MemberResponse.java
@immutable
class Member {
  const Member({
    this.id,
    this.nickname,
    this.totalStars = 0,
    this.supportGoals = const [],
    this.imageStyle = ImageStyle.cartoon,
    this.profiles = const [],
    this.adsRemoved = false,
    this.isPro = false,
    this.canExportCardsWithoutWatermark = false,
    this.canUseAllCardDesignThemes = false,
    this.subscription,
    this.canViewWeeklyReport = false,
    this.canTranslateRoutines = false,
    this.canScheduleRoutines = false,
    this.canUseGuardianVoice = false,
    this.canImportExpertRoutines = false,
    this.canUseRoutineMemory = false,
    this.canRegenerateImagesFree = false,
    this.account,
    bool? profilesKnown,
  }) : _profilesKnown = profilesKnown;

  /// 아이 호칭. 미설정이면 null이다 (서버가 null을 준다).
  final String? nickname;

  /// 누적 획득 별 개수
  final int totalStars;

  /// 선택한 도움 목표의 서버 enum 값
  final List<String> supportGoals;

  /// 카드 그림 방식. 필드가 없거나 모르는 값이면 만화다 —
  /// 필드가 없거나 새 값이 와도 화면이 죽지 않는다.
  final ImageStyle imageStyle;

  /// 연결된 이룸이 목록 — 먼저 연결된 차례 (`MemberResponse.profiles`).
  ///
  /// 필드가 없거나 모양이 달라도 빈 목록이다. 위 [nickname] 등은 `X-Profile-Id` 로
  /// 짚은 이룸이(없으면 첫 이룸이)의 값이다.
  final List<ProfileSummary> profiles;

  /// 이 계정의 요금제가 광고를 없애는가 (`entitlements.adsRemoved` · 요금제별 `*_ADS_REMOVED`).
  ///
  /// 필드가 없거나 모양이 달라도 false(광고 표시)다. 광고 게이트가 이 값으로 Pro 의 광고를 끈다.
  final bool adsRemoved;

  /// 보호자 회원 id (UUID 문자열). 스토어 결제에 실어 구매를 이 계정에 묶는다. 모르면 null
  final String? id;

  /// 서버가 본 요금제가 Pro 인가 (`entitlements.plan`). 모르면 false
  final bool isPro;

  /// 내 요금제 표시용 구독 상태 (만료일·자동 갱신·유예). 이전 서버면 null
  final MemberSubscription? subscription;

  /// 카드 내보내기에서 이룸 로고·워터마크를 뺄 수 있는가 (`entitlements.cardExportWithoutWatermark`).
  /// 모르면 false — 워터마크를 넣는 쪽으로 기운다.
  final bool canExportCardsWithoutWatermark;

  /// 카드 내보내기에서 기본 말고 다른 디자인 테마를 고를 수 있는가 (`entitlements.cardExportAllThemes`).
  final bool canUseAllCardDesignThemes;

  /// 주간 리포트를 볼 수 있는가 (`entitlements.weeklyReport`). 모르면 false
  final bool canViewWeeklyReport;

  /// 만든 일과를 다른 언어 사본으로 만들 수 있는가 (`entitlements.routineTranslate`). 모르면 false
  final bool canTranslateRoutines;

  /// 일과에 요일·시각을 정하고 이룸이 기기로 알림을 보낼 수 있는가 (`entitlements.routineSchedule`, #782 · #1080)
  final bool canScheduleRoutines;

  /// 카드마다 보호자 목소리를 녹음해 이룸이 기기에서 그 녹음으로 읽을 수 있는가 (`entitlements.guardianVoice`)
  final bool canUseGuardianVoice;

  /// 전문가 일과를 일과관리로 가져올 수 있는가 (`entitlements.routineTemplates`). 모르면 false
  final bool canImportExpertRoutines;

  /// 이룸이별 AI 메모(내가 고친 일과처럼 만들기)를 쓸 수 있는가 (`entitlements.routineMemory`). 모르면 false
  final bool canUseRoutineMemory;

  /// 카드 그림 다시 그리기가 크레딧 없이 되는가 (`entitlements.imageRegenerateFree`, 하루 한도는 서버가 봄)
  final bool canRegenerateImagesFree;

  /// 보호자 본인 표시 정보 (닉네임·가입 방법·가린 이메일·가입일). 내 정보 상단 카드용
  ///
  /// `account` 필드가 없는 이전 서버면 null — 카드가 "이메일 비공개"로 잘못 보이지 않게 정보 줄을 뺀다.
  final GuardianAccount? account;

  final bool? _profilesKnown;

  /// 응답에 이룸이 목록이 **있었는가.** 다중 보호자 이전 서버는 필드가 없다 — 그때 빈
  /// [profiles] 는 "이룸이가 없다"가 아니라 "모른다"다. 둘을 섞으면 그런 서버를 만난 앱이 이룸이
  /// 정보를 비우고 온보딩으로 돌려보낸다.
  ///
  /// 직접 만들 때 정하지 않으면 **목록이 비어 있지 않을 때만** 안다고 본다 — 비어 있는 것을
  /// "없다"로 읽는 쪽은 서버 응답을 읽은 [Member.fromJson] 뿐이다.
  bool get profilesKnown => _profilesKnown ?? profiles.isNotEmpty;

  /// 화면에 쓰이는 값이 모두 같은가. 주기 갱신이 같은 값으로 구독자를 다시 그리지 않게 하려는 비교다.
  bool sameAs(Member other) {
    if (id != other.id ||
        nickname != other.nickname ||
        totalStars != other.totalStars ||
        imageStyle != other.imageStyle ||
        adsRemoved != other.adsRemoved ||
        isPro != other.isPro ||
        canExportCardsWithoutWatermark != other.canExportCardsWithoutWatermark ||
        canUseAllCardDesignThemes != other.canUseAllCardDesignThemes ||
        subscription != other.subscription ||
        canViewWeeklyReport != other.canViewWeeklyReport ||
        canTranslateRoutines != other.canTranslateRoutines ||
        canScheduleRoutines != other.canScheduleRoutines ||
        canUseGuardianVoice != other.canUseGuardianVoice ||
        canImportExpertRoutines != other.canImportExpertRoutines ||
        canUseRoutineMemory != other.canUseRoutineMemory ||
        canRegenerateImagesFree != other.canRegenerateImagesFree ||
        account != other.account ||
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
      id: json['id'] is String ? json['id'] as String : null,
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
      adsRemoved: _isEntitled(json, 'adsRemoved'),
      isPro: switch (json['entitlements']) {
        final Map<dynamic, dynamic> entitlements => entitlements['plan'] == 'PRO',
        _ => false,
      },
      canExportCardsWithoutWatermark: _isEntitled(json, 'cardExportWithoutWatermark'),
      canUseAllCardDesignThemes: _isEntitled(json, 'cardExportAllThemes'),
      subscription: MemberSubscription.tryParse(json['subscription']),
      canViewWeeklyReport: _isEntitled(json, 'weeklyReport'),
      canTranslateRoutines: _isEntitled(json, 'routineTranslate'),
      canScheduleRoutines: _isEntitled(json, 'routineSchedule'),
      canUseGuardianVoice: _isEntitled(json, 'guardianVoice'),
      canImportExpertRoutines: _isEntitled(json, 'routineTemplates'),
      canUseRoutineMemory: _isEntitled(json, 'routineMemory'),
      canRegenerateImagesFree: _isEntitled(json, 'imageRegenerateFree'),
      account: json['account'] is Map ? GuardianAccount.fromMemberJson(json) : null,
      profilesKnown: json['profiles'] is List,
    );
  }
}

/// `entitlements.{key}` 가 true 인가. 필드가 없거나 모양이 달라도 false
bool _isEntitled(Map<String, dynamic> json, String key) =>
    switch (json['entitlements']) {
      final Map<dynamic, dynamic> entitlements => entitlements[key] == true,
      _ => false,
    };

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

  /// 내 몫의 새 이룸이를 만든다 (`POST /api/member/profile` ).
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

  /// 온보딩 완료 한 번 저장: 이룸이 확보 > 호칭·목표·캐릭터·그림 방식 > 예시 일과 (서버 한 트랜잭션)
  ///
  /// 고른 이룸이 헤더를 싣지 않는다. 탈퇴 후 재가입처럼 지워진 이룸이 id 가 남아 있어도 내 이룸이에 저장된다.
  Future<Attempt<Member>> completeOnboarding({
    required String nickname,
    required List<String> supportGoals,
    required String? character,
    required String imageStyle,
    required List<String> exampleCategories,
  }) {
    return guarded(_repo, 'completeOnboarding', () async {
      final res = await _dio.post<Map<String, dynamic>>(
        '/api/member/onboarding',
        data: {
          'nickname': nickname,
          'supportGoals': supportGoals,
          'character': ?character,
          'imageStyle': imageStyle,
          'exampleCategories': exampleCategories,
        },
        options: Options(extra: {ProfileHeaderInterceptor.skipKey: true}),
      );
      final body = res.data;
      final member = body == null ? null : Member.fromJson(body);
      if (member == null || member.profiles.isEmpty) {
        // 어느 이룸이에 저장됐는지 몰라 실패로 본다
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

  /// 이룸이 호칭 저장. [profileId] 가 있으면 그 이룸이, 없으면 고른 이룸이다.
  Future<AppFailure?> updateNickname(
    String nickname, {
    String? profileId,
  }) async {
    // 서버에는 없고 로컬에만 남은 상태라, 실패를 호출부에 돌려줘 사용자에게 알리게 한다
    final r = await guarded<void>(
      _repo,
      'updateNickname',
      () => _dio.patch<dynamic>(
        '/api/member/nickname',
        data: {'nickname': nickname},
        options: _targetProfileOptions(profileId),
      ),
    );
    return r.failure;
  }

  /// 보호자 본인 닉네임 저장 (`PATCH /api/member/account/nickname`). 응답은 [getMyInfo] 와 같은 모양
  ///
  /// 거절 4종: 형식 · 금지어 · 중복 · 7일 제한 (`NICKNAME_*`). 이룸이 호칭은 [updateNickname]
  Future<Attempt<Member>> updateGuardianNickname(String nickname) {
    return guarded(_repo, 'updateGuardianNickname', () async {
      final res = await _dio.patch<Map<String, dynamic>>(
        '/api/member/account/nickname',
        data: {'nickname': nickname},
      );
      final body = res.data;
      // 응답 모양이 다르면 저장 여부를 몰라 실패로 본다 (다시 받기로 맞춤)
      if (body == null) throw const AppFailure(fault: NetworkFault.app);
      return Member.fromJson(body);
    });
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
  /// [profileId] 가 있으면 그 이룸이, 없으면 고른 이룸이다.
  Future<AppFailure?> updateCharacter(
    String character, {
    String? profileId,
  }) async {
    // 서버에는 없고 로컬에만 남은 상태라, 실패를 호출부에 돌려줘 사용자에게 알리게 한다
    final r = await guarded<void>(
      _repo,
      'updateCharacter',
      () => _dio.patch<dynamic>(
        '/api/member/character',
        data: {'character': character},
        options: _targetProfileOptions(profileId),
      ),
    );
    return r.failure;
  }

  /// 카드 그림 방식 저장.
  ///
  /// ⚠️ [imageStyle]은 서버 enum 값이어야 한다 (`CARTOON` / `REALISTIC` /
  /// `PHOTO_ONLY`). `ImageStyle.apiValue`를 그대로 넘긴다.
  /// 대상 프로필은 캐릭터 저장과 같은 방식으로 정해진다(인증 인터셉터).
  /// [profileId] 가 있으면 그 이룸이, 없으면 고른 이룸이다.
  Future<AppFailure?> updateImageStyle(
    String imageStyle, {
    String? profileId,
  }) async {
    // 서버에는 없고 로컬에만 남은 상태라, 실패를 호출부에 돌려줘 사용자에게 알리게 한다
    final r = await guarded<void>(
      _repo,
      'updateImageStyle',
      () => _dio.patch<dynamic>(
        '/api/member/image-style',
        data: {'imageStyle': imageStyle},
        options: _targetProfileOptions(profileId),
      ),
    );
    return r.failure;
  }

  /// 저장 대상 이룸이 지정 (null 이면 고른 이룸이 그대로)
  static Options? _targetProfileOptions(String? profileId) => profileId == null
      ? null
      : Options(extra: {ProfileHeaderInterceptor.targetProfileKey: profileId});
}

/// 회원 정보 저장소. 인증 인터셉터가 붙은 [dioProvider]를 쓴다.
final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(dio: ref.watch(dioProvider)),
);
