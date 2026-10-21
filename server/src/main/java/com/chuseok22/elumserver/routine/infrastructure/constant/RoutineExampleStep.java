package com.chuseok22.elumserver.routine.infrastructure.constant;

/**
 * 예시 카드 1장: 문장(ko·en), 대체 픽토그램 id (pictograms/catalog.json), 앱 번들 예시 이미지 id
 * 앱 표시 우선순위: 사진·AI 그림 > 예시 이미지 > 픽토그램. 예시 이미지를 모르는 옛 앱은 픽토그램으로 대체
 */
public record RoutineExampleStep(String textKo, String textEn, String pictogramId, String exampleImageId) {

}
