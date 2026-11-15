package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminCreditPurchaseRow;
import com.chuseok22.elumserver.admin.application.list.AdminListDefaults;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPurchaseAdminQueryService;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPurchaseAdminQueryService.PurchaseFilter;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPurchaseRefundService;
import com.chuseok22.elumserver.credit.infrastructure.entity.AiCreditPurchase;
import com.chuseok22.elumserver.license.application.service.refund.StoreRefundRecheckService;
import com.chuseok22.elumserver.license.application.service.store.StoreConsumableRefundHandler.ConsumableRefundOutcome;
import com.chuseok22.elumserver.license.core.StoreRefundCheckTrigger;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StoreRefundCheckRun;
import java.util.List;
import java.util.Map;
import java.util.Objects;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;

/**
 * 관리자 크레딧 구매·환불 화면: 구매 목록(회원 이름 붙이기), 건별 수동 회수, 환불 재확인 기록·지금 확인
 */
@Service
@RequiredArgsConstructor
public class AdminCreditPurchaseService {

  private final CreditPurchaseAdminQueryService purchaseQueryService;
  private final CreditPurchaseRefundService refundService;
  private final StoreRefundRecheckService recheckService;
  private final AdminMemberFilter memberFilter;

  /// 구매 목록 한 쪽: 최근 구매부터 (동률은 id 로 고정)
  public Page<AdminCreditPurchaseRow> search(PurchaseFilter filter, int page) {
    Pageable pageable = PageRequest.of(Math.max(page, 0), AdminListDefaults.PAGE_SIZE,
      Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id")));
    Page<AiCreditPurchase> purchases = purchaseQueryService.search(filter, pageable);
    Map<String, String> displayNameById = memberFilter.displayNamesOf(purchases.getContent().stream()
      .map(AiCreditPurchase::getMemberId).filter(Objects::nonNull).distinct().toList());
    return purchases.map(purchase -> new AdminCreditPurchaseRow(purchase, displayNameById.get(purchase.getMemberId())));
  }

  /// 건별 수동 회수: 남은 양만 회수, 원장에 관리자·사유
  public ConsumableRefundOutcome revoke(String purchaseId, String actor, String reason) {
    return refundService.revokeByAdmin(purchaseId, actor, reason);
  }

  /// 지금 확인: 두 스토어 재확인 1회 (실행 기록에 관리자 남김)
  public List<StoreRefundCheckRun> runRecheckNow(String actor) {
    return recheckService.runAll(StoreRefundCheckTrigger.ADMIN, actor);
  }

  public RecheckOverview recheckOverview() {
    return new RecheckOverview(recheckService.isScheduleEnabled(), recheckService.recentRuns(),
      recheckService.storesNeedingAttention());
  }

  /**
   * 환불 재확인 칸
   *
   * @param attentionStores 매일 재확인이 켜졌는데 마지막 실행 실패이거나 26시간 넘게 성공이 없는 스토어
   */
  public record RecheckOverview(boolean isScheduleEnabled, List<StoreRefundCheckRun> recentRuns,
                                List<SubscriptionSource> attentionStores) {

  }
}
