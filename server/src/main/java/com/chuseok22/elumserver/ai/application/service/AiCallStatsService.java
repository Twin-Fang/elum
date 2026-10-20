package com.chuseok22.elumserver.ai.application.service;

import com.chuseok22.elumserver.ai.application.dto.response.AiCallTypeUsage;
import com.chuseok22.elumserver.ai.application.dto.response.AiFailureCount;
import com.chuseok22.elumserver.ai.application.dto.response.AiHealthSnapshot;
import com.chuseok22.elumserver.ai.application.dto.response.AiProviderStatus;
import com.chuseok22.elumserver.ai.application.dto.response.AiUsageBucket;
import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.core.AiFailureKind;
import com.chuseok22.elumserver.ai.core.AiProvider;
import com.chuseok22.elumserver.ai.core.AiProviderHealth;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.CallOutcome;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository.UsageBucketRow;
import com.chuseok22.elumserver.common.application.stats.StatsBucketUnit;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * AI 호출 통계: 칸·유형별 사용량, 유형별 기간 합계, 제공자 상태 판정
 * 제공자 상태 = 최근 24시간 호출 결과 1회 조회 > 제공자 줄(제공자 × 글/그림)별 판정
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class AiCallStatsService {

  /// 상태 판정 창 (최근 60분): 오류 늘어남 · 호출 없음
  static final int HEALTH_WINDOW_MINUTES = 60;
  /// 크레딧·키 오류와 실패 묶음을 보는 범위 (최근 24시간)
  static final int HEALTH_LOOKBACK_HOURS = 24;
  /// 오류 늘어남: 창 안 최소 호출 수와 실패율(%)
  static final int DEGRADED_MINIMUM_CALL_COUNT = 3;
  static final int DEGRADED_FAILURE_PERCENT = 50;
  /// 마지막 실패 문구 화면 표시 길이
  private static final int FAILURE_SUMMARY_MAX_LENGTH = 120;

  private final AiCallLogRepository aiCallLogRepository;
  private final SystemConfigService systemConfigService;

  /** 기간[from, to] 칸·유형별 호출 수·성공 수·비용 (모르는 유형 이름은 건너뜀 — 옛 enum 값이 남아도 화면이 죽지 않게) */
  public List<AiUsageBucket> sumUsageByBucket(StatsBucketUnit unit, LocalDate from, LocalDate toInclusive) {
    List<UsageBucketRow> rows = aiCallLogRepository.sumUsageByBucketAndCallType(
      unit.sqlName(), from.atStartOfDay(), toInclusive.plusDays(1).atStartOfDay());
    List<AiUsageBucket> buckets = new ArrayList<>(rows.size());
    for (UsageBucketRow row : rows) {
      AiCallType callType = toCallTypeOrNull(row.getCallType());
      if (callType != null) {
        buckets.add(new AiUsageBucket(
          row.getBucket(), callType, row.getTotalCount(), row.getSuccessCount(), row.getTotalCostUsd()));
      }
    }
    return buckets;
  }

  /** 기간[from, to) 유형별 합계 */
  public List<AiCallTypeUsage> sumUsageByCallType(LocalDateTime from, LocalDateTime to) {
    return aiCallLogRepository.sumUsageByCallTypeBetween(from, to).stream()
      .map(usage -> new AiCallTypeUsage(
        usage.getCallType(), usage.getTotalCount(), usage.getSuccessCount(), usage.getTotalCostUsd()))
      .toList();
  }

  private static AiCallType toCallTypeOrNull(String name) {
    try {
      return name == null ? null : AiCallType.valueOf(name);
    } catch (IllegalArgumentException e) {
      return null;
    }
  }

  /** 지금 AI 상태: 선택된 글·그림 제공자 + 최근 24시간 호출 있던 제공자 */
  public AiHealthSnapshot loadHealthSnapshot(LocalDateTime now) {
    List<CallOutcome> outcomes = aiCallLogRepository.findOutcomesSince(now.minusHours(HEALTH_LOOKBACK_HOURS));
    Map<ProviderLane, List<CallOutcome>> outcomesByLane = groupByLane(outcomes);
    LocalDateTime windowStart = now.minusMinutes(HEALTH_WINDOW_MINUTES);
    List<AiProviderStatus> statuses = outcomesByLane.entrySet().stream()
      .map(entry -> toStatus(entry.getKey(), entry.getValue(), windowStart))
      .toList();
    return new AiHealthSnapshot(statuses, countFailures(outcomes));
  }

  // 선택된 제공자를 먼저 (호출 기록이 없어도 카드가 보이게) > 나머지는 기록 순
  private Map<ProviderLane, List<CallOutcome>> groupByLane(List<CallOutcome> outcomes) {
    Map<ProviderLane, List<CallOutcome>> outcomesByLane = new LinkedHashMap<>();
    selectedLane(ConfigKey.TEXT_PROVIDER_SELECTED, false)
      .ifPresent(lane -> outcomesByLane.put(lane, new ArrayList<>()));
    selectedLane(ConfigKey.IMAGE_PROVIDER_SELECTED, true)
      .ifPresent(lane -> outcomesByLane.put(lane, new ArrayList<>()));
    for (CallOutcome outcome : outcomes) {
      outcomesByLane.computeIfAbsent(ProviderLane.of(outcome.getCallType()), lane -> new ArrayList<>()).add(outcome);
    }
    return outcomesByLane;
  }

  private Optional<ProviderLane> selectedLane(ConfigKey selectionKey, boolean isImage) {
    AiProvider provider = AiProvider.fromConfigValue(systemConfigService.getString(selectionKey));
    return Optional.ofNullable(provider).map(selected -> new ProviderLane(selected, isImage));
  }

  private AiProviderStatus toStatus(ProviderLane lane, List<CallOutcome> laneOutcomes, LocalDateTime windowStart) {
    List<CallOutcome> windowOutcomes = laneOutcomes.stream()
      .filter(outcome -> !outcome.getCreatedAt().isBefore(windowStart))
      .toList();
    long windowSuccessCount = windowOutcomes.stream().filter(CallOutcome::isSuccess).count();
    CallOutcome lastSuccess = laneOutcomes.stream().filter(CallOutcome::isSuccess).findFirst().orElse(null);
    CallOutcome lastFailure = laneOutcomes.stream().filter(outcome -> !outcome.isSuccess()).findFirst().orElse(null);
    return new AiProviderStatus(
      lane.label(),
      judgeHealth(toJudgeInputs(laneOutcomes), windowStart),
      windowOutcomes.size(),
      windowSuccessCount,
      averageLatencyMilliseconds(windowOutcomes),
      lastSuccess == null ? null : lastSuccess.getCreatedAt(),
      lastFailure == null ? null : lastFailure.getCreatedAt(),
      lastFailure == null ? null : AiFailureKind.classify(lastFailure.getErrorMessage()),
      lastFailure == null ? null : summarize(lastFailure.getErrorMessage())
    );
  }

  /**
   * 상태 판정: 크레딧 소진 > 키 오류 > 오류 늘어남 > 호출 없음 > 정상
   * 크레딧·키는 24시간 중 가장 최근 호출이 그 실패일 때 (뒤에 성공이 없음). 창 밖이어도 본다 — 소진 뒤 호출이 끊겨도 놓치지 않게
   */
  static AiProviderHealth judgeHealth(List<JudgeInput> newestFirstOutcomes, LocalDateTime windowStart) {
    if (!newestFirstOutcomes.isEmpty() && !newestFirstOutcomes.get(0).isSuccess()) {
      AiFailureKind latestFailureKind = AiFailureKind.classify(newestFirstOutcomes.get(0).errorMessage());
      if (latestFailureKind == AiFailureKind.CREDIT) {
        return AiProviderHealth.CREDIT_EXHAUSTED;
      }
      if (latestFailureKind == AiFailureKind.KEY) {
        return AiProviderHealth.KEY_INVALID;
      }
    }
    List<JudgeInput> windowOutcomes = newestFirstOutcomes.stream()
      .filter(outcome -> !outcome.createdAt().isBefore(windowStart))
      .toList();
    if (windowOutcomes.isEmpty()) {
      return AiProviderHealth.IDLE;
    }
    long failureCount = windowOutcomes.stream().filter(outcome -> !outcome.isSuccess()).count();
    boolean isDegraded = windowOutcomes.size() >= DEGRADED_MINIMUM_CALL_COUNT
      && failureCount * 100 >= (long) DEGRADED_FAILURE_PERCENT * windowOutcomes.size();
    return isDegraded ? AiProviderHealth.DEGRADED : AiProviderHealth.HEALTHY;
  }

  /** 판정 입력 한 건 (조회 투영과 시험을 분리) */
  record JudgeInput(boolean isSuccess, String errorMessage, LocalDateTime createdAt) {
  }

  private static List<JudgeInput> toJudgeInputs(List<CallOutcome> outcomes) {
    return outcomes.stream()
      .map(outcome -> new JudgeInput(outcome.isSuccess(), outcome.getErrorMessage(), outcome.getCreatedAt()))
      .toList();
  }

  // 실패 묶음: (원인, 제공자 줄) > 건수·마지막 시각, 건수 많은 순
  private static List<AiFailureCount> countFailures(List<CallOutcome> outcomes) {
    Map<String, AiFailureCount> countByKey = new LinkedHashMap<>();
    for (CallOutcome outcome : outcomes) {
      if (outcome.isSuccess()) {
        continue;
      }
      AiFailureKind kind = AiFailureKind.classify(outcome.getErrorMessage());
      String laneLabel = ProviderLane.of(outcome.getCallType()).label();
      countByKey.merge(kind.name() + "|" + laneLabel,
        new AiFailureCount(kind, laneLabel, 1, outcome.getCreatedAt()),
        (existing, added) -> new AiFailureCount(kind, laneLabel, existing.count() + 1, existing.lastAt()));
    }
    return countByKey.values().stream()
      .sorted(Comparator.comparingLong(AiFailureCount::count).reversed())
      .toList();
  }

  private static long averageLatencyMilliseconds(List<CallOutcome> outcomes) {
    return Math.round(outcomes.stream()
      .map(CallOutcome::getLatencyMs)
      .filter(Objects::nonNull)
      .mapToLong(Long::longValue)
      .average()
      .orElse(0));
  }

  // 화면 표시용 한 줄 (줄바꿈 정리, 120자 제한)
  private static String summarize(String errorMessage) {
    if (errorMessage == null) {
      return null;
    }
    String singleLine = errorMessage.replaceAll("\\s+", " ").trim();
    return singleLine.length() <= FAILURE_SUMMARY_MAX_LENGTH
      ? singleLine
      : singleLine.substring(0, FAILURE_SUMMARY_MAX_LENGTH) + "…";
  }

  /** 제공자 줄: 제공자 × 글/그림 (카드 그림 호출만 그림) */
  record ProviderLane(AiProvider provider, boolean isImage) {

    static ProviderLane of(AiCallType callType) {
      return new ProviderLane(callType.getProvider(), callType.isImage());
    }

    String label() {
      return provider.laneLabel(isImage);
    }
  }
}
