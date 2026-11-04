package com.chuseok22.elumserver.ai.infrastructure.client;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.AiCallLogService;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * OpenAI 그림 품질 고르기: 고품질 권한 회원만 고품질 키, 그 외(권한 없음·회원 미상·판정 실패)는 기본 품질 (#1075)
 */
class OpenAiImageClientQualityTest {

  private static final String MEMBER_ID = "m1";

  private final SystemConfigService systemConfigService = mock(SystemConfigService.class);
  private final EntitlementService entitlementService = mock(EntitlementService.class);
  private OpenAiImageClient client;

  @BeforeEach
  void setUp() {
    client = new OpenAiImageClient(null, null, systemConfigService, mock(AiCallLogService.class),
      entitlementService, mock(AiRestClientFactory.class));
    lenient().when(systemConfigService.getString(ConfigKey.OPENAI_IMAGE_QUALITY)).thenReturn("low");
    lenient().when(systemConfigService.getString(ConfigKey.OPENAI_IMAGE_QUALITY_PRO)).thenReturn("medium");
  }

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  @Test
  @DisplayName("고품질 권한이 켜진 회원은 고품질 키 값으로 그린다 — 안 붙으면 Pro 혜택이 사라진다")
  void usesProQualityWhenEntitled() {
    AiCallContext.setMemberId(MEMBER_ID);
    when(entitlementService.isAllowed(MEMBER_ID, Entitlement.IMAGE_HIGH_QUALITY)).thenReturn(true);

    assertThat(client.resolveQuality()).isEqualTo("medium");
  }

  @Test
  @DisplayName("고품질 권한이 꺼져 있으면 기본 품질 그대로 — 새면 그림 원가가 약 4배가 된다")
  void usesDefaultQualityWhenNotEntitled() {
    AiCallContext.setMemberId(MEMBER_ID);
    when(entitlementService.isAllowed(MEMBER_ID, Entitlement.IMAGE_HIGH_QUALITY)).thenReturn(false);

    assertThat(client.resolveQuality()).isEqualTo("low");
  }

  @Test
  @DisplayName("회원 미상(관리자 시험)은 권한을 묻지 않고 기본 품질")
  void usesDefaultQualityWithoutMember() {
    assertThat(client.resolveQuality()).isEqualTo("low");
    verify(entitlementService, never()).isAllowed(any(String.class), any(Entitlement.class));
  }

  @Test
  @DisplayName("권한 판정이 실패해도 그림은 기본 품질로 계속 그린다")
  void usesDefaultQualityWhenEntitlementCheckFails() {
    AiCallContext.setMemberId(MEMBER_ID);
    when(entitlementService.isAllowed(MEMBER_ID, Entitlement.IMAGE_HIGH_QUALITY))
      .thenThrow(new IllegalStateException("db down"));

    assertThat(client.resolveQuality()).isEqualTo("low");
  }

  @Test
  @DisplayName("배포만으로 그림 품질·원가가 바뀌지 않는다 — 기본 품질 low, 고품질 권한 Free·Pro 모두 꺼짐")
  void defaultsKeepCurrentImageCost() {
    assertThat(ConfigKey.OPENAI_IMAGE_QUALITY.getDefaultValue()).isEqualTo("low");
    assertThat(ConfigKey.OPENAI_IMAGE_MODEL.getDefaultValue()).isEqualTo("gpt-image-1-mini");
    assertThat(ConfigKey.OPENAI_IMAGE_QUALITY_PRO.getDefaultValue()).isEqualTo("medium");
    assertThat(ConfigKey.FREE_IMAGE_HIGH_QUALITY.getDefaultValue()).isEqualTo("false");
    assertThat(ConfigKey.PRO_IMAGE_HIGH_QUALITY.getDefaultValue()).isEqualTo("false");
  }
}
