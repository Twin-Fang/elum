package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiGenerateContentResponse;
import com.chuseok22.elumserver.ai.infrastructure.entity.AiCallLog;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/**
 * AI 호출 결과 기록 서비스. 기록 실패는 절대 본 호출을 실패시키지 않는다 —
 * 내부에서 예외를 잡아 경고 로그만 남긴다(모니터링이 서비스 가용성보다 우선일 수 없다).
 * REQUIRES_NEW로 분리해 호출한 쪽 트랜잭션이 롤백돼도 로그는 남는다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class AiCallLogService {

  private static final int ERROR_MESSAGE_MAX_LENGTH = 500;
  private static final double TOKENS_PER_MILLION = 1_000_000.0;

  private final AiCallLogRepository aiCallLogRepository;
  private final SystemConfigService systemConfigService;

  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void recordSuccess(
    AiCallType callType, String model, long latencyMs,
    GeminiGenerateContentResponse.UsageMetadata usage
  ) {
    save(callType, model, true, null, latencyMs, usage);
  }

  @Transactional(propagation = Propagation.REQUIRES_NEW)
  public void recordFailure(AiCallType callType, String model, long latencyMs, String errorMessage) {
    save(callType, model, false, errorMessage, latencyMs, null);
  }

  private void save(
    AiCallType callType, String model, boolean success, String errorMessage,
    long latencyMs, GeminiGenerateContentResponse.UsageMetadata usage
  ) {
    try {
      AiCallLog callLog = new AiCallLog();
      callLog.setMemberId(AiCallContext.currentMemberId());
      callLog.setCallType(callType);
      callLog.setModel(model);
      callLog.setSuccess(success);
      callLog.setErrorMessage(truncate(errorMessage));
      callLog.setLatencyMs(latencyMs);
      if (usage != null) {
        callLog.setPromptTokens(usage.promptTokenCount());
        callLog.setOutputTokens(usage.candidatesTokenCount());
        callLog.setTotalTokens(usage.totalTokenCount());
      }
      callLog.setEstimatedCostUsd(success ? estimateCostUsd(callType, usage) : 0.0);
      aiCallLogRepository.save(callLog);
    } catch (Exception e) {
      log.warn("AI 호출 로그 저장 실패 (본 호출에는 영향 없음): callType={}, model={}", callType, model, e);
    }
  }

  // 기록 시점의 시스템 설정 요금 단가로 비용을 추정한다.
  // 이미지: 장당 고정 단가 / 텍스트: 입출력 토큰 종량 / 로컬 LLM: 자체 호스팅이라 0.
  private double estimateCostUsd(AiCallType callType, GeminiGenerateContentResponse.UsageMetadata usage) {
    return switch (callType) {
      case GEMINI_IMAGE -> systemConfigService.getDouble(ConfigKey.PRICE_GEMINI_IMAGE_PER_IMAGE);
      case GEMINI_TEXT_CREATE, GEMINI_TEXT_QUESTION -> {
        if (usage == null) {
          yield 0.0;
        }
        double promptTokens = usage.promptTokenCount() == null ? 0 : usage.promptTokenCount();
        double outputTokens = usage.candidatesTokenCount() == null ? 0 : usage.candidatesTokenCount();
        yield promptTokens / TOKENS_PER_MILLION
          * systemConfigService.getDouble(ConfigKey.PRICE_GEMINI_TEXT_INPUT_PER_1M)
          + outputTokens / TOKENS_PER_MILLION
          * systemConfigService.getDouble(ConfigKey.PRICE_GEMINI_TEXT_OUTPUT_PER_1M);
      }
      case LOCAL_LLM_DLP -> 0.0;
    };
  }

  private String truncate(String message) {
    if (message == null || message.length() <= ERROR_MESSAGE_MAX_LENGTH) {
      return message;
    }
    return message.substring(0, ERROR_MESSAGE_MAX_LENGTH);
  }
}
