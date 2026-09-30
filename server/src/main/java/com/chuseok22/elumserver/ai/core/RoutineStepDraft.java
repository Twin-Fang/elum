package com.chuseok22.elumserver.ai.core;

import java.util.List;

public record RoutineStepDraft(String title, List<StepDraft> steps) {

  /**
   * @param imagePromptEn FLUX 용 영어 장면 한 줄. 이미지 제공자가 FLUX 일 때만 스키마로 요청하므로
   *                      그 밖에는 null 이다 (#373). 저장하지 않는다 — 그림은 같은 요청 안에서
   *                      바로 그리고, 카드 수정은 그림을 다시 그리지 않는다.
   * @param pictogramId 무료 픽토그램 id(#247). 요청에 실은 pictogramCatalog 안에서 AI 가 고른 값이며 선택 필드다 —
   *                    옛 프롬프트·모델이 빠뜨리거나 null 을 줘도 카드 생성은 실패하지 않는다. 카탈로그에 없는 값도
   *                    여기서는 그대로 두고, 검증·폴백은 파이프라인이 한다.
   */
  public record StepDraft(
    Integer order, String title, String description, String imagePromptEn, String pictogramId
  ) {

    public StepDraft(Integer order, String title, String description) {
      this(order, title, description, null, null);
    }

    public StepDraft(Integer order, String title, String description, String imagePromptEn) {
      this(order, title, description, imagePromptEn, null);
    }
  }
}
