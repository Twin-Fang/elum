package com.chuseok22.elumserver.expertroutine.application.dto.request;

import java.util.List;

/**
 * 관리자가 저장하는 전문가 일과 입력: 다듬기·검증 전 값 그대로 (검증은 ExpertRoutineAdminService)
 * 숫자·코드 칸은 문자열 그대로 받아 잘못된 값도 거절 이유와 함께 되돌려 줌
 */
public record ExpertRoutineInput(
  String title,
  String summary,
  String category,
  String language,
  String rewardText,
  String rewardPresetKey,
  String sortOrder,
  String reviewStatus,
  String reviewNote,
  List<StepInput> steps
) {

  /// 카드 1장: 문장, 픽토그램 id, 예시 이미지 id (빈 값은 없음)
  public record StepInput(String text, String pictogramId, String exampleImageId) {

  }
}
