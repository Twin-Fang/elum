package com.chuseok22.elumserver.member.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "이룸이를 함께 돌보는 사람 한 명")
public record GuardianResponse(

  @Schema(description = "이 이룸이와의 관계 ID. 계정 ID 가 아니다 — 다른 보호자의 계정 정보는 내려가지 않는다")
  String id,

  @Schema(description = "나인가. 목록에서 \"나\"를 표시하고 나가기·이름 고치기를 이 항목에만 보여주는 데 쓴다")
  boolean me,

  @Schema(description = "이 이룸이 안에서 불리는 이름. 비어 있으면 null — 앱이 \"보호자\"로 부른다", example = "엄마", nullable = true)
  String displayName,

  @Schema(description = "표시용 구분. GUARDIAN(가족 보호자) · CAREGIVER(센터 선생님 등). 권한 차이는 없다", example = "GUARDIAN")
  GuardianKind kind,

  @Schema(description = "이 이룸이에 합류한 시각. 이 순서대로 정렬돼 내려온다", example = "2026-10-01T09:00:00")
  LocalDateTime joinedAt
) {

  public static GuardianResponse from(ProfileGuardian guardian, String callerMemberId) {
    return new GuardianResponse(
      guardian.getId(),
      guardian.getMember().getId().equals(callerMemberId),
      guardian.getDisplayName(),
      guardian.getKind(),
      guardian.getJoinedAt());
  }
}
