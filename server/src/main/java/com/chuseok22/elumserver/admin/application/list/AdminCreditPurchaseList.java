package com.chuseok22.elumserver.admin.application.list;

import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Column;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Filter;
import com.chuseok22.elumserver.admin.application.list.AdminListDefinition.Option;
import com.chuseok22.elumserver.credit.application.service.purchase.CreditPurchaseAdminQueryService.PurchaseFilter;
import com.chuseok22.elumserver.credit.core.CreditPurchaseStatus;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.util.Arrays;
import java.util.List;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;

/**
 * 크레딧 구매·환불 목록 선언: 검색(거래 id·회원 id 완전 일치), 필터 2개(스토어, 상태), 정렬, 조건 > 검색 조건·Pageable 변환
 * 정렬은 구매한 때만 허용 (기본 최근순)
 */
public final class AdminCreditPurchaseList {

  /// 필터 키
  public static final String FILTER_STORE = "store";
  public static final String FILTER_STATUS = "status";

  /// 정렬 키 (열 키와 같음)
  public static final String SORT_CREATED_AT = "createdAt";

  /// 스토어 선택지: 크레딧 꾸러미를 파는 두 스토어
  public static final List<Option> STORE_OPTIONS = List.of(SubscriptionSource.APPLE_IAP, SubscriptionSource.GOOGLE_IAP)
    .stream().map(store -> new Option(store.name(), store.getLabel())).toList();
  public static final List<Option> STATUS_OPTIONS = Arrays.stream(CreditPurchaseStatus.values())
    .map(status -> new Option(status.name(), status.getLabel())).toList();

  public static final AdminListDefinition DEFINITION = new AdminListDefinition(
    List.of(
      new Column(SORT_CREATED_AT, "구매", true),
      new Column("member", "회원", false),
      new Column("store", "스토어", false),
      new Column("product", "상품", false),
      Column.numeric("credits", "크레딧", false),
      new Column("transactionId", "거래 id", false),
      new Column("status", "상태", false),
      new Column("refund", "환불", false),
      new Column("actions", "회수", false)),
    List.of("transactionId", "memberId"),
    List.of(
      new Filter(FILTER_STORE, "스토어", STORE_OPTIONS),
      new Filter(FILTER_STATUS, "상태", STATUS_OPTIONS)),
    SORT_CREATED_AT + AdminListDefinition.SORT_DELIMITER + AdminListDefinition.SORT_DESCENDING);

  private AdminCreditPurchaseList() {
  }

  /// 조건 > 구매 검색 조건 (정의로 보정된 값만 들어옴, 없으면 null = 그 조건 없음)
  public static PurchaseFilter filterOf(AdminListQuery query) {
    String store = query.filters().get(FILTER_STORE);
    String status = query.filters().get(FILTER_STATUS);
    return new PurchaseFilter(
      store == null ? null : SubscriptionSource.valueOf(store),
      status == null ? null : CreditPurchaseStatus.valueOf(status),
      query.q());
  }

  /// 조건 > 페이지 요청: 동률은 id 로 고정해 페이지가 겹치지 않게 한다
  public static Pageable pageableOf(AdminListQuery query) {
    Sort.Direction direction = query.isAscending() ? Sort.Direction.ASC : Sort.Direction.DESC;
    return PageRequest.of(query.pageIndex(), AdminListDefaults.PAGE_SIZE,
      Sort.by(new Sort.Order(direction, "createdAt"), new Sort.Order(Sort.Direction.ASC, "id")));
  }
}
