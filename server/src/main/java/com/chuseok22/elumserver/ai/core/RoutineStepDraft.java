package com.chuseok22.elumserver.ai.core;

import java.util.List;

public record RoutineStepDraft(String title, List<StepDraft> steps) {

  /**
   * @param imagePromptEn FLUX 용 영어 장면 한 줄. 이미지 제공자가 FLUX 일 때만 스키마로 요청하므로
   *                      그 밖에는 null 이다 (#373). 저장하지 않는다 — 그림은 같은 요청 안에서
   *                      바로 그리고, 카드 수정은 그림을 다시 그리지 않는다.
   */
  public record StepDraft(Integer order, String title, String description, String imagePromptEn) {

    public StepDraft(Integer order, String title, String description) {
      this(order, title, description, null);
    }
  }
}
