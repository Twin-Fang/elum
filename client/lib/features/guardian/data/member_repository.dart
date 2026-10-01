import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/network/dio_client.dart';
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

  final bool? _profilesKnown;

  /// 응답에 이룸이 목록이 **있었는가.** 옛 서버(다중 보호자 이전)는 필드가 없다 — 그때 빈
  /// [profiles] 는 "이룸이가 없다"가 아니라 "모른다"다. 둘을 섞으면 옛 서버를 만난 앱이 이룸이
  /// 정보를 비우고 온보딩으로 돌려보낸다.
  ///
  /// 직접 만들 때 정하지 않으면 **목록이 비어 있지 않을 때만** 안다고 본다 — 비어 있는 것을
  /// "없다"로 읽는 쪽은 서버 응답을 읽은 [Member.fromJson] 뿐이다.
  bool get profilesKnown => _profilesKnown ?? profiles.isNotEmpty;

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

  Future<Member?> getMyInfo() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/api/member/me');
      final body = res.data;
      if (body == null) return null;
      return Member.fromJson(body);
    } catch (e) {
      debugPrint('[member] 조회 실패 → 로컬 온보딩 값 사용: $e');
      return null;
    }
  }

  /// 아이 호칭 저장. 온보딩 결과를 서버와 맞춘다.
  Future<AppFailure?> updateNickname(String nickname) async {
    try {
      await _dio.patch<dynamic>(
        '/api/member/nickname',
        data: {'nickname': nickname},
      );
      return null;
    } catch (e) {
      // 로컬에는 남아 있지만 서버에는 없다 — 재설치하면 사라진다.
      // 부르는 쪽이 알아야 사용자에게 알릴 수 있다.
      debugPrint('[member] 호칭 저장 실패, 로컬에는 남아 있다: $e');
      return AppFailure.of(e);
    }
  }

  /// 도움 목표 저장 (전체 교체).
  ///
  /// ⚠️ [goals]는 서버 enum 값이어야 한다
  /// (`STEP_BY_STEP` / `PREPARE_ITEMS` / `PREPARE_NEW` / `INDEPENDENT`).
  /// 없는 값을 보내면 서버가 400을 준다.
  Future<AppFailure?> updateSupportGoals(List<String> goals) async {
    try {
      await _dio.patch<dynamic>(
        '/api/member/support-goals',
        data: {'supportGoals': goals},
      );
      return null;
    } catch (e) {
      debugPrint('[member] 목표 저장 실패, 로컬에는 남아 있다: $e');
      return AppFailure.of(e);
    }
  }

  /// 캐릭터 저장. 온보딩 결과를 서버와 맞춘다.
  ///
  /// ⚠️ [character]는 서버 `CharacterType` enum 값이어야 한다 (`LULU` / `POPO`).
  /// `CardCharacter.apiValue`를 그대로 넘긴다. 없는 값을 보내면 서버가 400을 준다.
  Future<AppFailure?> updateCharacter(String character) async {
    try {
      await _dio.patch<dynamic>(
        '/api/member/character',
        data: {'character': character},
      );
      return null;
    } catch (e) {
      debugPrint('[member] 캐릭터 저장 실패, 로컬에는 남아 있다: $e');
      return AppFailure.of(e);
    }
  }

  /// 카드 그림 방식 저장 (#458).
  ///
  /// ⚠️ [imageStyle]은 서버 enum 값이어야 한다 (`CARTOON` / `REALISTIC` /
  /// `PHOTO_ONLY`). `ImageStyle.apiValue`를 그대로 넘긴다.
  /// 대상 프로필은 캐릭터 저장과 같은 방식으로 정해진다(인증 인터셉터).
  Future<AppFailure?> updateImageStyle(String imageStyle) async {
    try {
      await _dio.patch<dynamic>(
        '/api/member/image-style',
        data: {'imageStyle': imageStyle},
      );
      return null;
    } catch (e) {
      debugPrint('[member] 그림 방식 저장 실패, 로컬에는 남아 있다: $e');
      return AppFailure.of(e);
    }
  }
}

/// 회원 정보 저장소. 인증 인터셉터가 붙은 [dioProvider]를 쓴다.
final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(dio: ref.watch(dioProvider)),
);
