package com.chuseok22.elumserver.admin.application.dto.response;

import com.chuseok22.elumserver.admin.application.dto.request.CreditAdjustType;
import java.time.LocalDateTime;

/**
 * 관리자 크레딧 조정의 미리보기이자 반영 결과 (#407). 미리보기와 반영이 같은 계산을 거친다.
 *
 * @param expiresAt 지급 묶음의 만료. null 이면 무기한(지급이 아니면 뜻 없음)
 */
public record CreditAdjustPreview(
  CreditAdjustType type,
  int amount,
  int availableBefore,
  int availableAfter,
  LocalDateTime expiresAt,
  boolean frozenBefore,
  boolean frozenAfter
) {

  /// 확인 화면 한 줄 — "남음 12 → 42, 즉시 적용".
  public String summary() {
    String status = frozenBefore == frozenAfter ? "" : (frozenAfter ? " · 동결" : " · 동결 해제");
    return "남음 " + availableBefore + " → " + availableAfter + status + ", 즉시 적용";
  }
}
