package com.chuseok22.elumserver.member.infrastructure.scheduler;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import ch.qos.logback.classic.Level;
import ch.qos.logback.classic.Logger;
import ch.qos.logback.classic.spi.ILoggingEvent;
import ch.qos.logback.core.read.ListAppender;
import com.chuseok22.elumserver.member.application.service.WithdrawnMemberService;
import java.io.IOException;
import java.lang.reflect.Method;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.slf4j.LoggerFactory;
import org.springframework.scheduling.annotation.Scheduled;

@ExtendWith(MockitoExtension.class)
class WithdrawnMemberPurgeSchedulerTest {

  @Mock
  private WithdrawnMemberService withdrawnMemberService;

  @InjectMocks
  private WithdrawnMemberPurgeScheduler scheduler;

  private final ListAppender<ILoggingEvent> logs = new ListAppender<>();
  private final Logger logger = (Logger) LoggerFactory.getLogger(WithdrawnMemberPurgeScheduler.class);

  @BeforeEach
  void attachLogs() {
    logs.start();
    logger.addAppender(logs);
  }

  @AfterEach
  void detachLogs() {
    logger.detachAppender(logs);
  }

  @Test
  @DisplayName("보관 기간이 지난 탈퇴 계정을 하나씩 완전 삭제한다")
  void purgeExpired_purgesEachExpiredMember() {
    when(withdrawnMemberService.findExpiredIds()).thenReturn(List.of("m1", "m2"));

    WithdrawnMemberPurgeScheduler.PurgeResult result = scheduler.purgeExpired();

    verify(withdrawnMemberService).purge("m1");
    verify(withdrawnMemberService).purge("m2");
    assertThat(result.purged()).isEqualTo(2);
    assertThat(result.failed()).isZero();
  }

  @Test
  @DisplayName("S7 한 계정을 지우다 실패해도 나머지는 지우고, 실패를 회원 ID 와 함께 로그로 남긴다")
  void purgeExpired_oneFailure_continuesAndLogs() {
    when(withdrawnMemberService.findExpiredIds()).thenReturn(List.of("m1", "m2", "m3"));
    // 엄격한 스텁은 다른 인자(m1·m3)로 불리면 그 자체로 예외를 던진다 — 스케줄러가 그것까지 실패로 센다.
    lenient().doThrow(new IllegalStateException("외래키 위반")).when(withdrawnMemberService).purge("m2");

    WithdrawnMemberPurgeScheduler.PurgeResult result = scheduler.purgeExpired();

    // 한 줄 실패로 전체가 멈추면 나머지 계정이 보관 기간을 넘겨 남는다.
    verify(withdrawnMemberService).purge("m1");
    verify(withdrawnMemberService).purge("m3");
    assertThat(result.purged()).isEqualTo(2);
    assertThat(result.failed()).isEqualTo(1);
    // 조용히 삼키면 약속한 기간을 넘겨 남아 있어도 아무도 모른다.
    assertThat(logs.list)
      .anySatisfy(event -> {
        assertThat(event.getLevel()).isEqualTo(Level.ERROR);
        assertThat(event.getFormattedMessage()).contains("m2");
        assertThat(event.getThrowableProxy()).isNotNull();
      });
  }

  @Test
  @DisplayName("S7 실패한 계정은 다음 정리 때 다시 시도한다 — 실패를 기억해 건너뛰지 않는다")
  void purgeExpired_failedMember_isRetriedNextRun() {
    // 지우지 못한 행은 그대로 남아 있으므로 다음 조회에 다시 나온다.
    when(withdrawnMemberService.findExpiredIds()).thenReturn(List.of("m2"));
    doThrow(new IllegalStateException("일시 장애")).doNothing()
      .when(withdrawnMemberService).purge("m2");

    WithdrawnMemberPurgeScheduler.PurgeResult first = scheduler.purgeExpired();
    WithdrawnMemberPurgeScheduler.PurgeResult second = scheduler.purgeExpired();

    verify(withdrawnMemberService, times(2)).purge("m2");
    assertThat(first.failed()).isEqualTo(1);
    assertThat(second.purged()).isEqualTo(1);
  }

  @Test
  @DisplayName("S7 대상 조회부터 실패해도 예외를 밖으로 내지 않고 로그를 남긴다 — 다음 정리 때 다시 돈다")
  void purgeExpired_lookupFailure_logsAndReturns() {
    when(withdrawnMemberService.findExpiredIds()).thenThrow(new IllegalStateException("DB 연결 실패"));

    WithdrawnMemberPurgeScheduler.PurgeResult result = scheduler.purgeExpired();

    assertThat(result.purged()).isZero();
    assertThat(logs.list).anySatisfy(event -> assertThat(event.getLevel()).isEqualTo(Level.ERROR));
  }

  @Test
  @DisplayName("정리는 매일 한국 시각으로 정해진 때에 돈다")
  void purgeExpired_isScheduledDailyInSeoul() throws NoSuchMethodException {
    Method method = WithdrawnMemberPurgeScheduler.class.getMethod("run");
    Scheduled scheduled = method.getAnnotation(Scheduled.class);

    assertThat(scheduled).isNotNull();
    assertThat(scheduled.cron()).isNotBlank();
    assertThat(scheduled.zone()).isEqualTo("Asia/Seoul");
  }

  @Test
  @DisplayName("스케줄링이 켜져 있다 — 꺼져 있으면 정리가 한 번도 돌지 않아 보관 기간이 끝없이 늘어난다")
  void schedulingIsEnabled() throws IOException {
    boolean enabled;
    try (Stream<Path> files = Files.walk(Path.of("src/main/java"))) {
      enabled = files.filter(p -> p.toString().endsWith(".java"))
        .anyMatch(p -> {
          try {
            return Files.readString(p).contains("@EnableScheduling");
          } catch (IOException e) {
            throw new IllegalStateException(e);
          }
        });
    }

    // @Scheduled 만 붙이고 @EnableScheduling 이 없으면 컴파일도 테스트도 통과한 채 아무 일도 안 일어난다.
    assertThat(enabled).isTrue();
  }
}
