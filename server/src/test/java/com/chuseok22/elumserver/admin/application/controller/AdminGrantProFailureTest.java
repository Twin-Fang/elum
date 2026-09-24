package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.flash;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.admin.application.exception.AdminViewExceptionHandler;
import com.chuseok22.elumserver.admin.application.service.AdminMemberService;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.springframework.boot.test.system.CapturedOutput;
import org.springframework.boot.test.system.OutputCaptureExtension;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/**
 * Pro 발급이 실패했을 때 관리자가 보는 안내 (이슈 #372 운영 E2E D1).
 *
 * <p>상세를 열어 둔 사이 회원이 탈퇴하면 발급 버튼이 화면에 남아 있다. 전에는 컨트롤러가 모든 실패를
 * "사유를 입력해주세요" 로 바꿔 사유를 넣었는데도 그 안내가 떴고, 진짜 원인(탈퇴 계정)은 서버 로그에도
 * 남지 않았다. 정지·해제·강제 로그아웃·Pro 회수는 같은 경우 409 "탈퇴한 계정이에요" 를 낸다.
 */
@ExtendWith(OutputCaptureExtension.class)
class AdminGrantProFailureTest {

  private AdminMemberService adminMemberService;
  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    adminMemberService = mock(AdminMemberService.class);
    mockMvc = MockMvcBuilders.standaloneSetup(new AdminMemberController(adminMemberService))
      .setControllerAdvice(new AdminViewExceptionHandler())
      .build();
  }

  @Test
  @DisplayName("D1 탈퇴 계정에 Pro 발급 — 사유 안내가 아니라 다른 탈퇴 계정 조작과 같은 409 안내를 내고 로그에 남긴다")
  void grantPro_withdrawnMember_showsWithdrawnNotMemoHint(CapturedOutput output) throws Exception {
    doThrow(new CustomException(ErrorCode.MEMBER_WITHDRAWN))
      .when(adminMemberService).grantPro(anyString(), any(), anyString());

    mockMvc.perform(post("/admin/members/m1/grant-pro").param("days", "1").param("memo", "QA 발급"))
      .andExpect(status().isConflict())
      .andExpect(model().attribute("error", ErrorCode.MEMBER_WITHDRAWN.getMessage()))
      .andExpect(flash().attributeCount(0));

    assertThat(output).contains("[관리자 화면] MEMBER_WITHDRAWN");
  }

  @Test
  @DisplayName("D1 탈퇴 계정 안내는 정지와 같은 모양이다 — 같은 원인에 두 가지 안내를 내지 않는다")
  void grantPro_withdrawnMember_sameAsSuspend() throws Exception {
    doThrow(new CustomException(ErrorCode.MEMBER_WITHDRAWN))
      .when(adminMemberService).grantPro(anyString(), any(), anyString());
    doThrow(new CustomException(ErrorCode.MEMBER_WITHDRAWN))
      .when(adminMemberService).suspend(anyString());

    Object grantError = mockMvc.perform(post("/admin/members/m1/grant-pro").param("memo", "QA 발급"))
      .andReturn().getModelAndView().getModel().get("error");
    Object suspendError = mockMvc.perform(post("/admin/members/m1/suspend"))
      .andReturn().getModelAndView().getModel().get("error");

    assertThat(grantError).isEqualTo(suspendError);
  }

  @Test
  @DisplayName("사유가 비었을 때만 사유 입력 안내를 낸다 — 상세 화면에 머물러 다시 넣을 수 있다")
  void grantPro_blankMemo_stillShowsMemoHint() throws Exception {
    doThrow(new CustomException(ErrorCode.INVALID_INPUT_VALUE))
      .when(adminMemberService).grantPro(anyString(), any(), anyString());

    mockMvc.perform(post("/admin/members/m1/grant-pro").param("memo", " "))
      .andExpect(status().is3xxRedirection())
      .andExpect(flash().attribute("errorMessage", "Pro 발급 실패: 사유를 입력해주세요. (E-ADM-001)"));
  }
}
