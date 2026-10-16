package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.dto.request.PromptUpdateRequest;
import com.chuseok22.elumserver.admin.application.dto.response.PromptLocaleView;
import com.chuseok22.elumserver.admin.application.service.AdminPromptService;
import com.chuseok22.elumserver.ai.application.service.PromptTemplateSeeder;
import com.chuseok22.elumserver.ai.core.PromptKey;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import java.util.EnumSet;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.ui.ExtendedModelMap;
import org.springframework.validation.BeanPropertyBindingResult;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

class AdminPromptControllerLocaleTest {

  private AdminPromptService adminPromptService;
  private EnabledLocales enabledLocales;
  private AdminPromptController controller;

  @BeforeEach
  void setUp() {
    adminPromptService = mock(AdminPromptService.class);
    enabledLocales = mock(EnabledLocales.class);
    when(enabledLocales.current()).thenReturn(EnumSet.of(AppLocale.KO, AppLocale.EN));
    when(adminPromptService.missingKeys(any())).thenReturn(List.of());
    controller = new AdminPromptController(adminPromptService, enabledLocales);
  }

  @Test
  @DisplayName("모르는 언어 코드는 ko 화면으로 — 주소를 손으로 고쳐도 깨지지 않는다")
  void list_unknownLocale_fallsBackToKo() {
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.list("xx", model);

    assertThat(view).isEqualTo("admin/prompts");
    assertThat(model.getAttribute("selectedLocale")).isEqualTo("ko");
    verify(adminPromptService).getAll(AppLocale.KO);
  }

  @Test
  @DisplayName("켜지지 않은 언어를 열면 꺼짐 표시와 없는 행 목록이 모델에 실린다")
  void list_disabledLocale_showsMissingRows() {
    when(adminPromptService.missingKeys(AppLocale.ES))
      .thenReturn(List.of(PromptKey.FLUX_IMAGE_PROMPT_TRANSLATE));
    ExtendedModelMap model = new ExtendedModelMap();

    controller.list("es", model);

    assertThat(model.getAttribute("selectedLocale")).isEqualTo("es");
    assertThat(model.getAttribute("localeEnabled")).isEqualTo(false);
    assertThat((List<?>) model.getAttribute("missingKeys")).hasSize(1);
    @SuppressWarnings("unchecked")
    List<PromptLocaleView> views = (List<PromptLocaleView>) model.getAttribute("locales");
    assertThat(views).hasSize(5);
    assertThat(views).filteredOn(view -> view.code().equals("en")).singleElement()
      .satisfies(view -> assertThat(view.enabled()).isTrue());
    assertThat(views).filteredOn(view -> view.code().equals("es")).singleElement()
      .satisfies(view -> {
        assertThat(view.enabled()).isFalse();
        assertThat(view.missingCount()).isEqualTo(1);
      });
  }

  @Test
  @DisplayName("저장하면 그 언어 행만 고치고 같은 언어 탭으로 돌아온다")
  void update_staysOnTheLocaleTab() {
    PromptUpdateRequest request = new PromptUpdateRequest("내용");
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    String view = controller.update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "ja", request,
      new BeanPropertyBindingResult(request, "request"), redirect);

    assertThat(view).isEqualTo("redirect:/admin/prompts?locale=ja");
    verify(adminPromptService).update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.JA, "내용");
    assertThat(redirect.getFlashAttributes()).containsKey("message");
  }

  @Test
  @DisplayName("없는 행을 저장하려 하면 행 만들기를 먼저 누르라고 알린다 (E-PRM-002)")
  void update_missingRow_explainsHowToCreate() {
    PromptUpdateRequest request = new PromptUpdateRequest("내용");
    doThrow(new CustomException(ErrorCode.PROMPT_TEMPLATE_NOT_FOUND))
      .when(adminPromptService).update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.ZH, "내용");
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    String view = controller.update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "zh", request,
      new BeanPropertyBindingResult(request, "request"), redirect);

    assertThat(view).isEqualTo("redirect:/admin/prompts?locale=zh");
    assertThat((String) redirect.getFlashAttributes().get("errorMessage"))
      .contains("기본값으로 행 만들기").contains("E-PRM-002");
  }

  @Test
  @DisplayName("공백 저장은 지금과 같은 문구(E-PRM-001)로 거절한다")
  void update_blank_keepsTheExistingMessage() {
    PromptUpdateRequest request = new PromptUpdateRequest("   ");
    doThrow(new CustomException(ErrorCode.PROMPT_TEMPLATE_BLANK))
      .when(adminPromptService).update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, AppLocale.KO, "   ");
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    controller.update(PromptKey.GEMINI_ROUTINE_CREATE_PREFIX, "ko", request,
      new BeanPropertyBindingResult(request, "request"), redirect);

    assertThat((String) redirect.getFlashAttributes().get("errorMessage"))
      .endsWith("프롬프트를 저장하지 않았습니다. 내용을 입력해주세요. (E-PRM-001)");
  }

  @Test
  @DisplayName("기본값으로 행 만들기는 만든 수·건너뛴 수를 알리고 같은 탭으로 돌아온다")
  void seed_reportsCounts() {
    when(adminPromptService.seedLocale(AppLocale.ES)).thenReturn(new PromptTemplateSeeder.SeedResult(4, 0, 0));
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    String view = controller.seed("es", redirect);

    assertThat(view).isEqualTo("redirect:/admin/prompts?locale=es");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("새로 4개");
  }

  @Test
  @DisplayName("행 만들기가 일부 실패하면 오류 문구와 에러 코드를 보인다")
  void seed_failure_showsErrorCode() {
    when(adminPromptService.seedLocale(AppLocale.JA)).thenReturn(new PromptTemplateSeeder.SeedResult(3, 0, 1));
    RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

    controller.seed("ja", redirect);

    assertThat((String) redirect.getFlashAttributes().get("errorMessage")).contains("실패 1개").contains("E-PRM-003");
  }
}
