package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineExampleCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.Parameter;
import io.swagger.v3.oas.annotations.enums.ParameterIn;
import io.swagger.v3.oas.annotations.tags.Tag;
import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;

@Tag(name = "Routine", description = "온보딩 예시 일과 API (#803). accessToken(Bearer) 인증이 필요합니다.")
public interface RoutineExampleControllerDocs {

  @Operation(
    summary = "온보딩 예시 일과 만들기 (#803)",
    description = """
      온보딩에서 고른 분류마다 예시 일과 2개를 **오늘 일과**로 만듭니다. **AI·크레딧을 쓰지 않습니다.**

      **분류 코드**: `MORNING_EVENING` · `SCHOOL_STUDY` · `HOUSE_SELF` · `OUTSIDE`

      **동작**
      - 상태 `CONFIRMED`, `isExample = true`. 이룸이 기기에 바로 보입니다.
      - `scheduledAt` 은 오늘 날짜 + 예시별 기본 시각입니다. 다음 날부터는 지난 일과입니다.
      - 화면 언어가 한국어면 한국어 문장, 그 외는 영어 문장입니다.
      - 보유 일과 한도에 세지 않습니다.
      - 이 이룸이에 예시가 이미 있으면 아무것도 만들지 않고 빈 목록을 돌려줍니다.

      **400**: 빈 목록 · 모르는 분류 코드
      """
  )
  ResponseEntity<List<RoutineResponse>> createExamples(
    Authentication authentication,
    @Parameter(in = ParameterIn.HEADER, name = Caller.PROFILE_HEADER, description = Caller.PROFILE_HEADER_DESCRIPTION) String profileId,
    RoutineExampleCreateRequest request
  );
}
