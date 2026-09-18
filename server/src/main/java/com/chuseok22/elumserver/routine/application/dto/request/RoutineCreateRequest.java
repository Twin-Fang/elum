package com.chuseok22.elumserver.routine.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.Size;
import java.time.LocalDateTime;
import java.util.List;

/**
 * 일과 생성 요청.
 *
 * <p>⚠️ <b>제약을 지우지 않는다.</b> 컨트롤러가 {@code @Valid}로 이 기록을 검사하고,
 * 검사에 걸리면 AI를 <b>한 번도 부르지 않고</b> 400으로 끝낸다. 제약이 없던 시절에는
 * 빈 요청 하나가 DLP·텍스트·이미지 생성을 18.7초 동안 다 돌린 뒤 DB 제약에서 터졌다
 * (이슈 #215). 돈은 나가고 사용자는 500만 본다.
 */
@Schema(description = "일과 생성 요청")
public record RoutineCreateRequest(

  @Schema(description = "보호자가 입력한 자연어 일과 원문", example = "내일 오후 3시에 병원 가기",
    requiredMode = Schema.RequiredMode.REQUIRED)
  @NotBlank(message = "일과 내용을 입력해주세요.")
  @Size(max = 1000, message = "일과 내용은 1000자를 넘을 수 없습니다.")
  String rawInputText,

  @Schema(description = "일과를 수행할 날짜/시각. 생략하면 **서버가 지금 시각으로 채운다**",
    example = "2026-07-19T15:00:00")
  LocalDateTime scheduledAt,

  @Schema(description = "POST /api/routines/questions 질문에 대한 답변(선택지+직접입력 통합). 질문 단계를 거치지 않았으면 생략 가능", example = "[\"우산\", \"우비\", \"여벌 양말\"]")
  List<String> answers,

  @Schema(description = "보호자가 정한 보상(강화물). 선택 항목이라 생략 가능하다", example = "젤리 먹기")
  @Size(max = 100, message = "보상은 100자를 넘을 수 없습니다.")
  String rewardText,

  @Schema(description = "보상 프리셋 키(SNACK/VIDEO/PLAY/WALK/CUSTOM). 직접 입력이면 CUSTOM 또는 생략", example = "SNACK")
  String rewardPresetKey
) {

}
