package com.chuseok22.elumserver.member.application.dto.request;

import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotNull;
import java.util.Set;

@Schema(description = "도움 목표 설정 요청")
public record MemberSupportGoalsUpdateRequest(

  @Schema(description = "선택한 도움 목표(전체 교체, 빈 배열이면 전부 해제)", example = "[\"PREPARE_ITEMS\", \"PREPARE_NEW\"]")
  @NotNull(message = "supportGoals는 필수입니다.")
  Set<SupportGoal> supportGoals
) {

}
