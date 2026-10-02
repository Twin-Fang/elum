package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.security.Principal;
import java.util.HashMap;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/**
 * 문구 한 벌이 비어 있는 언어를 켜면 거절되는지 본다 (다국어 #526).
 *
 * <p>ko·ja 는 완성, es 는 빈 파일로 가짜를 끼워 "켜는 언어마다 결과가 다르다"는 것을 값으로 증명한다.
 * 기본값(ko)만으로는 가드를 지워도 통과하므로 그 증거가 되지 못한다.
 */
@ExtendWith(MockitoExtension.class)
class AdminConfigControllerLocaleGuardTest {

  @Mock private SystemConfigService systemConfigService;
  @Mock private ImageClientRouter imageClientRouter;
  @Mock private TextClientRouter textClientRouter;

  private AdminConfigController controller;
  private final Principal admin = () -> "admin";

  @BeforeEach
  void setUp() {
    controller = new AdminConfigController(systemConfigService, imageClientRouter, textClientRouter);
    Map<String, String> complete = new HashMap<>();
    complete.put("suggestion.01.text", "t");
    for (String goal : new String[]{"PREPARE_ITEMS", "PREPARE_NEW"}) {
      complete.put("fallback." + goal + ".question", "q");
      for (int i = 1; i <= 3; i++) {
        complete.put("fallback." + goal + ".option." + i + ".label", "l");
      }
    }
    RoutinePhrases.overrideStandardForTesting(new RoutinePhrases(
      locale -> locale == AppLocale.KO || locale == AppLocale.JA ? complete : Map.of()));
  }

  @AfterEach
  void tearDown() {
    RoutinePhrases.resetStandardForTesting();
  }

  @Test
  @DisplayName("문구가 완성된 ja 는 켤 수 있다")
  void completeLocale_isSaved() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko,ja", null, admin, flash);

    verify(systemConfigService).update(eq(ConfigKey.ENABLED_CONTENT_LOCALES), eq("ko,ja"), any(), any());
    assertThat(flash.getFlashAttributes()).doesNotContainKey("errorMessage");
  }

  @Test
  @DisplayName("문구가 빈 es 를 켜면 저장 전에 E-CFG-004 로 거절한다")
  void incompleteLocale_isRejected() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, "ko,ja,es", null, admin, flash);

    verify(systemConfigService, never()).update(any(), any(), any(), any());
    assertThat((String) flash.getFlashAttributes().get("errorMessage")).contains("E-CFG-004").contains("문구 파일");
  }

  @Test
  @DisplayName("ko 를 빼고 비어 있는 es 만 적어도 ko 가 붙어 정규화되고 es 때문에 거절된다")
  void koOmitted_stillGuardsOthers() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ENABLED_CONTENT_LOCALES, " ES ", null, admin, flash);

    verify(systemConfigService, never()).update(any(), any(), any(), any());
    assertThat((String) flash.getFlashAttributes().get("errorMessage")).contains("E-CFG-004");
  }
}
