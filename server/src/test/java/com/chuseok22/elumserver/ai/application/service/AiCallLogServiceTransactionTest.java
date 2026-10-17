package com.chuseok22.elumserver.ai.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallType;
import com.chuseok22.elumserver.ai.infrastructure.repository.AiCallLogRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.UnexpectedRollbackException;
import org.springframework.transaction.support.AbstractPlatformTransactionManager;
import org.springframework.transaction.support.DefaultTransactionStatus;

/**
 * AI 호출 기록 트랜잭션 경계: 저장·커밋 실패가 본 AI 호출로 새지 않음
 * 실제 AbstractPlatformTransactionManager 흐름(시작 > 커밋/롤백) 위에서 검증
 */
class AiCallLogServiceTransactionTest {

  private final AiCallLogRepository aiCallLogRepository = mock(AiCallLogRepository.class);
  private final SystemConfigService systemConfigService = mock(SystemConfigService.class);

  @Test
  @DisplayName("저장이 예외를 던지면 기록 트랜잭션만 롤백하고 호출자에게 예외를 넘기지 않는다")
  void recordSuccess_repositoryThrows_rollsBackWithoutPropagating() {
    RecordingTransactionManager transactionManager = new RecordingTransactionManager(false);
    AiCallLogService aiCallLogService = new AiCallLogService(aiCallLogRepository, systemConfigService, transactionManager);
    when(aiCallLogRepository.save(any())).thenThrow(new IllegalStateException("DB down"));

    assertThatCode(() -> aiCallLogService.recordSuccess(AiCallType.LOCAL_LLM_DLP, "exaone", 100, null))
      .doesNotThrowAnyException();
    assertThat(transactionManager.rollbackCount).isEqualTo(1);
    assertThat(transactionManager.commitCount).isZero();
  }

  @Test
  @DisplayName("커밋이 UnexpectedRollbackException 으로 실패해도 기록 메서드는 예외를 넘기지 않는다")
  void recordFailure_commitFails_doesNotPropagate() {
    RecordingTransactionManager transactionManager = new RecordingTransactionManager(true);
    AiCallLogService aiCallLogService = new AiCallLogService(aiCallLogRepository, systemConfigService, transactionManager);

    assertThatCode(() -> aiCallLogService.recordFailure(AiCallType.GEMINI_TEXT_CREATE, "gemini", 10, "timeout"))
      .doesNotThrowAnyException();
    assertThat(transactionManager.commitCount).isEqualTo(1);
  }

  @Test
  @DisplayName("기록은 항상 새 트랜잭션(REQUIRES_NEW)으로 연다 — 호출자 트랜잭션 롤백과 무관하게 남는다")
  void record_opensRequiresNewTransaction() {
    RecordingTransactionManager transactionManager = new RecordingTransactionManager(false);
    AiCallLogService aiCallLogService = new AiCallLogService(aiCallLogRepository, systemConfigService, transactionManager);

    aiCallLogService.recordFailure(AiCallType.GEMINI_TEXT_CREATE, "gemini", 10, "timeout");

    assertThat(transactionManager.lastPropagationBehavior).isEqualTo(TransactionDefinition.PROPAGATION_REQUIRES_NEW);
    assertThat(transactionManager.commitCount).isEqualTo(1);
  }

  /// 시작·커밋·롤백 횟수 기록용 트랜잭션 매니저 (shouldFailCommit: 커밋 시 롤백 표시 충돌 재현)
  private static final class RecordingTransactionManager extends AbstractPlatformTransactionManager {

    private final boolean shouldFailCommit;
    private int commitCount;
    private int rollbackCount;
    private int lastPropagationBehavior = -1;

    private RecordingTransactionManager(boolean shouldFailCommit) {
      this.shouldFailCommit = shouldFailCommit;
    }

    @Override
    protected Object doGetTransaction() {
      return new Object();
    }

    @Override
    protected void doBegin(Object transaction, TransactionDefinition definition) {
      lastPropagationBehavior = definition.getPropagationBehavior();
    }

    @Override
    protected void doCommit(DefaultTransactionStatus status) {
      commitCount++;
      if (shouldFailCommit) {
        throw new UnexpectedRollbackException("Transaction silently rolled back because it has been marked as rollback-only");
      }
    }

    @Override
    protected void doRollback(DefaultTransactionStatus status) {
      rollbackCount++;
    }
  }
}
