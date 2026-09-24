package com.chuseok22.elumserver.member.infrastructure.config;

import static org.assertj.core.api.Assertions.assertThatCode;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class GuardianshipBackfillInitializerTest {

  @Mock
  private ProfileGuardianRepository profileGuardianRepository;

  @Mock
  private RoutineRepository routineRepository;

  @InjectMocks
  private GuardianshipBackfillInitializer initializer;

  @Test
  @DisplayName("E38 옛 서버로 되돌려 있던 동안 생긴 관계·만든 사람 빈칸을 부팅할 때 메운다")
  void e38_backfillsGapsLeftByOldServer() {
    when(profileGuardianRepository.backfillFromProfileOwner()).thenReturn(1);
    when(routineRepository.backfillCreatorFromProfileOwner()).thenReturn(2);

    initializer.run(null);

    verify(profileGuardianRepository).backfillFromProfileOwner();
    verify(routineRepository).backfillCreatorFromProfileOwner();
  }

  @Test
  @DisplayName("메우다 실패해도 서버는 뜬다 — 부팅이 죽으면 무중단 배포가 없어 서비스가 멈춘다")
  void backfillFailure_doesNotStopBoot() {
    when(profileGuardianRepository.backfillFromProfileOwner()).thenThrow(new RuntimeException("DB 끊김"));
    when(routineRepository.backfillCreatorFromProfileOwner()).thenReturn(0);

    assertThatCode(() -> initializer.run(null)).doesNotThrowAnyException();
    // 한쪽이 실패해도 다른 쪽은 돈다
    verify(routineRepository).backfillCreatorFromProfileOwner();
  }
}
