package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.security.Principal;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/** 일과 생성 가능 언어 저장이 관리자 화면에서 어떻게 거절·안내되는지 본다 (다국어 #526). */
@ExtendWith(MockitoExtension.class)
class AdminConfigControllerLocaleTest {

  @Mock private SystemConfigService systemConfigService;
  @Mock private ImageClientRouter imageClientRouter;
  @Mock private TextClientRouter textClientRouter;

  private AdminConfigController controller;
  private final Principal admin = () -> "admin";

  @BeforeEach
  void setUp() {
    controller = new AdminConfigController(systemConfigService, imageClientRouter, textClientRouter);
  }

  @Test
  @DisplayName("ko 만 켜는 저장은 통과해 설정 서비스로 간다 — ko 문구 한 벌은 늘 완성이다")
  void koOnly_passesThrough() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko", null, admin, flash);

    verify(systemConfigService).update(eq(ConfigKey.ENABLED_CONTENT_LOCALES), eq("ko"), any(), any());
    assertThat(flash.getFlashAttributes()).containsKey("message").doesNotContainKey("errorMessage");
  }

  @Test
  @DisplayName("모르는 언어 코드는 저장 전에 막고 E-CFG-001 로 알린다")
  void unknownCode_isRejected() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko,xx", null, admin, flash);

    verify(systemConfigService, never()).update(any(), any(), any(), any());
    assertThat((String) flash.getFlashAttributes().get("errorMessage")).contains("E-CFG-001");
  }

  @Test
  @DisplayName("서버 문구 파일이 비어 있는 언어는 켤 수 없다고 E-CFG-004 로 알린다")
  void notReady_isExplained() {
    doThrow(new CustomException(ErrorCode.CONTENT_LOCALE_NOT_READY))
      .when(systemConfigService).update(any(), any(), any(), any());
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko", null, admin, flash);

    assertThat((String) flash.getFlashAttributes().get("errorMessage")).contains("E-CFG-004").contains("문구 파일");
  }
}
