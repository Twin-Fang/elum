package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryEnabledRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryImportRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryRuleCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineMemoryRuleUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryExportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryImportResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryObservationResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.enums.ParameterIn;
import io.swagger.v3.oas.annotations.tags.Tag;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(name = "Routine Memory", description = "AI 메모리 API (Pro): 보호자 한 사람이 이룸이 한 명에게 쓰는 카드 만들기 규칙. accessToken(Bearer) 인증이 필요합니다.")
public interface RoutineMemoryControllerDocs {

  @Operation(
    summary = "AI 메모리 보기",
    description = """
      이 보호자의 이 이룸이 규칙(`rules`)과 수정 기록(`edits`)을 돌려줍니다. 다른 보호자의 규칙은 보이지 않습니다.

      - 규칙 정렬: ACTIVE, WATCHING, OFF 순 > 그 안에서 최근 것 먼저. `evidences` 는 규칙마다 최근 5개, `edits` 는 최근 20개.
      - `WATCHING`(관찰 중)은 일과 만들 때 쓰지 않습니다. 보호자가 "항상 이렇게"를 누르거나, 같은 수정이 서로 다른 일과 `autoApplyCount`개에서 관찰되면 `ACTIVE` 가 됩니다.
      - **Free**: `available=false`, 나머지는 비어 있습니다 (403 아님 — 화면이 미리 보기만 판단).

      **403**: 이룸이 기기 토큰 (`PROFILE_ACCESS_DENIED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> getMemory(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "규칙 직접 적기",
    description = """
      직접 적은 규칙(`MANUAL`)을 `ACTIVE` 로 저장합니다. 같은 글이 이미 있으면 그대로 둡니다. 최대 20개.

      **400**: 빈 글 · 60자 초과 · 20개 초과 (`INVALID_INPUT_VALUE`), 진단·장애·정도·연락처·기관 이름이 든 글 (`ROUTINE_MEMORY_LINE_NOT_ALLOWED`)
      **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> addRule(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineMemoryRuleCreateRequest request
  );

  @Operation(
    summary = "규칙 고치기",
    description = """
      `status`(`ACTIVE` | `OFF`) 또는 `text`(직접 적은 규칙만) 중 하나 이상. `WATCHING` > `ACTIVE` 가 "항상 이렇게 / 지금 적용"입니다.
      `OFF` 인 규칙은 같은 수정이 더 관찰돼도 저절로 켜지지 않습니다.

      **400**: 값 없음 · `WATCHING` 으로 바꾸기 · 직접 적지 않은 규칙의 글 고치기 · 남의 규칙 id (`INVALID_INPUT_VALUE`), 금지 낱말 (`ROUTINE_MEMORY_LINE_NOT_ALLOWED`)
      **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> updateRule(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    @Parameter(description = "규칙 id") String ruleId,
    RoutineMemoryRuleUpdateRequest request
  );

  @Operation(
    summary = "규칙 지우기",
    description = """
      규칙과 근거를 지웁니다. 같은 수정(종류·바꾸기 전·후 낱말)을 AI 가 다시 찾아와도 되살리지 않습니다 (거절 기억).

      **400**: 없는 규칙·남의 규칙 id (`INVALID_INPUT_VALUE`) · **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> deleteRule(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    @Parameter(description = "규칙 id") String ruleId
  );

  @Operation(
    summary = "AI 메모리 켜기/끄기",
    description = """
      끄면 고친 카드에서 수정을 찾지도, 일과 만들기에 규칙을 넣지도 않습니다. 규칙은 남습니다.

      **400**: `enabled` 없음 · **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> setEnabled(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineMemoryEnabledRequest request
  );

  @Operation(
    summary = "AI 메모리 모두 지우기",
    description = """
      이 보호자·이 이룸이의 규칙·근거·수정 기록·거절 기억과, 이 보호자가 만든 일과의 AI 처음 카드 사본 표시를 모두 지웁니다.
      켜짐 상태는 그대로입니다.

      **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryResponse> clearMemory(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "방금 고쳐서 보낸 일과에서 찾은 수정",
    description = """
      일과를 고쳐 확정한 직후 몇 초 동안 물어 "다음에도 이렇게 할까요?"를 띄우는 데 씁니다.

      - `PENDING`: 아직 찾는 중 · `READY`: 찾음(`items`) · `NONE`: 고친 게 없거나 대상이 아님(꺼짐·Pro 아님·남의 일과 포함)
      - 끈 규칙(`OFF`)은 `items` 에서 뺍니다.
      """
  )
  ResponseEntity<RoutineMemoryObservationResponse> getObservations(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    @Parameter(description = "방금 보낸 일과 id") String routineId
  );

  @Operation(
    summary = "AI 메모리 내보내기",
    description = """
      규칙만 `elum.routine-memory.v1` 모양으로 돌려줍니다. 이룸이 이름·회원 식별값·근거 일과 제목은 넣지 않습니다.

      **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryExportResponse> exportMemory(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId
  );

  @Operation(
    summary = "AI 메모리 가져오기",
    description = """
      내보내기와 같은 모양을 받아 병합합니다. 같은 (종류, before, after, 요약)은 건너뛰고, 필터·형식에 걸린 항목은 버립니다.
      가져온 규칙의 상태는 파일 값입니다 (`WATCHING` 은 근거 0 으로 시작). 종류가 `MANUAL` 이면 직접 적은 규칙, 그 밖은 `AI` 출처입니다.

      **400**: 모르는 `schema` · 규칙 목록 없음 · 200개 초과 (`INVALID_INPUT_VALUE`) · **403**: Free (`ROUTINE_MEMORY_PRO_REQUIRED`)
      """
  )
  ResponseEntity<RoutineMemoryImportResponse> importMemory(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineMemoryImportRequest request
  );
}
