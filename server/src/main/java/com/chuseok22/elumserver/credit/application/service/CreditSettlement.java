package com.chuseok22.elumserver.credit.application.service;

/**
 * 정산 결과 (#407).
 *
 * @param charged      실제 차감량
 * @param overage      청구했지만 잔액이 모자라 차감하지 못한 몫(빚으로 남기지 않는다)
 * @param balanceAfter 정산 뒤 사용 가능량
 */
public record CreditSettlement(int charged, int overage, int balanceAfter) {

}
