package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.ArgumentMatchers.isNull;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.flash;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.model;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.view;

import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustType;
import com.chuseok22.elumserver.admin.application.dto.response.CreditAdjustPreview;
import com.chuseok22.elumserver.admin.application.exception.AdminViewExceptionHandler;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService;
import com.chuseok22.elumserver.admin.application.service.AdminCreditQueryService.JobFilter;
import com.chuseok22.elumserver.admin.application.service.AdminCreditService;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.Page;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/**
 * 관리자 크레딧 화면의 입력 오류가 500 이 아니라 폼 오류로 보이는지 (#407).
 *
 * <p>숫자 칸에 글자, 없는 필터 값, 바깥 주소로의 돌아가기 같은 입력이 화면을 깨뜨리지 않아야 한다.
 */
class AdminCreditControllerTest {

  private AdminCreditQueryService queryService;
  private AdminCreditService creditService;
  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    queryService = mock(AdminCreditQueryService.class);
    creditService = mock(AdminCreditService.class);
    when(creditService.currentPolicy()).thenReturn(AiCreditPolicy.disabledDefault());
    when(queryService.jobs(any(), anyInt())).thenReturn(Page.empty());
    mockMvc = MockMvcBuilders.standaloneSetup(new AdminCreditController(queryService, creditService))
      .setControllerAdvice(new AdminViewExceptionHandler())
      .build();
  }

  @Test
  @DisplayName("조정 — 수량에 글자가 오면 서비스까지 가지 않고 폼 오류로 돌아간다")
  void adjust_badAmount_flashError() throws Exception {
    mockMvc.perform(post("/admin/credits/members/m1/adjust")
        .param("type", "GRANT").param("amount", "삼십").param("reason", "보상"))
      .andExpect(status().is3xxRedirection())
      .andExpect(redirectedUrl("/admin/credits/members/m1"))
      .andExpect(flash().attribute("errorMessage", "조정하지 못했어요: 수량은 숫자로 적어주세요. (E-CRD-001)"));

    verify(creditService, never()).adjust(anyString(), any(), anyInt(), any(), any(), any());
  }

  @Test
  @DisplayName("조정 — 서비스 검사(차감 상한 등)에 걸리면 그 문구로 폼 오류")
  void adjust_serviceRejects_flashError() throws Exception {
    when(creditService.adjust(eq("m1"), eq(CreditAdjustType.DEDUCT), eq(50), isNull(), any(), eq("회수")))
      .thenThrow(new IllegalArgumentException("남은 크레딧(10)보다 많이 뺄 수 없어요."));

    mockMvc.perform(post("/admin/credits/members/m1/adjust")
        .param("type", "DEDUCT").param("amount", "50").param("reason", "회수"))
      .andExpect(flash().attribute("errorMessage",
        "조정하지 못했어요: 남은 크레딧(10)보다 많이 뺄 수 없어요. (E-CRD-001)"));
  }

  @Test
  @DisplayName("조정 — 반영하면 요약을 알린다")
  void adjust_success_flashMessage() throws Exception {
    when(creditService.adjust(eq("m1"), eq(CreditAdjustType.GRANT), eq(30), any(), any(), eq("보상")))
      .thenReturn(new CreditAdjustPreview(CreditAdjustType.GRANT, 30, 12, 42, null, false, false));

    mockMvc.perform(post("/admin/credits/members/m1/adjust")
        .param("type", "GRANT").param("amount", "30").param("expiryMode", "NONE").param("reason", "보상"))
      .andExpect(flash().attribute("message", "지급 반영했어요. 남음 12 → 42"));
  }

  @Test
  @DisplayName("미리보기 — 사유가 비면 같은 화면에 폼 오류를 두고 서비스는 부르지 않는다")
  void previewAdjust_blankReason_rendersError() throws Exception {
    mockMvc.perform(post("/admin/credits/members/m1/adjust/preview")
        .param("type", "GRANT").param("amount", "30").param("reason", " "))
      .andExpect(status().isOk())
      .andExpect(view().name("admin/credits-member-detail"))
      .andExpect(model().attribute("errorMessage", "조정할 수 없어요: 사유를 적어주세요. (E-CRD-001)"))
      .andExpect(model().attributeDoesNotExist("preview"));

    verify(creditService, never()).previewAdjust(anyString(), any(), anyInt(), any());
  }

  @Test
  @DisplayName("없는 회원 상세는 404 안내 화면이다")
  void memberDetail_unknown_404() throws Exception {
    when(queryService.memberDetail(eq("nope"), anyInt(), any(), anyInt()))
      .thenThrow(new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    mockMvc.perform(get("/admin/credits/members/nope"))
      .andExpect(status().isNotFound())
      .andExpect(model().attribute("error", ErrorCode.MEMBER_NOT_FOUND.getMessage()));
  }

  @Test
  @DisplayName("작업 탐색 — 틀린 상태·날짜는 필터를 끈 것으로 본다(400 아님)")
  void jobs_badFilterValues_ignored() throws Exception {
    mockMvc.perform(get("/admin/credits/jobs").param("status", "BOGUS").param("from", "어제").param("kind", "ROUTINE_CREATE"))
      .andExpect(status().isOk());

    ArgumentCaptor<JobFilter> filter = ArgumentCaptor.forClass(JobFilter.class);
    verify(queryService).jobs(filter.capture(), eq(0));
    assertThat(filter.getValue().status()).isNull();
    assertThat(filter.getValue().from()).isNull();
    assertThat(filter.getValue().kind()).isNotNull();
  }

  @Test
  @DisplayName("수동 반환 — 돌아갈 곳은 크레딧 화면 안으로만, 실패는 폼 오류")
  void release_backIsSanitized() throws Exception {
    when(creditService.manualRelease(eq("j1"), any(), eq("")))
      .thenThrow(new IllegalArgumentException("사유를 적어주세요."));

    mockMvc.perform(post("/admin/credits/jobs/j1/release").param("reason", "").param("back", "https://evil.example"))
      .andExpect(redirectedUrl("/admin/credits/jobs"))
      .andExpect(flash().attribute("errorMessage", "반환하지 못했어요: 사유를 적어주세요. (E-CRD-002)"));
    mockMvc.perform(post("/admin/credits/jobs/j1/release").param("reason", "멈춤")
        .param("back", "/admin/credits/members/m1"))
      .andExpect(redirectedUrl("/admin/credits/members/m1"));
  }

  @Test
  @DisplayName("정책 발행 — 숫자가 아닌 지급량은 폼 오류, 발행하지 않는다")
  void publish_badNumber_flashError() throws Exception {
    mockMvc.perform(post("/admin/credits/policy")
        .param("freeGrant", "백").param("proGrant", "100").param("costRoutineText", "1").param("costCardImage", "1")
        .param("costImageRegenerate", "1").param("ttlMinutes", "15").param("enabled", "true")
        .param("grantApply", "NEXT_PERIOD").param("reason", "조정"))
      .andExpect(redirectedUrl("/admin/credits/policy"))
      .andExpect(flash().attribute("errorMessage",
        "발행하지 못했어요: Free 주간 지급량은(는) 숫자로 적어주세요. (E-CRD-003)"));

    verify(creditService, never()).publishPolicy(any(), any());
  }
}
