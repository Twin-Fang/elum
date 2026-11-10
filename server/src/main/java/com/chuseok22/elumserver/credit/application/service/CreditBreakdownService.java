package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.application.dto.response.CreditSummaryResponse.BreakdownLine;
import com.chuseok22.elumserver.credit.core.CreditBreakdownKind;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditGrant;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.List;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;

/**
 * 요약의 종류별 줄: 지금 유효한 묶음 > 종류 3개(PERIODIC · BONUS · PURCHASED)로 합산
 * PERIODIC 은 항상 한 줄, BONUS·PURCHASED 는 남은 양이 있거나 이번 주기에 받은 것이 있을 때만. 합계 remaining = 사용 가능 + 예약
 */
@Service
@RequiredArgsConstructor
public class CreditBreakdownService {

  private final AiCreditGrantRepository grantRepository;

  /// 읽기만 한다 (호출자 트랜잭션 안에서 불러 방금 만든 지급을 그대로 본다)
  public List<BreakdownLine> linesOf(String accountId, LocalDateTime now, LocalDateTime periodStart, ZoneId zone) {
    return linesOf(grantRepository.findValidForBreakdown(accountId, now, periodStart), zone);
  }

  static List<BreakdownLine> linesOf(List<AiCreditGrant> validGrants, ZoneId zone) {
    List<BreakdownLine> lines = new ArrayList<>();
    for (CreditBreakdownKind kind : CreditBreakdownKind.values()) {
      List<AiCreditGrant> ofKind = validGrants.stream()
        .filter(grant -> CreditBreakdownKind.of(grant.getSource()) == kind)
        .toList();
      if (ofKind.isEmpty() && kind != CreditBreakdownKind.PERIODIC) {
        continue;
      }
      int granted = ofKind.stream().mapToInt(AiCreditGrant::getAmount).sum();
      int remaining = ofKind.stream().mapToInt(AiCreditGrant::getRemaining).sum();
      lines.add(new BreakdownLine(
        kind, granted, Math.max(0, granted - remaining), remaining, earliestExpiryOf(ofKind, zone)));
    }
    return lines;
  }

  // 남은 양이 있는 묶음 중 가장 먼저 끝나는 만료 (만료 없는 묶음뿐이면 null = 제한 없음)
  private static java.time.OffsetDateTime earliestExpiryOf(List<AiCreditGrant> grants, ZoneId zone) {
    return grants.stream()
      .filter(grant -> grant.getRemaining() > 0 || grants.stream().noneMatch(other -> other.getRemaining() > 0))
      .map(AiCreditGrant::getExpiresAt)
      .filter(Objects::nonNull)
      .min(Comparator.naturalOrder())
      .map(expiresAt -> expiresAt.atZone(zone).toOffsetDateTime())
      .orElse(null);
  }
}
