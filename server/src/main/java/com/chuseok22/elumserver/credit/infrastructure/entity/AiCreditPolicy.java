package com.chuseok22.elumserver.credit.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import com.chuseok22.elumserver.credit.core.CreditAction;
import com.chuseok22.elumserver.license.core.PlanType;
import com.fasterxml.jackson.core.type.TypeReference;
import com.fasterxml.jackson.databind.ObjectMapper;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;
import jakarta.persistence.UniqueConstraint;
import java.time.LocalDateTime;
import java.util.Map;
import lombok.Getter;
import lombok.Setter;
import lombok.extern.slf4j.Slf4j;

/**
 * 크레딧 정책 한 버전 (#407). 추가 전용 — 바꿀 때는 version+1 새 행을 발행한다.
 *
 * <p>플랜별 지급량·행동별 단가를 JSON 으로 둔다. 플랜·행동이 늘어도 표를 바꾸지 않는다.
 */
@Slf4j
@Entity
@Getter
@Setter
@Table(
  name = "ai_credit_policy",
  uniqueConstraints = @UniqueConstraint(name = "uk_ai_credit_policy_version", columnNames = "version")
)
public class AiCreditPolicy extends BaseEntity {

  public static final String GRANT_APPLY_NEXT_PERIOD = "NEXT_PERIOD";
  public static final String GRANT_APPLY_IMMEDIATE = "IMMEDIATE";

  /// 단가 키가 빠졌거나 JSON 이 깨졌을 때의 단가. 0 으로 두면 공짜로 새고, 크게 두면 멀쩡한 사용자가 막힌다.
  private static final int FALLBACK_COST = 1;
  private static final int REASON_MAX_LENGTH = 500;
  private static final int DEFAULT_TTL_MINUTES = 15;
  private static final ObjectMapper JSON = new ObjectMapper();
  private static final TypeReference<Map<String, Integer>> INT_MAP = new TypeReference<>() {
  };

  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(nullable = false)
  private int version;

  /// false 면 크레딧을 보지 않고 기존 일과 생성 횟수 한도로 돌아간다.
  @Column(nullable = false)
  private boolean enabled;

  @Column(name = "effective_from", nullable = false)
  private LocalDateTime effectiveFrom;

  /// {"FREE":100,"PRO":100}
  @Column(name = "weekly_grant", nullable = false, columnDefinition = "TEXT")
  private String weeklyGrantJson;

  /// {"ROUTINE_TEXT":1,"CARD_IMAGE":1,"IMAGE_REGENERATE":1}
  @Column(name = "action_costs", nullable = false, columnDefinition = "TEXT")
  private String actionCostsJson;

  @Column(name = "reservation_ttl_minutes", nullable = false)
  private int reservationTtlMinutes;

  /// NEXT_PERIOD | IMMEDIATE — 새 지급량을 이번 주 이미 준 지급에도 반영하는가.
  @Column(name = "grant_apply", nullable = false, length = 20)
  private String grantApply;

  /// 발행한 관리자 로그인 아이디(회원이 아니다). 컬럼 이름은 기본 규칙으로 created_by 가 된다 — routine.created_by 처럼
  /// 회원을 가리키는 컬럼이 아니라서 탈퇴 참조 검사(WithdrawCoversMemberReferencesTest)에 걸리지 않게 이름을 적지 않는다.
  private String createdBy;

  @Column(length = REASON_MAX_LENGTH)
  private String reason;

  /// 컬럼보다 긴 사유로 발행이 500 이 되지 않게 자른다. 폼 입력은 서비스가 먼저 200자로 막는다.
  public void setReason(String reason) {
    this.reason = (reason != null && reason.length() > REASON_MAX_LENGTH) ? reason.substring(0, REASON_MAX_LENGTH) : reason;
  }

  /**
   * 정책 행이 하나도 없을 때 쓰는 꺼진 정책. 크레딧 없이 기존 횟수 한도로 돈다.
   *
   * <p>V26 이 v1 을 넣으므로 운영에서는 나오지 않는다. 마이그레이션 전 로컬·테스트용 안전판이다.
   */
  public static AiCreditPolicy disabledDefault() {
    AiCreditPolicy policy = new AiCreditPolicy();
    policy.setVersion(0);
    policy.setEnabled(false);
    policy.setEffectiveFrom(LocalDateTime.MIN);
    policy.setWeeklyGrantJson("{}");
    policy.setActionCostsJson("{}");
    policy.setReservationTtlMinutes(DEFAULT_TTL_MINUTES);
    policy.setGrantApply(GRANT_APPLY_NEXT_PERIOD);
    return policy;
  }

  /// 이 플랜의 주간 지급량. 키가 없거나 JSON 이 깨졌으면 0 — 모르는 플랜에 임의로 주지 않는다.
  public int weeklyGrantFor(PlanType plan) {
    Integer amount = parse(weeklyGrantJson).get(plan.name());
    return amount == null ? 0 : Math.max(0, amount);
  }

  /// 이 행동의 단가. 키가 없거나 JSON 이 깨졌으면 1.
  public int costOf(CreditAction action) {
    return costFrom(actionCostsJson, action);
  }

  /**
   * 단가 JSON(작업의 cost_snapshot)에서 단가를 읽는다. 정산이 시작 시점 단가를 쓰려고 정책 행 없이 부른다.
   */
  public static int costFrom(String costsJson, CreditAction action) {
    Integer cost = parse(costsJson).get(action.name());
    return (cost == null || cost < 0) ? FALLBACK_COST : cost;
  }

  private static Map<String, Integer> parse(String json) {
    if (json == null || json.isBlank()) {
      return Map.of();
    }
    try {
      Map<String, Integer> parsed = JSON.readValue(json, INT_MAP);
      return parsed == null ? Map.of() : parsed;
    } catch (Exception e) {
      log.warn("크레딧 정책 JSON 파싱 실패 — 기본값으로 계산한다: json={}", json, e);
      return Map.of();
    }
  }
}
