package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.admin.application.dto.response.AdminPushPreviewResponse;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushSendResponse;
import com.chuseok22.elumserver.admin.application.service.AdminPushService;
import com.chuseok22.elumserver.admin.core.AdminPushOutcome;
import com.chuseok22.elumserver.notification.application.service.AdminMessageSendResult;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.mock.web.MockHttpSession;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/// 화면 스크립트가 읽는 JSON 계약: 거절이면 400 + 사유·오류 코드(아니면 화면이 성공으로 읽음), 미리 계산은 늘 200, 먼저 받을 회원은 세션에 남음
class AdminPushApiControllerTest {

  private static final String REQUEST_BODY = """
    {"targetMode":"MEMBERS","memberIds":["m1"],"title":"제목","body":"본문","route":"home","testMemberId":" me "}
    """;

  private final AdminPushService adminPushService = mock(AdminPushService.class);
  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    mockMvc = MockMvcBuilders.standaloneSetup(new AdminPushApiController(adminPushService)).build();
  }

  @Test
  @DisplayName("보내기 거절(야간)은 400 이고 outcome·errorCode 를 싣는다")
  void send_rejected_returns400WithReason() throws Exception {
    when(adminPushService.send(any())).thenReturn(AdminPushSendResponse.rejected(AdminPushOutcome.QUIET_HOURS));

    mockMvc.perform(post("/admin/push/api/send").contentType(MediaType.APPLICATION_JSON).content(REQUEST_BODY))
      .andExpect(status().isBadRequest())
      .andExpect(jsonPath("$.outcome").value("QUIET_HOURS"))
      .andExpect(jsonPath("$.errorCode").value("E-PUSH-003"));
  }

  @Test
  @DisplayName("보내기 성공은 200 이고 기기 성공·실패 수를 싣는다")
  void send_sent_returns200WithCounts() throws Exception {
    when(adminPushService.send(any()))
      .thenReturn(AdminPushSendResponse.sent(3, new AdminMessageSendResult("msg-1", 3, 2, 1)));

    mockMvc.perform(post("/admin/push/api/send").contentType(MediaType.APPLICATION_JSON).content(REQUEST_BODY))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.outcome").value("SENT"))
      .andExpect(jsonPath("$.sentDeviceCount").value(2))
      .andExpect(jsonPath("$.failedDeviceCount").value(1));
  }

  @Test
  @DisplayName("미리 계산은 상한 초과여도 200 이고 수를 보여 준다")
  void preview_tooMany_returns200() throws Exception {
    when(adminPushService.preview(any())).thenReturn(
      AdminPushPreviewResponse.of(AdminPushOutcome.TOO_MANY_RECIPIENTS, 1200, 1100, 900, 1000, false));

    mockMvc.perform(post("/admin/push/api/preview").contentType(MediaType.APPLICATION_JSON).content(REQUEST_BODY))
      .andExpect(status().isOk())
      .andExpect(jsonPath("$.outcome").value("TOO_MANY_RECIPIENTS"))
      .andExpect(jsonPath("$.memberCount").value(1200))
      .andExpect(jsonPath("$.isQuietHours").value(false));
  }

  @Test
  @DisplayName("먼저 보내 보기는 받을 회원 id 를 공백 없이 세션에 남긴다 (다음에 화면이 다시 채움)")
  void sendTest_storesTestMemberInSession() throws Exception {
    when(adminPushService.sendTest(any()))
      .thenReturn(AdminPushSendResponse.sent(1, new AdminMessageSendResult("msg-1", 1, 1, 0)));
    MockHttpSession session = new MockHttpSession();

    mockMvc.perform(post("/admin/push/api/test").session(session)
        .contentType(MediaType.APPLICATION_JSON).content(REQUEST_BODY))
      .andExpect(status().isOk());

    assertThat(session.getAttribute(AdminPushApiController.TEST_MEMBER_SESSION_KEY)).isEqualTo("me");
  }
}
