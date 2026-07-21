import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// 보호자 회원 정보 — 서버 `MemberResponse`에 대응한다.
///
/// 출처: server/.../member/application/dto/response/MemberResponse.java
@immutable
class Member {
  const Member({
    this.nickname,
    this.totalStars = 0,
    this.supportGoals = const [],
  });

  /// 아이 호칭. 미설정이면 null이다 (서버가 null을 준다).
  final String? nickname;

  /// 누적 획득 별 개수
  final int totalStars;

  /// 선택한 도움 목표의 서버 enum 값
  final List<String> supportGoals;

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
  Future<void> updateNickname(String nickname) async {
    try {
      await _dio.patch<dynamic>(
        '/api/member/nickname',
        data: {'nickname': nickname},
      );
    } catch (e) {
      debugPrint('[member] 호칭 저장 실패, 로컬에는 남아 있다: $e');
    }
  }

  /// 도움 목표 저장 (전체 교체).
  ///
  /// ⚠️ [goals]는 서버 enum 값이어야 한다
  /// (`STEP_BY_STEP` / `PREPARE_ITEMS` / `PREPARE_NEW` / `INDEPENDENT`).
  /// 없는 값을 보내면 서버가 400을 준다.
  Future<void> updateSupportGoals(List<String> goals) async {
    try {
      await _dio.patch<dynamic>(
        '/api/member/support-goals',
        data: {'supportGoals': goals},
      );
    } catch (e) {
      debugPrint('[member] 목표 저장 실패, 로컬에는 남아 있다: $e');
    }
  }

  /// 캐릭터 저장. 온보딩 결과를 서버와 맞춘다.
  ///
  /// ⚠️ [character]는 서버 `CharacterType` enum 값이어야 한다 (`LULU` / `POPO`).
  /// `CardCharacter.apiValue`를 그대로 넘긴다. 없는 값을 보내면 서버가 400을 준다.
  Future<void> updateCharacter(String character) async {
    try {
      await _dio.patch<dynamic>(
        '/api/member/character',
        data: {'character': character},
      );
    } catch (e) {
      debugPrint('[member] 캐릭터 저장 실패, 로컬에는 남아 있다: $e');
    }
  }
}

/// 회원 정보 저장소. 인증 인터셉터가 붙은 [dioProvider]를 쓴다.
final memberRepositoryProvider = Provider<MemberRepository>(
  (ref) => MemberRepository(dio: ref.watch(dioProvider)),
);
