package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.core.CreditPeriod;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPolicy;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditPolicyRepository;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Set;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 크레딧 정책 버전 조회·발행 (#407).
 *
 * <p>일과 생성마다 정책을 묻는다. 30초 캐시로 요청마다 DB 를 두드리지 않고, 서버가 여러 대여도 발행 뒤
 * 30초 안에 수렴한다(SystemConfigService 와 같은 절충).
 */
@Slf4j
@Service
public class CreditPolicyService {

  /// 관리자가 적는 사유의 최대 길이. 원장·작업에는 "[관리자 반환] " 같은 머리말이 붙어도 컬럼(500) 안에 든다.
  public static final int ADMIN_REASON_MAX_LENGTH = 200;

  private static final long CACHE_TTL_MILLIS = 30_000;
  private static final Set<String> GRANT_APPLY_VALUES =
    Set.of(AiCreditPolicy.GRANT_APPLY_NEXT_PERIOD, AiCreditPolicy.GRANT_APPLY_IMMEDIATE);
  private static final ObjectMapper JSON = new ObjectMapper();

  private final AiCreditPolicyRepository policyRepository;
  private final Clock clock;

  private volatile AiCreditPolicy cached;
  private volatile long cachedAtMillis;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 빠뜨리면 서버가 뜨지 않는다.
  @Autowired
  public CreditPolicyService(AiCreditPolicyRepository policyRepository) {
    this(policyRepository, Clock.systemDefaultZone());
  }

  CreditPolicyService(AiCreditPolicyRepository policyRepository, Clock clock) {
    this.policyRepository = policyRepository;
    this.clock = clock;
  }

  /**
   * 지금 유효한 정책. 시작 시각이 지난 것 중 가장 높은 버전이고, 하나도 없으면 꺼진 기본 정책이다.
   *
   * <p>DB 오류는 그대로 던진다 — 정책을 모르는 채 크레딧 없이 열어 두면 비용이 장부 밖으로 샌다. 호출자가
   * AI_CREDIT_UNAVAILABLE 로 바꾼다.
   */
  public AiCreditPolicy current() {
    AiCreditPolicy snapshot = cached;
    long nowMillis = clock.millis();
    if (snapshot != null && nowMillis - cachedAtMillis < CACHE_TTL_MILLIS) {
      return snapshot;
    }
    AiCreditPolicy loaded = policyRepository
      .findFirstByEffectiveFromLessThanEqualOrderByVersionDesc(LocalDateTime.now(clock))
      .orElseGet(AiCreditPolicy::disabledDefault);
    cached = loaded;
    cachedAtMillis = nowMillis;
    return loaded;
  }

  /**
   * 이 주기의 주간 지급량을 정하는 정책. 켜기·단가는 {@link #current()} 를 쓰고 지급량만 여기서 읽는다.
   *
   * <ol>
   *   <li>이 주기 안에 IMMEDIATE 로 발행한 버전이 있으면 그중 최신 — 관리자 서비스가 이미 준 지급도 그
   *       지급량으로 맞췄으므로, 뒤늦게 처음 온 회원도 같은 양을 받아야 한다.</li>
   *   <li>아니면 주기 시작 시각에 유효하던 버전 — NEXT_PERIOD 발행은 "다음 주부터"라서, 주 중간에 처음 온
   *       회원에게 새 지급량을 주면 이번 주로 샌다.</li>
   *   <li>주기 시작 때 버전이 하나도 없으면(V26 이 주 중간에 v1 을 넣었다) 지금 정책.</li>
   * </ol>
   *
   * <p>회원마다 그 주 첫 지급 때 한 번만 부른다(지급 행이 있으면 부르지 않는다) — 캐시하지 않는다.
   * DB 오류는 {@link #current()} 처럼 그대로 던진다.
   */
  public AiCreditPolicy grantPolicyFor(CreditPeriod period) {
    LocalDateTime now = LocalDateTime.now(clock);
    // 주기 밖(끝난 뒤)에 발행한 IMMEDIATE 는 그 주기를 바꾸지 않는다. 끝은 포함하지 않는다.
    LocalDateTime until = now.isBefore(period.end()) ? now : period.end().minusNanos(1);
    return policyRepository
      .findFirstByGrantApplyAndEffectiveFromGreaterThanAndEffectiveFromLessThanEqualOrderByVersionDesc(
        AiCreditPolicy.GRANT_APPLY_IMMEDIATE, period.start(), until)
      .or(() -> policyRepository.findFirstByEffectiveFromLessThanEqualOrderByVersionDesc(period.start()))
      .orElseGet(this::current);
  }

  /**
   * 새 버전을 발행한다. 기존 행은 고치지 않는다 — 진행 중 작업과 지난 원장이 옛 버전을 가리킨다.
   *
   * <p>시작 시각은 발행 시각이다. NEXT_PERIOD/IMMEDIATE 는 "이번 주에 이미 준 지급에도 반영하는가"이고,
   * 그 조정은 관리자 서비스가 한다.
   *
   * @throws IllegalArgumentException 사유가 비었거나 숫자가 음수·TTL 이 1분 미만일 때 (관리자 폼 오류로 보인다)
   */
  @Transactional
  public AiCreditPolicy publish(PolicyDraft draft, String actor) {
    validate(draft);
    int nextVersion = policyRepository.findFirstByOrderByVersionDesc()
      .map(latest -> latest.getVersion() + 1)
      .orElse(1);

    AiCreditPolicy policy = new AiCreditPolicy();
    policy.setVersion(nextVersion);
    policy.setEnabled(draft.enabled());
    policy.setEffectiveFrom(LocalDateTime.now(clock));
    policy.setWeeklyGrantJson(toJson(draft.weeklyGrant()));
    policy.setActionCostsJson(toJson(draft.actionCosts()));
    policy.setReservationTtlMinutes(draft.reservationTtlMinutes());
    policy.setGrantApply(draft.grantApply());
    policy.setCreatedBy(actor);
    policy.setReason(draft.reason().trim());
    AiCreditPolicy saved = policyRepository.save(policy);

    // 이 서버는 바로 새 버전을 본다. 다른 서버는 캐시 TTL 안에 따라온다.
    cached = null;
    log.info("크레딧 정책 발행: version={}, enabled={}, actor={}", nextVersion, draft.enabled(), actor);
    return saved;
  }

  /// 버전 이력, 최신부터.
  @Transactional(readOnly = true)
  public List<AiCreditPolicy> history() {
    return policyRepository.findAllByOrderByVersionDesc();
  }

  private static void validate(PolicyDraft draft) {
    if (draft.reason() == null || draft.reason().isBlank()) {
      throw new IllegalArgumentException("정책을 바꾸는 사유를 적어주세요.");
    }
    if (draft.reason().trim().length() > ADMIN_REASON_MAX_LENGTH) {
      throw new IllegalArgumentException("사유는 " + ADMIN_REASON_MAX_LENGTH + "자까지 적을 수 있어요.");
    }
    if (draft.reservationTtlMinutes() < 1) {
      throw new IllegalArgumentException("예약 유지 시간은 1분 이상이어야 해요.");
    }
    if (!GRANT_APPLY_VALUES.contains(draft.grantApply())) {
      throw new IllegalArgumentException("적용 시점은 NEXT_PERIOD 나 IMMEDIATE 여야 해요.");
    }
    boolean negative = nullSafe(draft.weeklyGrant()).values().stream().anyMatch(v -> v == null || v < 0)
      || nullSafe(draft.actionCosts()).values().stream().anyMatch(v -> v == null || v < 0);
    if (negative) {
      throw new IllegalArgumentException("지급량과 단가는 0 이상이어야 해요.");
    }
  }

  private static <K> Map<K, Integer> nullSafe(Map<K, Integer> map) {
    return map == null ? Map.of() : map;
  }

  /// enum 키를 이름 문자열로 — 엔티티가 이름으로 읽는다.
  private static String toJson(Map<? extends Enum<?>, Integer> values) {
    Map<String, Integer> byName = new LinkedHashMap<>();
    if (values != null) {
      values.forEach((key, value) -> byName.put(key.name(), value));
    }
    try {
      return JSON.writeValueAsString(byName);
    } catch (JsonProcessingException e) {
      // 문자열·정수 맵이라 실제로는 나지 않는다. 나면 발행을 실패시킨다 — 빈 정책을 남기지 않는다.
      log.error("크레딧 정책 JSON 직렬화 실패: values={}", values, e);
      throw new CustomException(ErrorCode.INTERNAL_SERVER_ERROR);
    }
  }
}
