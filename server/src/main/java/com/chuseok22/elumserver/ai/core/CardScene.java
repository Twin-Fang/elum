package com.chuseok22.elumserver.ai.core;

/**
 * 카드 그림 한 장의 장면 정보: 일과 제목, 카드 제목·설명, 글 AI 가 준 영어 장면 한 줄
 * 없는 값은 null (그림 지시문 JSON 에서 생략)
 *
 * @param routineTitle 어떤 일과인지 알려 주는 참고용 (그리지 않음)
 * @param sceneDetail  자세·손에 든 물건·위치를 적은 영어 한 줄 (imagePromptEn)
 */
public record CardScene(String routineTitle, String stepTitle, String stepDescription, String sceneDetail) {

  /// 보호자가 직접 추가한 카드처럼 설명 하나뿐인 장면
  public static CardScene descriptionOnly(String stepDescription) {
    return new CardScene(null, null, stepDescription, null);
  }
}
