package com.chuseok22.elumserver.routine.application.controller;

import io.swagger.v3.oas.annotations.tags.Tag;

/**
 * Swagger 묶음 "Routine" 문서: 일과 만들기·조회·관리·진행·카드 편집 (RoutineController)
 * 같은 묶음 컨트롤러 7개(일과·일과관리·카드 그림·카드 소리·예시 일과·다른 언어로 만들기·주간 리포트)가 아래 태그 상수를 함께 씀
 */
@Tag(name = RoutineControllerDocs.TAG_NAME, description = RoutineControllerDocs.TAG_DESCRIPTION)
public interface RoutineControllerDocs extends
  RoutineCreationDocs,
  RoutineQueryDocs,
  RoutineManagementDocs,
  RoutineProgressDocs,
  RoutineStepEditDocs,
  RoutineCardSplitDocs {

  // Swagger 태그: 이름·설명이 같아야 문서에서 한 묶음으로 합쳐짐
  String TAG_NAME = "Routine";
  String TAG_DESCRIPTION = "부모 자연어 입력 기반 일과(Routine) 생성/검토/승인/단계 완료/단계 수정/단계 삭제/AI 추가 질문 API. 모든 엔드포인트는 accessToken(Bearer) 인증이 필요합니다.";
}
