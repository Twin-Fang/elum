package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.license.core.SubscriptionSource;
import java.time.LocalDateTime;

/**
 * 회원 구독에 반영할 스토어 구매 1건 (Pro 를 주는 구매 중 가장 늦게 끝나는 것)
 *
 * @param purchaseId    store_purchase.id (subscription.external_ref 에 저장)
 * @param entitledUntil Pro 유지 마지막 시각 (유예 포함)
 */
public record StoreEntitlement(SubscriptionSource store, String purchaseId, String productId, LocalDateTime entitledUntil) {

}
