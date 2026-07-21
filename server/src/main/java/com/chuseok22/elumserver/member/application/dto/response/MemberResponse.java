package com.chuseok22.elumserver.member.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
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

  @Schema(description = "회원가입 일시 (KST, ISO-8601 형식)", example = "2026-07-16T10:30:00")
  LocalDateTime createdAt
) {

  public static MemberResponse from(Member member) {
    return new MemberResponse(
      member.getId(),
      member.getUsername(),
      member.getTotalStars(),
      member.getNickname(),
      member.getSupportGoals(),
      member.getCreatedAt()
    );
  }
}
