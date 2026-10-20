package com.chuseok22.elumserver.member.application.service;

import com.chuseok22.elumserver.member.infrastructure.repository.MemberDailyVisitRepository;
import java.time.LocalDate;
import java.util.Map;
import java.util.UUID;
import java.util.concurrent.ConcurrentHashMap;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 회원 하루 방문 기록: 인증된 요청마다 호출 > 인스턴스 메모리로 그날 처음인지 확인 > 처음이면 1줄 저장
 * 같은 날 두 번째 요청부터 DB 접근 없음. 재기동·다른 인스턴스는 한 번 더 시도하지만 고유 제약으로 무시됨
 */
@Slf4j
@Component
public class MemberVisitRecorder {

  private final MemberDailyVisitRepository memberDailyVisitRepository;
  /// 방문 저장 전용 새 트랜잭션 (Postgres 는 실패한 문장이 바깥 트랜잭션까지 망가뜨림)
  private final TransactionTemplate requiresNewTransaction;
  /// 오늘 기록을 마친 회원 (날짜가 바뀌면 비움)
  private final Map<String, Boolean> recordedMemberIds = new ConcurrentHashMap<>();
  private volatile LocalDate recordedDate;

  public MemberVisitRecorder(
    MemberDailyVisitRepository memberDailyVisitRepository, PlatformTransactionManager transactionManager
  ) {
    this.memberDailyVisitRepository = memberDailyVisitRepository;
    this.requiresNewTransaction = new TransactionTemplate(transactionManager);
    this.requiresNewTransaction.setPropagationBehavior(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
  }

  /** 그날 첫 요청이면 방문 저장 (실패해도 요청은 통과, 다음 요청에서 다시 시도) */
  public void recordFirstVisitOfDay(String memberId, LocalDate today) {
    resetIfDateChanged(today);
    if (memberId == null || recordedMemberIds.putIfAbsent(memberId, Boolean.TRUE) != null) {
      return;
    }
    try {
      requiresNewTransaction.executeWithoutResult(status ->
        memberDailyVisitRepository.insertIfAbsent(UUID.randomUUID().toString(), memberId, today));
    } catch (Exception e) {
      recordedMemberIds.remove(memberId);
      log.warn("[member visit] save failed, request unaffected : memberId={}", memberId, e);
    }
  }

  private void resetIfDateChanged(LocalDate today) {
    if (today.equals(recordedDate)) {
      return;
    }
    synchronized (this) {
      if (!today.equals(recordedDate)) {
        recordedMemberIds.clear();
        recordedDate = today;
      }
    }
  }
}
