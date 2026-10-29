package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.AiFailureKind;
import com.chuseok22.elumserver.common.application.alert.IncidentAlert;
import com.chuseok22.elumserver.common.application.alert.IncidentAlertService;
import com.chuseok22.elumserver.common.application.alert.IncidentAlertType;
import com.chuseok22.elumserver.common.infrastructure.properties.IncidentAlertProperties;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ConcurrentHashMap;
import java.util.concurrent.atomic.AtomicInteger;
import org.springframework.stereotype.Component;

/**
 * AI 제공자 연속 실패 알림: 제공자 줄(OpenAI 그림, Gemini 글 등)별 연속 실패 수 > 기준 이상이면 알림 (#648)
 * 같은 줄 성공 1건 > 0 으로 되돌림, 실패 문구는 원인 분류 이름만 싣고 원문은 싣지 않음
 */
@Component
public class AiProviderFailureAlerter {

  private final IncidentAlertService incidentAlertService;
  private final int consecutiveFailureThreshold;
  private final Map<String, AtomicInteger> consecutiveFailureCountByLane = new ConcurrentHashMap<>();

  public AiProviderFailureAlerter(
    IncidentAlertService incidentAlertService, IncidentAlertProperties incidentAlertProperties
  ) {
    this.incidentAlertService = incidentAlertService;
    this.consecutiveFailureThreshold = incidentAlertProperties.aiConsecutiveFailureThreshold();
  }

  public void onSuccess(AiCallType callType) {
    consecutiveFailureCountByLane.remove(callType.providerLaneLabel());
  }

  public void onFailure(AiCallType callType, String errorMessage) {
    String lane = callType.providerLaneLabel();
    int consecutiveFailureCount = consecutiveFailureCountByLane
      .computeIfAbsent(lane, key -> new AtomicInteger())
      .incrementAndGet();
    if (consecutiveFailureCount < consecutiveFailureThreshold) {
      return;
    }
    // 항목 4개: 제공자 줄, 연속 실패 수, 최근 원인 분류, 호출 유형 (쿨다운은 줄 단위)
    incidentAlertService.notify(new IncidentAlert(IncidentAlertType.AI_PROVIDER_CONSECUTIVE_FAILURE, lane, List.of(
      new IncidentAlert.Detail("제공자", lane),
      new IncidentAlert.Detail("건수", "연속 " + consecutiveFailureCount + "회 실패 (기준 " + consecutiveFailureThreshold + "회)"),
      new IncidentAlert.Detail("최근 원인", AiFailureKind.classify(errorMessage).getLabel()),
      new IncidentAlert.Detail("호출 유형", callType.name())
    )));
  }
}
