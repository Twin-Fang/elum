package com.chuseok22.elumserver.member.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;
import java.util.Set;

@Schema(description = "보호자 회원 정보 응답")
public record MemberResponse(

  @Schema(description = "회원 고유 ID (UUID 문자열)", example = "b3b1e2a0-1234-4d56-9abc-1234567890ab")
  String id,

  @Schema(description = "로그인 아이디", example = "chuseok22")
  String username,

  @Schema(description = "누적 획득 별 개수", example = "12")
  Integer totalStars,

  @Schema(description = "아이 호칭(별명), 미설정 시 null", example = "하늘이")
  String nickname,

  @Schema(description = "선택한 도움 목표(빈 배열이면 미설정)")
  Set<SupportGoal> supportGoals,

  @Schema(description = "선택한 캐릭터, 미설정 시 null", example = "LULU")
  CharacterType character,

  @Schema(description = "회원가입 일시 (KST, ISO-8601 형식)", example = "2026-07-16T10:30:00")
  LocalDateTime createdAt
) {

  /**
   * 계정과 프로필을 합쳐 기존 응답 형식 그대로 만든다.
   *
   * <p>필드가 두 엔티티로 갈렸지만 **응답 JSON은 바뀌지 않는다.** 이미 배포된 앱이
   * 이 형식을 쓰고 있어, 내부 구조 변경이 클라이언트에 새어 나가면 안 된다.
   *
   * <p>[profile]이 없으면 당사자 항목을 비워 응답한다. 가입 직후 프로필 생성에
   * 실패한 예외적인 상태에서도 화면이 죽지 않게 한다.
   */
  public static MemberResponse from(Member member, Profile profile) {
    return new MemberResponse(
      member.getId(),
      member.getUsername(),
      profile == null ? 0 : profile.getTotalStars(),
      profile == null ? null : profile.getNickname(),
      profile == null ? Set.of() : profile.getSupportGoals(),
      profile == null ? null : profile.getCharacter(),
      member.getCreatedAt()
    );
  }
}
