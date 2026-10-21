package com.chuseok22.elumserver.routine.core;

/**
 * 일과 하나의 카드 수 상한 단일 원본: AI 생성 검증(RoutineAiPipeline), 카드 직접 추가(RoutineStepEditService)
 * 시스템 설정으로 두지 않음 > 앱·AI 계약에 묶인 값 (앱 routine_step_editing.dart 10장, Gemini 스키마 maxItems 10,
 * 프롬프트 "10개 이하", 오류 문구 "10장까지", 크레딧 응답 maxCardsPerRoutine). 바꾸려면 이 계약을 함께 바꾼다
 */
public final class RoutineStepLimits {

  /// 한 일과의 카드 수 상한
  public static final int MAX_STEP_COUNT = 10;

  private RoutineStepLimits() {
  }
}
