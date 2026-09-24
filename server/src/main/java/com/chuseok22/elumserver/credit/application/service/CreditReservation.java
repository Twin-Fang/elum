package com.chuseok22.elumserver.credit.application.service;

/**
 * 예약 결과 (#407).
 *
 * @param jobId     작업 id. DISABLED 면 null — 정산·반환을 부르지 않는다
 * @param routineId ALREADY_SETTLED 일 때 저장된 일과 id. 호출자는 AI 를 다시 부르지 않고 이 일과를 돌려준다
 */
public record CreditReservation(String jobId, Outcome outcome, String routineId) {

  public enum Outcome {
    /// 예약했다. 성공하면 settle, 실패하면 release 를 부른다.
    RESERVED,
    /// 같은 요청 키가 이미 끝났다(멱등).
    ALREADY_SETTLED,
    /// 크레딧 정책이 꺼져 있다. 기존 횟수 한도로 돈다.
    DISABLED,
  }

  public static CreditReservation disabled() {
    return new CreditReservation(null, Outcome.DISABLED, null);
  }

  public static CreditReservation reserved(String jobId) {
    return new CreditReservation(jobId, Outcome.RESERVED, null);
  }

  public static CreditReservation alreadySettled(String jobId, String routineId) {
    return new CreditReservation(jobId, Outcome.ALREADY_SETTLED, routineId);
  }

  public boolean isReserved() {
    return outcome == Outcome.RESERVED;
  }
}
