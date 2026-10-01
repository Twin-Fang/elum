package com.chuseok22.elumserver.routine.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.jwt.AccessTokenDetails;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineProgressSyncRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineService;
import com.chuseok22.elumserver.routine.application.service.RoutineStepPhotoService;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.security.authentication.TestingAuthenticationToken;
import org.springframework.security.core.Authentication;

/**
 * 이룸이 토큰이 받는 일과 응답에서 보호자 원문을 뺀다 (#357).
 *
 * <p>스프링을 띄우지 않는다. 컨트롤러가 호출자 종류에 따라 응답을 가공하는지만 본다.
 * 이룸이 토큰이 부를 수 있는 일과 엔드포인트(조회 전부 + 완료·취소·진행 동기화)가 대상이다.
 */
class RoutineControllerSourceTextTest {

  private static final String RAW = "내일 비가 오는데 하늘이가 학교에 갈 준비를 해야 해";
  private static final String MASKED = "내일 비가 오는데 <이름>이가 학교에 갈 준비를 해야 해";
  private static final String FEEDBACK = "좀 더 짧게 해줘";

  private final RoutineService service = mock(RoutineService.class);
  private final RoutineController controller = new RoutineController(service, mock(RoutineStepPhotoService.class));

  private final Authentication elumi = elumiAuth();
  private final Authentication guardian = new TestingAuthenticationToken("member-1", null);

  private static Authentication elumiAuth() {
    TestingAuthenticationToken token = new TestingAuthenticationToken("member-1", null);
    token.setDetails(new AccessTokenDetails("link-1"));
    return token;
  }

  private static RoutineResponse routine() {
    return routineBy("member-1");
  }

  /// createdBy 가 만든 보호자인 일과. guardian 토큰의 memberId 는 member-1 이다.
  private static RoutineResponse routineBy(String createdBy) {
    return new RoutineResponse("r1", "제목", RAW, MASKED, null, "CONFIRMED", FEEDBACK, null,
      0, 0, 0, null, null, List.of(), null, null, createdBy);
  }

  private static void assertStripped(RoutineResponse r) {
    assertThat(r.rawInputText()).isNull();
    assertThat(r.sanitizedInputText()).isNull();
    assertThat(r.revisionFeedback()).isNull();
    // 화면에 쓰는 값은 그대로다
    assertThat(r.id()).isEqualTo("r1");
    assertThat(r.title()).isEqualTo("제목");
    assertThat(r.status()).isEqualTo("CONFIRMED");
  }

  private static void assertKept(RoutineResponse r) {
    assertThat(r.rawInputText()).isEqualTo(RAW);
    assertThat(r.sanitizedInputText()).isEqualTo(MASKED);
    assertThat(r.revisionFeedback()).isEqualTo(FEEDBACK);
  }

  @Test
  @DisplayName("이룸이 토큰: 단건·목록·오늘·지난·임시저장 조회에서 원문 계열이 빠진다")
  void elumiReadsAreStripped() {
    when(service.getRoutine(any(), anyString())).thenReturn(routine());
    when(service.getMyRoutines(any())).thenReturn(List.of(routine()));
    when(service.getTodayRoutines(any())).thenReturn(List.of(routine()));
    when(service.getPastRoutines(any())).thenReturn(List.of(routine()));
    when(service.getDraftRoutines(any())).thenReturn(List.of(routine()));

    assertStripped(controller.getRoutine(elumi, "r1").getBody());
    controller.getMyRoutines(elumi, null).getBody().forEach(RoutineControllerSourceTextTest::assertStripped);
    controller.getTodayRoutines(elumi, null).getBody().forEach(RoutineControllerSourceTextTest::assertStripped);
    controller.getPastRoutines(elumi, null).getBody().forEach(RoutineControllerSourceTextTest::assertStripped);
    controller.getDraftRoutines(elumi, null).getBody().forEach(RoutineControllerSourceTextTest::assertStripped);
  }

