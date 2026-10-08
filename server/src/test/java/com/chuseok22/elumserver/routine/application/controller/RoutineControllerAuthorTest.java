package com.chuseok22.elumserver.routine.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.jwt.AccessTokenDetails;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository.GuardianName;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineAuthorResolver;
import com.chuseok22.elumserver.routine.application.service.RoutineCreateService;
import com.chuseok22.elumserver.routine.application.service.RoutineProgressService;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService;
import com.chuseok22.elumserver.routine.application.service.RoutineService;
import com.chuseok22.elumserver.routine.application.service.RoutineStepPhotoService;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.Authentication;

/** 일과 응답을 내보내는 컨트롤러 길이 모두 만든 사람 정보를 싣는다 (#361). 앱이 읽는 값이 어느 길에서도 빠지지 않는지 본다. */
class RoutineControllerAuthorTest {

  private final RoutineService service = mock(RoutineService.class);
  private final RoutineCreateService createService = mock(RoutineCreateService.class);
  private final RoutineQueryService queryService = mock(RoutineQueryService.class);
  private final RoutineProgressService progressService = mock(RoutineProgressService.class);
  private final ProfileGuardianRepository guardians = mock(ProfileGuardianRepository.class);
  private final RoutineController controller = new RoutineController(
    service, createService, queryService, progressService, mock(RoutineStepPhotoService.class), new RoutineAuthorResolver(guardians));

  private final Authentication guardian = new TestingAuthenticationToken("member-1", null);

  private static RoutineResponse routineBy(String createdBy) {
    return new RoutineResponse("r1", "제목", "원문", "마스킹본", null, "CONFIRMED", null, null,
      0, 0, 0, null, null, List.of(), null, null, createdBy, null, null, "p1", "ko");
  }

  private static GuardianName dad() {
    return new GuardianName() {
      @Override
      public String getMemberId() {
        return "member-2";
      }

      @Override
      public String getDisplayName() {
        return "아빠";
      }
    };
  }

  @Test
  @DisplayName("단건·목록·생성 응답이 모두 createdByMe 와 creatorName 을 싣는다")
  void everyRoutineResponseCarriesAuthor() {
    List<GuardianName> names = List.of(dad());
    when(guardians.findNamesByProfileIdAndMemberIdIn(anyString(), any())).thenReturn(names);
    when(queryService.getRoutine(any(), anyString())).thenReturn(routineBy("member-2"));
    when(queryService.getMyRoutines(any())).thenReturn(List.of(routineBy("member-2")));
    when(createService.create(any(), any(), any())).thenReturn(routineBy("member-1"));

    RoutineResponse one = controller.getRoutine(guardian, "r1").getBody();
    RoutineResponse listed = controller.getMyRoutines(guardian, null).getBody().get(0);
    RoutineResponse created = controller.create(guardian, null, null, mock(RoutineCreateRequest.class)).getBody();

    assertThat(one.createdByMe()).isFalse();
    assertThat(one.creatorName()).isEqualTo("아빠");
    assertThat(listed.createdByMe()).isFalse();
    assertThat(listed.creatorName()).isEqualTo("아빠");
    assertThat(created.createdByMe()).isTrue();
  }

  @Test
  @DisplayName("이룸이 휴대폰은 createdByMe=false 이고 만든 사람 이름을 받지 않는다")
  void elumiGetsNoCreatorName() {
    TestingAuthenticationToken elumi = new TestingAuthenticationToken("member-1", null);
    elumi.setDetails(new AccessTokenDetails("link-1"));
    when(queryService.getTodayRoutines(any())).thenReturn(List.of(routineBy("member-2")));

    RoutineResponse r = controller.getTodayRoutines(elumi, null).getBody().get(0);

    assertThat(r.createdByMe()).isFalse();
    assertThat(r.creatorName()).isNull();
  }
}
