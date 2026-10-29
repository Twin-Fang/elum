package com.chuseok22.elumserver.member.application.service;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.infrastructure.repository.MemberDailyVisitRepository;
import java.time.LocalDate;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.SimpleTransactionStatus;

/**
 * 방문 기록: 회원당 하루 1번만 DB 에 간다
 * 깨지면 인증된 요청마다 insert 가 나가 API 전체가 느려진다
 */
class MemberVisitRecorderTest {

  private static final LocalDate TODAY = LocalDate.of(2026, 10, 20);

  private MemberDailyVisitRepository repository;
  private MemberVisitRecorder recorder;

  @BeforeEach
  void setUp() {
    repository = mock(MemberDailyVisitRepository.class);
    PlatformTransactionManager transactionManager = mock(PlatformTransactionManager.class);
    when(transactionManager.getTransaction(any())).thenReturn(new SimpleTransactionStatus());
    recorder = new MemberVisitRecorder(repository, transactionManager);
  }

  @Test
  @DisplayName("같은 날 여러 요청은 1번, 다음 날 첫 요청은 다시 1번 저장")
  void recordsOncePerMemberPerDay() {
    recorder.recordFirstVisitOfDay("m1", TODAY);
    recorder.recordFirstVisitOfDay("m1", TODAY);
    recorder.recordFirstVisitOfDay("m1", TODAY.plusDays(1));

    verify(repository, times(1)).insertIfAbsent(any(), eq("m1"), eq(TODAY));
    verify(repository, times(1)).insertIfAbsent(any(), eq("m1"), eq(TODAY.plusDays(1)));
  }

  @Test
  @DisplayName("저장이 실패하면 다음 요청에서 다시 시도한다 (요청은 막지 않음)")
  void retriesAfterFailure() {
    when(repository.insertIfAbsent(any(), eq("m1"), eq(TODAY)))
      .thenThrow(new IllegalStateException("db down"))
      .thenReturn(1);

    recorder.recordFirstVisitOfDay("m1", TODAY);
    recorder.recordFirstVisitOfDay("m1", TODAY);

    verify(repository, times(2)).insertIfAbsent(any(), eq("m1"), eq(TODAY));
  }
}
