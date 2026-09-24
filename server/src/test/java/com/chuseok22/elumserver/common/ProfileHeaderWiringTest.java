package com.chuseok22.elumserver.common;

import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.link.application.controller.DeviceLinkController;
import com.chuseok22.elumserver.link.application.service.DeviceLinkService;
import com.chuseok22.elumserver.link.application.service.RedeemRateLimiter;
import com.chuseok22.elumserver.member.application.controller.MemberController;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.routine.application.controller.RoutineController;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineReorderRequest;
import com.chuseok22.elumserver.routine.application.service.RoutineService;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.security.authentication.UsernamePasswordAuthenticationToken;
import org.springframework.security.core.Authentication;

/**
 * {@code X-Profile-Id} 가 컨트롤러에서 서비스까지 빠짐없이 가는지 본다 (다중 보호자 4-4).
 *
 * <p>판단은 서비스의 ProfileAccessGuard 가 한다. 여기서 보는 것은 "헤더를 버리지 않았는가"다 —
 * 한 컨트롤러가 헤더를 빠뜨리면 그 API 만 늘 기본 이룸이를 보고, 테스트는 전부 통과한다.
 */
@ExtendWith(MockitoExtension.class)
class ProfileHeaderWiringTest {

  @Mock
  private RoutineService routineService;

  @Mock
  private MemberService memberService;

  @Mock
  private DeviceLinkService deviceLinkService;

  @Mock
  private RedeemRateLimiter rateLimiter;

  private final Authentication guardian = new UsernamePasswordAuthenticationToken("m1", null, List.of());

  @Test
  @DisplayName("E27 일과 목록은 헤더의 이룸이를 서비스로 넘긴다")
  void e27_routineList_passesProfileHeader() {
    new RoutineController(routineService).getTodayRoutines(guardian, "p9");

    verify(routineService).getTodayRoutines(Caller.guardian("m1", "p9"));
  }

  @Test
  @DisplayName("E36 헤더가 없으면 기본 이룸이 — 지금 앱")
  void e36_routineList_withoutHeader_meansDefault() {
    new RoutineController(routineService).getTodayRoutines(guardian, null);

    verify(routineService).getTodayRoutines(Caller.guardian("m1"));
  }

  @Test
  @DisplayName("일과 순서도 헤더의 이룸이로 간다")
  void reorder_passesProfileHeader() {
    new RoutineController(routineService).reorder(guardian, "p9", new RoutineReorderRequest(List.of("r1")));

    verify(routineService).reorder(Caller.guardian("m1", "p9"), List.of("r1"));
  }

  @Test
  @DisplayName("내 정보도 헤더의 이룸이로 간다")
  void memberMe_passesProfileHeader() {
    new MemberController(memberService).getMyInfo(guardian, "p9");

    verify(memberService).getMyInfo(Caller.guardian("m1", "p9"));
  }

  @Test
  @DisplayName("연결 암호는 헤더의 이룸이에 발급된다 — 그 휴대폰이 볼 이룸이다")
  void deviceLinkIssue_passesProfileHeader() {
    new DeviceLinkController(deviceLinkService, rateLimiter).issue(guardian, "p9");

    verify(deviceLinkService).issue(Caller.guardian("m1", "p9"));
  }
}
