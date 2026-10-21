package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.service.PromptLocaleGate;
import com.chuseok22.elumserver.admin.application.service.SystemConfigOverviewService;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.TextClientRouter;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.member.application.dto.response.MemberPickerItem;
import com.chuseok22.elumserver.member.application.service.MemberPickerService;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.security.Principal;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

/** 광고 항상 노출 회원 저장 (#912): 없는 회원 ID 는 막고, 형식 거부는 이유를 입력칸 옆에 보낸다. */
class AdminConfigControllerMemberIdsTest {

  private static final String EXISTING_MEMBER_ID = "0f8fad5b-d9cb-469f-a165-70867728950e";
  private static final String UNKNOWN_MEMBER_ID = "7c9e6679-7425-40de-944b-e07fc1f90ae7";

  private SystemConfigService systemConfigService;
  private MemberPickerService memberPickerService;
  private AdminConfigController controller;
  private final Principal admin = () -> "admin";

  @BeforeEach
  void setUp() {
    systemConfigService = mock(SystemConfigService.class);
    memberPickerService = mock(MemberPickerService.class);
    controller = new AdminConfigController(systemConfigService, mock(ImageClientRouter.class),
      mock(TextClientRouter.class), mock(PromptLocaleGate.class), mock(SystemConfigOverviewService.class),
      memberPickerService);
    when(memberPickerService.findExisting(any())).thenReturn(List.of(
      new MemberPickerItem(EXISTING_MEMBER_ID, "tester", "시험", "ACTIVE", "활성")));
  }

  @Test
  @DisplayName("없는 회원 ID 가 섞이면 저장하지 않고 어느 ID 인지 알린다 — 오타가 저장되면 광고 시험이 조용히 빗나간다")
  void unknownMember_isRejected() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ADS_ALWAYS_SHOWN_MEMBER_IDS, EXISTING_MEMBER_ID + "," + UNKNOWN_MEMBER_ID,
      null, admin, flash);

    verify(systemConfigService, never()).update(any(), any(), any(), any());
    assertThat((String) flash.getFlashAttributes().get("errorMessage"))
      .contains("없는 회원").contains(UNKNOWN_MEMBER_ID.substring(0, 8)).contains("E-CFG-001");
  }

  @Test
  @DisplayName("있는 회원만이면 저장한다")
  void existingMembers_areSaved() {
    RedirectAttributesModelMap flash = new RedirectAttributesModelMap();

    controller.update(ConfigKey.ADS_ALWAYS_SHOWN_MEMBER_IDS, EXISTING_MEMBER_ID, null, admin, flash);

    verify(systemConfigService).update(eq(ConfigKey.ADS_ALWAYS_SHOWN_MEMBER_IDS), eq(EXISTING_MEMBER_ID), any(), any());
  }

  @Test
  @DisplayName("빠른 저장이 거부되면 검사 이유를 reason 으로 따로 준다 — 화면이 입력칸 옆에 보인다")
  void asyncRejection_carriesReason() {
    doThrow(new CustomException(ErrorCode.SYSTEM_CONFIG_INVALID_VALUE, "버전은 2.69.1 로 적어요"))
      .when(systemConfigService).update(any(), any(), any(), any());

    Map<String, Object> result = controller.updateAsync(ConfigKey.MIN_APP_VERSION_IOS, "v1", null, admin);

    assertThat(result).containsEntry("ok", false);
    assertThat((String) result.get("reason")).contains("버전은 2.69.1 로 적어요").contains("E-CFG-001");
  }
}
