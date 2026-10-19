package com.chuseok22.elumserver.routine.application.controller;

import io.swagger.v3.oas.annotations.tags.Tag;

@Tag(
  name = "Routine",
  description = "부모 자연어 입력 기반 일과(Routine) 생성/검토/승인/단계 완료/단계 수정/단계 삭제/AI 추가 질문 API. 모든 엔드포인트는 accessToken(Bearer) 인증이 필요합니다."
)
public interface RoutineControllerDocs extends
  RoutineCreationDocs,
  RoutineQueryDocs,
  RoutineManagementDocs,
  RoutineLibraryDocs,
  RoutineProgressDocs,
  RoutineStepEditDocs {
}
