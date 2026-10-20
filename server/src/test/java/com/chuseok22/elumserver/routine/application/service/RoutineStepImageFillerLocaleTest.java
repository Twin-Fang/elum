package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.common.infrastructure.store.InMemorySharedStateStore;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineStepImageThrottle;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;
import java.util.concurrent.atomic.AtomicReference;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/** 커밋 뒤 다른 스레드에서 그리는 추가 카드 그림이 일과 언어를 잃지 않는다. */
@ExtendWith(MockitoExtension.class)
class RoutineStepImageFillerLocaleTest {

  private static final GeneratedImage IMAGE = new GeneratedImage(new byte[]{1, 2, 3}, "png");
  private static final String SEED_KEY = FluxSeed.routineKey("profile-1", "Ir al colegio");

  @Mock private ImageClientRouter imageClientRouter;
  @Mock private FluxImageClient fluxImageClient;
  @Mock private GeminiTextClient geminiTextClient;
  @Mock private ImageGenerationClient imageClient;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;
  @Mock private CreditReservationService creditReservationService;

  private RoutineStepImageFiller filler;

  @BeforeEach
  void setUp() {
    filler = new RoutineStepImageFiller(
      new CardImageGenerator(imageClientRouter, fluxImageClient, geminiTextClient),
      routineImageStorage, routineStepRepository, aiDailyBudgetGuard,
      new RoutineStepImageThrottle(new InMemorySharedStateStore()), creditReservationService);
    lenient().when(imageClientRouter.current()).thenReturn(imageClient);
    lenient().when(imageClient.generateCardImage(any(), any())).thenReturn(IMAGE);
    lenient().when(routineImageStorage.save(anyString(), anyInt(), any())).thenReturn("images/step-1/1.png");
    lenient().when(routineStepRepository.existsById(anyString())).thenReturn(true);
    lenient().when(routineStepRepository.updateImagePath(anyString(), anyString())).thenReturn(1);
    AiCallContext.clear();
  }

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  @Test
  @DisplayName("예약 때 세워 둔 일과 언어가 커밋 뒤 그림 스레드까지 간다 — 그 사이 요청 스레드의 언어가 비워져도")
  void afterCommit_keepsTheLocaleCapturedAtScheduleTime() throws InterruptedException {
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);
    AtomicReference<AppLocale> seen = new AtomicReference<>();
    CountDownLatch called = new CountDownLatch(1);
    when(imageClient.generateCardImage(any(), any())).thenAnswer(invocation -> {
      seen.set(AiCallContext.currentContentLocale());
      called.countDown();
      return IMAGE;
    });

    AiCallContext.setContentLocale(AppLocale.ES);
    TransactionSynchronizationManager.initSynchronization();
    try {
      filler.scheduleAfterCommit(
        "member-1", "routine-1", "step-1", "Saca el paraguas.", CharacterType.LULU, SEED_KEY, null, ImageStyle.CARTOON);
      // addStep 이 끝나면 요청 스레드의 언어가 비워진다. 커밋 콜백은 그 뒤에 돈다.
      AiCallContext.setContentLocale(null);
      TransactionSynchronizationManager.getSynchronizations().forEach(TransactionSynchronization::afterCommit);
    } finally {
      TransactionSynchronizationManager.clearSynchronization();
    }

    assertThat(called.await(5, TimeUnit.SECONDS)).isTrue();
    assertThat(seen.get()).isEqualTo(AppLocale.ES);
  }

  @Test
  @DisplayName("그림 스레드는 끝나면 언어도 비운다 — 다음 작업에 새지 않는다")
  void fill_clearsLocaleAfterward() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);
    AiCallContext.setContentLocale(AppLocale.JA);

    filler.fill("member-1", "routine-1", "step-1", "傘を持ちます。", CharacterType.LULU, SEED_KEY, null, ImageStyle.CARTOON);

    assertThat(AiCallContext.currentContentLocale()).isEqualTo(AppLocale.KO);
  }
}
