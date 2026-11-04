package com.chuseok22.elumserver.license.core;

import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import lombok.AllArgsConstructor;
import lombok.Getter;

/**
 * 플랜이 여는 권한 하나.
 *
 * <p>각 권한은 플랜별로 설정 키를 하나씩 들고 있다. <b>무엇이 Free고 무엇이 Pro인지가
 * 코드가 아니라 설정 값에 있다</b>는 뜻이다. 가격 정책이 정해지면 배포 없이 관리자
 * 화면에서 숫자만 바꾸면 된다.
 *
 * <p>플랜이 셋 이상 되거나 기관별 커스텀 한도가 필요해지면 이 매핑을 테이블로 옮긴다.
 * 그때도 {@code EntitlementService}를 부르는 쪽은 바뀌지 않는다.
 */
@Getter
@AllArgsConstructor
public enum Entitlement {

  AI_IMAGE_GENERATION(
    Kind.FLAG, "AI 맞춤 삽화",
    ConfigKey.FREE_AI_IMAGE_GENERATION, ConfigKey.PRO_AI_IMAGE_GENERATION
  ),
  ADS_REMOVED(
    Kind.FLAG, "광고 제거",
    ConfigKey.FREE_ADS_REMOVED, ConfigKey.PRO_ADS_REMOVED
  ),
  ROUTINE_CREATE_PER_DAY(
    Kind.LIMIT, "하루 일과 생성",
    ConfigKey.FREE_ROUTINE_CREATE_PER_DAY, ConfigKey.PRO_ROUTINE_CREATE_PER_DAY
  ),
  ROUTINE_CREATE_PER_WEEK(
    Kind.LIMIT, "주당 일과 생성",
    ConfigKey.FREE_ROUTINE_CREATE_PER_WEEK, ConfigKey.PRO_ROUTINE_CREATE_PER_WEEK
  ),
  ROUTINE_MAX_COUNT(
    Kind.LIMIT, "보유 일과 개수",
    ConfigKey.FREE_ROUTINE_MAX_COUNT, ConfigKey.PRO_ROUTINE_MAX_COUNT
  ),
  PROFILE_MAX_COUNT(
    Kind.LIMIT, "이룸이 명수",
    ConfigKey.FREE_PROFILE_MAX_COUNT, ConfigKey.PRO_PROFILE_MAX_COUNT
  ),
  HISTORY_RETENTION_DAYS(
    Kind.LIMIT, "기록 보관 일수",
    ConfigKey.FREE_HISTORY_RETENTION_DAYS, ConfigKey.PRO_HISTORY_RETENTION_DAYS
  ),
  // 카드 내보내기(이미지·인쇄)는 앱이 만든다 — 서버는 판정 값만 내려준다 (#1073)
  CARD_EXPORT_WITHOUT_WATERMARK(
    Kind.FLAG, "카드 내보내기 워터마크 없음",
    ConfigKey.FREE_CARD_EXPORT_WITHOUT_WATERMARK, ConfigKey.PRO_CARD_EXPORT_WITHOUT_WATERMARK
  ),
  CARD_EXPORT_ALL_THEMES(
    Kind.FLAG, "카드 내보내기 디자인 테마 전부",
    ConfigKey.FREE_CARD_EXPORT_ALL_THEMES, ConfigKey.PRO_CARD_EXPORT_ALL_THEMES
  ),
  // 요일·시각 반복 일과 + 이룸이 기기 일과 시간 알림 (#782, #1080). 꺼지면 예약만 멈추고 지우지 않음
  ROUTINE_SCHEDULE(
    Kind.FLAG, "요일별 반복 일과·이룸이 기기 알림",
    ConfigKey.FREE_ROUTINE_SCHEDULE, ConfigKey.PRO_ROUTINE_SCHEDULE
  ),
  ;

  /// 한도를 두지 않는다는 뜻. 수치 권한의 기본값이다.
  public static final int UNLIMITED = -1;

  private final Kind kind;
  private final String label;
  private final ConfigKey freeKey;
  private final ConfigKey proKey;

  public ConfigKey configKeyFor(PlanType plan) {
    return plan == PlanType.PRO ? proKey : freeKey;
  }

  public enum Kind {
    /// 켜짐/꺼짐
    FLAG,
    /// 수치 한도. -1이면 무제한
    LIMIT,
  }
}
