package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.ImageProvider;
import com.chuseok22.elumserver.ai.infrastructure.client.FluxImageClient;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiTextClient;
import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageClientRouter;
import com.chuseok22.elumserver.ai.infrastructure.client.ImageGenerationClient;
import com.chuseok22.elumserver.common.infrastructure.store.InMemorySharedStateStore;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineStepImageThrottle;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.Optional;
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

/**
 * 보호자가 추가한 카드의 그림 (#368).
 *
 * <p>실제 AI 를 부르지 않는다. 그림 클라이언트만 가짜로 두고 "불렀는가"를 본다 — 그림 한 장이
 * 곧 돈이라, 부르지 않아야 할 때 부르지 않는 것이 이 클래스가 지키는 약속이다.
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepImageFillerTest {

  private static final GeneratedImage IMAGE = new GeneratedImage(new byte[]{1, 2, 3}, "png");

  private static final String SEED_KEY = FluxSeed.routineKey("profile-1", "비 오는 날 학교에 가요");

  @Mock private ImageClientRouter imageClientRouter;
  @Mock private FluxImageClient fluxImageClient;
  @Mock private GeminiTextClient geminiTextClient;
  @Mock private ImageGenerationClient imageClient;
  @Mock private RoutineImageStorage routineImageStorage;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private AiDailyBudgetGuard aiDailyBudgetGuard;

  private RoutineStepImageFiller filler;
  private final RoutineStep step = new RoutineStep();

  @BeforeEach
  void setUp() {
    // 창 제한은 가짜가 아니라 실제 메모리 저장소로 돌린다.
    // 제공자 고르기는 실제 CardImageGenerator 로 돈다. 고른 제공자가 FLUX 가 아니면(가짜 라우터는
    // null) 지금처럼 current() 로 간다.
    filler = new RoutineStepImageFiller(
      new CardImageGenerator(imageClientRouter, fluxImageClient, geminiTextClient),
      routineImageStorage, routineStepRepository, aiDailyBudgetGuard,
      new RoutineStepImageThrottle(new InMemorySharedStateStore())
    );
    lenient().when(imageClientRouter.current()).thenReturn(imageClient);
    lenient().when(imageClient.generateImage(anyString(), any())).thenReturn(IMAGE);
    lenient().when(routineImageStorage.save(anyString(), anyInt(), any())).thenReturn("images/step-1/1.png");
    lenient().when(routineStepRepository.findById(anyString())).thenReturn(Optional.of(step));
    AiCallContext.clear();
  }

  @AfterEach
  void tearDown() {
    AiCallContext.clear();
  }

  private void fill(String memberId) {
    filler.fill(memberId, "routine-1", "step-1", "현관에서 우산을 챙겨요.", CharacterType.LULU, SEED_KEY);
  }

  @Test
  @DisplayName("상한 아래면 그림을 만들어 카드에 붙인다")
  void belowBudget_generatesAndAttachesImage() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);

    fill("member-1");

    assertThat(step.getImagePath()).isEqualTo("images/step-1/1.png");
  }

  @Test
  @DisplayName("하루 비용 상한에 닿았으면 그림을 부르지 않는다 — 카드는 이미 추가됐고 기본 그림으로 남는다")
  void budgetReached_skipsImage() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(true);

    fill("member-1");

    verify(imageClient, never()).generateImage(anyString(), any());
    assertThat(step.getImagePath()).isNull();
  }

  @Test
  @DisplayName("한 회원은 창 안에서 10장까지만 그림을 만든다 — 추가·삭제를 되풀이해도 그림 호출에 끝이 있다")
  void throttle_capsImagesPerMember() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);

    for (int i = 0; i < 11; i++) {
      fill("member-1");
    }

    verify(imageClient, times(10)).generateImage(anyString(), any());
  }

  @Test
  @DisplayName("다른 회원의 그림 횟수는 서로 영향을 주지 않는다")
  void throttle_isPerMember() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);
    for (int i = 0; i < 10; i++) {
      fill("member-1");
    }

    fill("member-2");

    verify(imageClient, times(11)).generateImage(anyString(), any());
  }

  @Test
  @DisplayName("상한에 걸려 건너뛴 그림은 회원의 그림 횟수를 깎지 않는다")
  void budgetSkip_doesNotConsumeThrottle() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(true);
    for (int i = 0; i < 10; i++) {
      fill("member-1");
    }

    when(aiDailyBudgetGuard.isReached()).thenReturn(false);
    fill("member-1");

    verify(imageClient, times(1)).generateImage(anyString(), any());
  }

  @Test
  @DisplayName("커밋 뒤 다른 스레드에서 만드는 그림 호출에도 회원이 남는다 — 전에는 회원 없이 기록됐다")
  void afterCommit_imageCallCarriesMember() throws InterruptedException {
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);
    AtomicReference<String> memberSeenByImageCall = new AtomicReference<>();
    CountDownLatch called = new CountDownLatch(1);
    when(imageClient.generateImage(anyString(), any())).thenAnswer(invocation -> {
      // AiCallLogService 가 기록할 때 읽는 바로 그 자리다.
      memberSeenByImageCall.set(AiCallContext.currentMemberId());
      called.countDown();
      return IMAGE;
    });

    // 요청 스레드에는 회원 맥락이 없다(addStep 은 세우지 않는다). 물려받은 값이 아니라
    // 그림 스레드가 스스로 세워야 한다.
    TransactionSynchronizationManager.initSynchronization();
    try {
      filler.scheduleAfterCommit(
        "member-1", "routine-1", "step-1", "현관에서 우산을 챙겨요.", CharacterType.LULU, SEED_KEY);
      TransactionSynchronizationManager.getSynchronizations()
        .forEach(TransactionSynchronization::afterCommit);
    } finally {
      TransactionSynchronizationManager.clearSynchronization();
    }

    assertThat(called.await(5, TimeUnit.SECONDS)).isTrue();
    assertThat(memberSeenByImageCall.get()).isEqualTo("member-1");
  }

  @Test
  @DisplayName("그림 스레드는 끝나면 회원 맥락을 비운다 — 다음 작업에 새지 않는다")
  void fill_clearsMemberContextAfterward() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);

    fill("member-1");

    assertThat(AiCallContext.currentMemberId()).isNull();
  }

  @Test
  @DisplayName("FLUX 면 추가 카드는 영어 장면이 없어 번역해 그리고, 일과의 seed 로 그린다 (#373)")
  void flux_translatesAndUsesRoutineSeed() {
    when(aiDailyBudgetGuard.isReached()).thenReturn(false);
    when(imageClientRouter.selected()).thenReturn(ImageProvider.FLUX);
    when(fluxImageClient.available()).thenReturn(true);
    when(geminiTextClient.translateImagePrompt("현관에서 우산을 챙겨요."))
      .thenReturn("The character picks up an umbrella at the front door.");
    when(fluxImageClient.generate(any(), any(), any())).thenReturn(IMAGE);

    fill("member-1");

    verify(fluxImageClient).generate(
      "The character picks up an umbrella at the front door.", CharacterType.LULU, FluxSeed.of(SEED_KEY));
    assertThat(step.getImagePath()).isEqualTo("images/step-1/1.png");
  }
}
