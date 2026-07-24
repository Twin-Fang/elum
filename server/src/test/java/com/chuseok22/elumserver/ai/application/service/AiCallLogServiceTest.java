package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse.UsageMetadata;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class AiCallLogServiceTest {

  @Mock
  private AiCallLogRepository aiCallLogRepository;

  @Mock
  private SystemConfigService systemConfigService;

  @InjectMocks
  private AiCallLogService aiCallLogService;

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  @Test
  @DisplayName("텍스트 성공 기록은 토큰 종량으로 비용을 계산한다")
  void recordSuccess_textCall_computesTokenBasedCost() {
    when(systemConfigService.getDouble(ConfigKey.PRICE_GEMINI_TEXT_INPUT_PER_1M)).thenReturn(0.30);
    when(systemConfigService.getDouble(ConfigKey.PRICE_GEMINI_TEXT_OUTPUT_PER_1M)).thenReturn(2.50);
    AiCallContext.setMemberId("member-1");

    aiCallLogService.recordSuccess(
      AiCallType.GEMINI_TEXT_CREATE, "gemini-2.5-flash", 1200,
      new UsageMetadata(1_000_000, 2_000_000, 3_000_000)
    );

    ArgumentCaptor<AiCallLog> captor = ArgumentCaptor.forClass(AiCallLog.class);
    verify(aiCallLogRepository).save(captor.capture());
    AiCallLog saved = captor.getValue();
    assertThat(saved.getMemberId()).isEqualTo("member-1");
    assertThat(saved.isSuccess()).isTrue();
    assertThat(saved.getPromptTokens()).isEqualTo(1_000_000);
    assertThat(saved.getOutputTokens()).isEqualTo(2_000_000);
    // 1M 입력 × $0.30 + 2M 출력 × $2.50 = $5.30
    assertThat(saved.getEstimatedCostUsd()).isEqualTo(5.30);
  }

  @Test
  @DisplayName("이미지 성공 기록은 장당 고정 단가로 비용을 계산한다")
  void recordSuccess_imageCall_usesPerImagePrice() {
    when(systemConfigService.getDouble(ConfigKey.PRICE_GEMINI_IMAGE_PER_IMAGE)).thenReturn(0.039);

    aiCallLogService.recordSuccess(AiCallType.GEMINI_IMAGE, "gemini-image", 3000, null);

    ArgumentCaptor<AiCallLog> captor = ArgumentCaptor.forClass(AiCallLog.class);
    verify(aiCallLogRepository).save(captor.capture());
    assertThat(captor.getValue().getEstimatedCostUsd()).isEqualTo(0.039);
    // 컨텍스트가 없으면 회원 미상(null)으로 남는다.
    assertThat(captor.getValue().getMemberId()).isNull();
  }

  @Test
  @DisplayName("로컬 LLM은 자체 호스팅이므로 비용 0으로 기록한다")
  void recordSuccess_localLlm_zeroCost() {
    aiCallLogService.recordSuccess(AiCallType.LOCAL_LLM_DLP, "exaone", 500, null);

    ArgumentCaptor<AiCallLog> captor = ArgumentCaptor.forClass(AiCallLog.class);
    verify(aiCallLogRepository).save(captor.capture());
    assertThat(captor.getValue().getEstimatedCostUsd()).isZero();
  }

  @Test
  @DisplayName("실패 기록은 비용 0에 에러 메시지를 500자로 잘라 저장한다")
  void recordFailure_truncatesErrorMessage() {
    aiCallLogService.recordFailure(AiCallType.GEMINI_TEXT_CREATE, "gemini", 900, "에러".repeat(600));

    ArgumentCaptor<AiCallLog> captor = ArgumentCaptor.forClass(AiCallLog.class);
    verify(aiCallLogRepository).save(captor.capture());
    assertThat(captor.getValue().isSuccess()).isFalse();
    assertThat(captor.getValue().getErrorMessage()).hasSize(500);
    assertThat(captor.getValue().getEstimatedCostUsd()).isZero();
  }

  @Test
  @DisplayName("usage가 없는 텍스트 성공 기록도 예외 없이 비용 0으로 저장한다")
  void recordSuccess_missingUsage_zeroCost() {
    aiCallLogService.recordSuccess(AiCallType.GEMINI_TEXT_QUESTION, "gemini", 800, null);

    ArgumentCaptor<AiCallLog> captor = ArgumentCaptor.forClass(AiCallLog.class);
    verify(aiCallLogRepository).save(captor.capture());
    assertThat(captor.getValue().getEstimatedCostUsd()).isZero();
    assertThat(captor.getValue().getTotalTokens()).isNull();
  }

  @Test
  @DisplayName("로그 저장이 실패해도 예외를 밖으로 던지지 않는다")
  void recordSuccess_repositoryFailure_doesNotThrow() {
    when(aiCallLogRepository.save(any())).thenThrow(new RuntimeException("DB down"));

    assertThatCode(() -> aiCallLogService.recordSuccess(AiCallType.LOCAL_LLM_DLP, "exaone", 100, null))
      .doesNotThrowAnyException();
  }
}
