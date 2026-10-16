package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;

import com.chuseok22.elumserver.admin.application.service.PromptLocaleGate;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.util.Set;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/** 프롬프트 행이 없는 언어는 켤 수 없다 — 관리자 화면에서 저장 전에 막고 이유와 에러 코드를 알린다. */
class AdminConfigControllerPromptGateTest {

  private SystemConfigService systemConfigService;
  private PromptLocaleGate promptLocaleGate;
  private AdminConfigController controller;
  private RedirectAttributesModelMap redirect;

  @BeforeEach
  void setUp() {
    systemConfigService = mock(SystemConfigService.class);
    promptLocaleGate = mock(PromptLocaleGate.class);
    controller = new AdminConfigController(
      systemConfigService, mock(ImageClientRouter.class), mock(TextClientRouter.class), promptLocaleGate);
    redirect = new RedirectAttributesModelMap();
  }

  @Test
  @DisplayName("행이 없는 언어를 켜려 하면 저장하지 않고 이유와 에러 코드(E-CFG-005)를 알린다")
  void missingPromptRows_blockEnabling() {
    doThrow(new CustomException(ErrorCode.CONTENT_LOCALE_PROMPT_MISSING)).when(promptLocaleGate).requireReady(any());

    String view = controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko,es", null, null, redirect);

    assertThat(view).isEqualTo("redirect:/admin/settings");
    assertThat((String) redirect.getFlashAttributes().get("errorMessage"))
      .contains("E-CFG-005").contains("기본값으로 행 만들기");
    verify(systemConfigService, never()).update(any(), anyString(), any(), any());
  }

  @Test
  @DisplayName("게이트에는 정규화된 켤 언어 목록(ko 포함)이 넘어간다")
  void gateReceivesTheNormalizedLocales() {
    doThrow(new CustomException(ErrorCode.CONTENT_LOCALE_PROMPT_MISSING)).when(promptLocaleGate).requireReady(any());

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "es", null, null, redirect);

    verify(promptLocaleGate).requireReady(eq(Set.of(AppLocale.KO, AppLocale.ES)));
  }

  @Test
  @DisplayName("ko 만 켜는 저장은 통과해 설정 서비스로 간다")
  void koOnly_passesThrough() {
    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko", null, null, redirect);

    verify(promptLocaleGate).requireReady(eq(Set.of(AppLocale.KO)));
    verify(systemConfigService).update(eq(ConfigKey.ENABLED_CONTENT_LOCALES), eq("ko"), any(), any());
  }

  @Test
  @DisplayName("다른 설정 키는 프롬프트 게이트를 보지도 않는다")
  void otherKeys_untouched() {
    controller.update(ConfigKey.GEMINI_TEXT_MODEL, "gemini-flash-latest", null, null, redirect);

    verifyNoInteractions(promptLocaleGate);
  }
}
