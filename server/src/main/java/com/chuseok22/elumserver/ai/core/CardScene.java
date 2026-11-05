package com.chuseok22.elumserver.ai.core;

/**
 * 카드 그림 장면 정보: 일과 제목(참고용, 그리지 않음), 카드 제목·설명, 영어 장면 한 줄(imagePromptEn), 보호자 요청(다시 그리기)
 * 없는 값은 null > 그림 지시문 JSON 에서 생략
 */
public record CardScene(
  String routineTitle, String stepTitle, String stepDescription, String sceneDetail, String guardianRequest
) {

  /// 보호자 요청 없는 장면 (일과 만들기·카드 추가)
  public CardScene(String routineTitle, String stepTitle, String stepDescription, String sceneDetail) {
    this(routineTitle, stepTitle, stepDescription, sceneDetail, null);
  }

  /// 보호자가 직접 추가한 카드처럼 설명 하나뿐인 장면
  public static CardScene descriptionOnly(String stepDescription) {
    return new CardScene(null, null, stepDescription, null);
  }
}
