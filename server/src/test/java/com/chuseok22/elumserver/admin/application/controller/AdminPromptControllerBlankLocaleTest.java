package com.chuseok22.elumserver.admin.application.controller;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.redirectedUrl;

import com.chuseok22.elumserver.admin.application.service.AdminAuditService;
import com.chuseok22.elumserver.admin.application.service.AdminPromptService;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/** 요청 바인딩까지 거치는 쓰기 경로 검사: 빈 locale 이 defaultValue 로 ko 가 되어 ko 행을 덮어쓰면 안 된다. */
class AdminPromptControllerBlankLocaleTest {

  private static final String UPDATE_URL = "/admin/prompts/" + PromptKey.GEMINI_ROUTINE_CREATE_PREFIX.name();

  private AdminPromptService adminPromptService;
  private MockMvc mockMvc;

  @BeforeEach
  void setUp() {
    adminPromptService = mock(AdminPromptService.class);
    mockMvc = MockMvcBuilders
      .standaloneSetup(new AdminPromptController(adminPromptService, mock(EnabledLocales.class), mock(AdminAuditService.class)))
      .build();
  }

  @Test
  @DisplayName("locale= (빈 값)으로 저장하면 ko 행에 쓰지 않고 거절한다")
  void update_emptyLocale_writesNothing() throws Exception {
    mockMvc.perform(post(UPDATE_URL).param("locale", "").param("content", "English"))
      .andExpect(redirectedUrl("/admin/prompts?locale=ko"));

    verify(adminPromptService, never()).update(any(), any(AppLocale.class), any(), any());
  }

  @Test
  @DisplayName("locale=공백 으로 저장하면 거절한다")
  void update_blankLocale_writesNothing() throws Exception {
    mockMvc.perform(post(UPDATE_URL).param("locale", "  ").param("content", "English"))
      .andExpect(redirectedUrl("/admin/prompts?locale=ko"));

    verify(adminPromptService, never()).update(any(), any(AppLocale.class), any(), any());
  }

  @Test
  @DisplayName("locale 파라미터가 아예 없으면 ko 에 저장한다")
  void update_missingLocale_isKo() throws Exception {
    mockMvc.perform(post(UPDATE_URL).param("content", "내용"))
      .andExpect(redirectedUrl("/admin/prompts?locale=ko"));

    verify(adminPromptService).update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.KO, "내용", null);
  }

  @Test
  @DisplayName("행 만들기도 공백 locale 은 시더를 부르지 않는다")
  void seed_blankLocale_doesNotSeed() throws Exception {
    mockMvc.perform(post("/admin/prompts/locales/{locale}/seed", "  "))
      .andExpect(redirectedUrl("/admin/prompts?locale=ko"));

    verify(adminPromptService, never()).seedLocale(any());
  }
}
