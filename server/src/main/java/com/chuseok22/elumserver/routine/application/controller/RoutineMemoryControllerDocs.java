package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryEnabledRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryLinesUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.enums.ParameterIn;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(name = "Routine Memory", description = "이룸이별 AI 메모 API (#1082, Pro). accessToken(Bearer) 인증이 필요합니다.")
public interface RoutineMemoryControllerDocs {

  @Operation(
    summary = "AI 메모 보기",
    description = """
      보호자가 고쳐 확정한 카드에서 AI 가 정리한 이 이룸이의 카드 만들기 방식 메모를 돌려줍니다 (최대 10줄).

      - **Free**: `available=false`, 나머지는 비어 있습니다 (403 아님 — 화면이 숨김 여부만 판단).
      - 메모를 아직 만들지 않았으면 `enabled=true`, 빈 줄입니다.
      - 메모는 하루 한 번 묶어 갱신합니다. 보호자 입력 원문은 메모에도, 메모를 만드는 AI 호출에도 쓰지 않습니다.

      **403**: 이룸이 기기 토큰 (`PROFILE_ACCESS_DENIED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> getMemory(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "AI 메모 줄 통째로 바꾸기",
    description = """
      화면에 보이는 전체 줄을 그대로 보냅니다. 줄 하나 고치기·지우기도 이 API 로 합니다.

      - 이전 AI 줄과 같은 문장은 `AI`, 나머지는 `GUARDIAN` 으로 저장합니다. 보호자 줄은 AI 갱신이 덮어쓰지 않습니다.
      - 빠진 AI 줄은 다시 만들지 않도록 기억합니다.

      **400**: 10줄 초과 · 한 줄 60자 초과 (`INVALID_INPUT_VALUE`), 진단·장애·정도·연락처가 든 줄 (`ROUTINE_MEMORY_LINE_NOT_ALLOWED`)
      **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> replaceLines(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineMemoryLinesUpdateRequest request
  );

  @Operation(
    summary = "AI 메모 켜기/끄기",
    description = """
      끄면 일과 만들기에 메모·확정 예시를 넣지 않고, 그동안 확정한 일과도 배우지 않습니다. 메모 줄은 남습니다.

      **400**: `enabled` 없음 · **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> setEnabled(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineMemoryEnabledRequest request
  );

  @Operation(
    summary = "AI 메모 모두 지우기",
    description = """
      메모 줄을 모두 지우고, 이 이룸이 일과에 남은 AI 처음 카드 기록도 비웁니다 (예시·다음 갱신에 다시 쓰이지 않음).
      켜짐 상태는 그대로이고, 이후 확정한 일과부터 다시 배웁니다.

      **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> clearMemory(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );
}
