package com.chuseok22.elumserver.credit.application.service;

import com.chuseok22.elumserver.credit.core.CreditPeriod;

/**
 * 한 시점의 크레딧 잔액 (#407).
 *
 * @param available   사용 가능 = Σ 유효 묶음 remaining − Σ 진행 중 예약. 0 아래로 내려가지 않는다
 * @param weeklyGrant 이번 주 주간 지급량(amount). 아직 지급 전이면 0
 * @param bonus       주간이 아닌 유효 묶음의 남은 양 합
 * @param used        이번 주기 실제 차감 합(CONSUME)
 * @param reserved    진행 중 예약 합
 * @param period      이번 주기
 */
public record CreditBalance(int available, int weeklyGrant, int bonus, int used, int reserved, CreditPeriod period) {

}