  @Test
  @DisplayName("이룸이 토큰: 단계 완료·취소·진행 동기화 응답에서도 원문 계열이 빠진다")
  void elumiProgressWritesAreStripped() {
    when(service.completeStep(any(), anyString(), anyString())).thenReturn(routine());
    when(service.cancelStep(any(), anyString(), anyString())).thenReturn(routine());
    when(service.syncProgress(any(), anyString(), any())).thenReturn(routine());

    assertStripped(controller.completeStep(elumi, "r1", "s1").getBody());
    assertStripped(controller.cancelStep(elumi, "r1", "s1").getBody());
    assertStripped(controller.syncProgress(elumi, "r1", new RoutineProgressSyncRequest(List.of())).getBody());
  }

  @Test
  @DisplayName("보호자 토큰: 조회 응답은 그대로다")
  void guardianReadsAreUntouched() {
    when(service.getRoutine(any(), anyString())).thenReturn(routine());
    when(service.getMyRoutines(any())).thenReturn(List.of(routine()));
    when(service.getTodayRoutines(any())).thenReturn(List.of(routine()));

    assertKept(controller.getRoutine(guardian, "r1").getBody());
    controller.getMyRoutines(guardian, null).getBody().forEach(RoutineControllerSourceTextTest::assertKept);
    controller.getTodayRoutines(guardian, null).getBody().forEach(RoutineControllerSourceTextTest::assertKept);
  }

  @Test
  @DisplayName("다른 보호자가 만든 일과: 보호자 토큰이어도 원문 계열이 빠지고 제목·상태는 그대로다")
  void otherGuardiansRoutineIsStripped() {
    when(service.getRoutine(any(), anyString())).thenReturn(routineBy("member-2"));
    when(service.getMyRoutines(any())).thenReturn(List.of(routineBy("member-2")));
    when(service.getTodayRoutines(any())).thenReturn(List.of(routineBy("member-2")));
    when(service.getPastRoutines(any())).thenReturn(List.of(routineBy("member-2")));
    when(service.getDraftRoutines(any())).thenReturn(List.of(routineBy("member-2")));

    assertStripped(controller.getRoutine(guardian, "r1").getBody());
    controller.getMyRoutines(guardian, null).getBody().forEach(RoutineControllerSourceTextTest::assertStripped);
    controller.getTodayRoutines(guardian, null).getBody().forEach(RoutineControllerSourceTextTest::assertStripped);
    controller.getPastRoutines(guardian, null).getBody().forEach(RoutineControllerSourceTextTest::assertStripped);
    controller.getDraftRoutines(guardian, null).getBody().forEach(RoutineControllerSourceTextTest::assertStripped);
  }

  @Test
  @DisplayName("다른 보호자가 만든 일과: 단계 완료·취소·진행 동기화 응답에서도 원문 계열이 빠진다")
  void otherGuardiansProgressWritesAreStripped() {
    when(service.completeStep(any(), anyString(), anyString())).thenReturn(routineBy("member-2"));
    when(service.cancelStep(any(), anyString(), anyString())).thenReturn(routineBy("member-2"));
    when(service.syncProgress(any(), anyString(), any())).thenReturn(routineBy("member-2"));

    assertStripped(controller.completeStep(guardian, "r1", "s1").getBody());
    assertStripped(controller.cancelStep(guardian, "r1", "s1").getBody());
    assertStripped(controller.syncProgress(guardian, "r1", new RoutineProgressSyncRequest(List.of())).getBody());
  }

  @Test
  @DisplayName("만든 사람이 비어 있는 옛 일과: 연결된 보호자에게는 기존대로 보인다")
  void legacyRoutineWithoutCreatorStaysVisibleToGuardian() {
    when(service.getRoutine(any(), anyString())).thenReturn(routineBy(null));
    when(service.getMyRoutines(any())).thenReturn(List.of(routineBy(null)));

    assertKept(controller.getRoutine(guardian, "r1").getBody());
    controller.getMyRoutines(guardian, null).getBody().forEach(RoutineControllerSourceTextTest::assertKept);
  }

  @Test
  @DisplayName("만든 사람이 비어 있어도 이룸이 토큰에는 원문을 주지 않는다")
  void legacyRoutineWithoutCreatorIsStrippedForElumi() {
    when(service.getRoutine(any(), anyString())).thenReturn(routineBy(null));

    assertStripped(controller.getRoutine(elumi, "r1").getBody());
  }
}
