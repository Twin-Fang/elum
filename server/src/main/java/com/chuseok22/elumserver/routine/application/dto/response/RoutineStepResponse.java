package com.chuseok22.elumserver.routine.application.dto.response;

import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "일과 단계 응답")
public record RoutineStepResponse(

  @Schema(description = "단계 ID")
  String id,

  @Schema(description = "단계 순서", example = "1")
  Integer stepOrder,

  @Schema(description = "카드에 표시할 짧은 라벨. 이 변경 이전에 생성된 기존 루틴은 null일 수 있음", example = "옷을 입어요")
  String title,

  @Schema(description = "아동에게 소리 내어 읽어줄 문장", example = "학교 갈 옷을 입어요")
  String description,

  @Schema(description = "생성된 이미지 저장 경로")
  String imagePath,

  @Schema(description = "완료 여부", example = "false")
  Boolean completed,

  @Schema(description = "완료 시각(KST), 미완료 시 null")
  LocalDateTime completedAt,

  @Schema(
    description = "무료 픽토그램 id(SVG 파일명, 앱에 번들). 사진·AI 그림이 없을 때 앱이 보여준다. "
      + "null 이면 이 카드는 픽토그램이 없다(이 기능 이전 카드 등) — 앱이 기본 그림으로 대체", example = "get_dressed_,_to")
  String pictogramId,

  @Schema(description = "미리 만든 단계 음성 열쇠. 아직 없으면 null — 앱은 기기 음성으로 읽는다. "
    + "글이 바뀌면 값이 바뀐다", example = "step-1/3f2a9c0d1b2e4f60.wav")
  String speechPath,

  @Schema(description = "앱에 번들된 예시 카드 이미지 id(온보딩 예시 일과 단계만). 사진·AI 그림이 없을 때 픽토그램보다 먼저 보여준다. "
    + "null 이면 예시 이미지가 없는 카드", example = "fold_blanket")
  String exampleImageId,

  @Schema(description = "보호자 목소리 녹음 열쇠(Pro). 녹음이 없으면 null. 다시 녹음하면 값이 바뀐다. "
    + "이룸이 기기는 이 값이 있으면 기본 음성보다 녹음을 먼저 받는다(GET .../voice)", example = "member-1/0f8fad5b-d9cb-469f-a165-70867728950e.m4a")
  String guardianVoicePath,

  @Schema(description = "카드 그림이 AI 가 그린 그림인가. true 면 보호자 화면에 `다시 그리기`를 보인다 "
    + "(POST .../image/regenerate). 그림 없음·보호자 사진·이야기에서 가져온 그림은 false", example = "true")
  boolean aiPicture
) {

  public static RoutineStepResponse from(RoutineStep step) {
    return new RoutineStepResponse(
      step.getId(),
      step.getStepOrder(),
      step.getTitle(),
      step.getDescription(),
      step.getImagePath(),
      step.getCompleted(),
      step.getCompletedAt(),
      step.getPictogramId(),
      step.getSpeechPath(),
      step.getExampleImageId(),
      step.getGuardianVoicePath(),
      RoutineImageStorage.isAiDrawn(step.getImagePath())
    );
  }
}
