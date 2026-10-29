package com.chuseok22.elumserver.routine.application.dto;

import com.chuseok22.elumserver.common.locale.AppLocale;
import java.util.List;

/**
 * 이야기로 나눌 일과의 읽기 전용 스냅샷: 원본 id, 제목, 언어, 이룸이 호칭, 카드 목록
 * 이름 가리기 전의 값이라 호출부(talk)가 가린 뒤에 쓴다
 */
public record RoutineShareSnapshot(
  String originalRoutineId,
  String title,
  AppLocale language,
  String profileNickname,
  List<StepSnapshot> steps
) {

  /**
   * 카드 1장: imageKey 는 일과 그림 저장 열쇠(없으면 null), isGuardianPhoto 는 보호자가 올린 사진 여부
   */
  public record StepSnapshot(
    String stepId,
    int stepOrder,
    String title,
    String description,
    String imageKey,
    String pictogramId,
    String exampleImageId,
    boolean isGuardianPhoto
  ) {

  }

  public boolean hasGuardianPhoto() {
    return steps.stream().anyMatch(StepSnapshot::isGuardianPhoto);
  }
}
