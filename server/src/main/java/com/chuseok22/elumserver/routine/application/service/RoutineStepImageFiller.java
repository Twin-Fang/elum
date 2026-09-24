package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineStepImageThrottle;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;

/**
 * 보호자가 직접 추가한 카드의 그림을 <b>나중에</b> 채운다 (이슈 #199).
 *
 * <p>추가한 카드에 그림이 없으면 그 카드는 죽는다. 이룸이 화면은 글자 없이도 뜻이 통해야
 * 하는데, 그림이 없으면 글을 못 읽는 사용자에게는 빈 카드다 (서비스 원칙 3 · 전문가 자문).
 *
 * <h2>왜 별도 빈인가</h2>
 *
 * {@code RoutineService} 안에 두면 같은 빈 안에서 자기 메서드를 부르게 되어
 * <b>{@code @Transactional}이 프록시를 타지 않는다.</b> 커밋 뒤 다른 스레드에서 도는 코드라
 * 트랜잭션이 하나도 열리지 않고, 엔티티를 고쳐도 아무것도 저장되지 않는다.
 *
 * <p>이 클래스 안에서도 자기 메서드의 {@code @Transactional} 에 기대지 않는다 — 경로 저장은 리포지토리의
 * 한 줄 UPDATE 가 자기 트랜잭션으로 한다. 예전의 {@code persistImagePath} 는 {@code fill} 이 자기 호출로
 * 불러 트랜잭션이 열리지 않았고, 분리된 엔티티를 고쳐 경로가 저장되지 않았다.
 *
 * <h2>지키는 세 가지</h2>
 *
 * <ul>
 *   <li><b>응답을 붙잡지 않는다</b> — 별도 스레드에서 돈다. Gemini 호출은 몇 초 걸린다.
 *       클라는 {@code imagePath}가 빌 동안 "그림 만드는 중"을 띄운다 (#198 §9).</li>
 *   <li><b>커밋 뒤에 시작한다</b> — 트랜잭션이 롤백되면 카드가 없는데 그림 파일만 남는다.</li>
 *   <li><b>실패해도 삼킨다</b> — 카드 추가는 이미 성공했고 받아 줄 응답이 없다.
 *       {@code imagePath}를 {@code null}로 두면 클라가 기본 그림으로 채운다
 *       (서비스 원칙 6 — 어떤 실패에서도 끝까지 진행된다).</li>
 *   <li><b>비용 장치에 걸리면 그림만 건너뛴다</b> — 하루 비용 상한과 회원별 그림 횟수 (#368).
 *       카드 추가를 거절하지 않는다. 막으면 보호자가 일과를 못 고친다.</li>
 * </ul>
 *
 * <h2>카드당 한 번만 부른다</h2>
 *
 * 자동 재시도를 걸지 않는다. 일과 생성 경로({@code RoutineAiPipeline})는 1회 재시도하지만
 * 그쪽은 사용자가 화면 앞에서 기다리는 중이라 성공률이 곧 체감 품질이다. 여기는 카드가
 * 이미 화면에 있고, 실패는 기본 그림으로 덮인다. 재시도는 비용만 배로 든다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class RoutineStepImageFiller {

  private final CardImageGenerator cardImageGenerator;
  private final RoutineImageStorage routineImageStorage;
  private final RoutineStepRepository routineStepRepository;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;
  private final RoutineStepImageThrottle routineStepImageThrottle;

  /// 가상 스레드라 몇 초짜리 HTTP 대기에 OS 스레드를 묶어 두지 않는다.
  private final ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

  /**
   * 지금 트랜잭션이 커밋되면 그림 생성을 시작하도록 예약한다.
   *
   * <p>트랜잭션 밖에서 불리거나 설명이 비어 있으면 아무 일도 하지 않는다 —
   * 빈 프롬프트로 부르면 돈만 쓰고 엉뚱한 그림이 나온다.
   */
  /// @param seedKey {@code FluxSeed.routineKey} — 일과를 만들 때와 같은 seed 로 그려 같은 캐릭터가 나온다 (#373)
  public void scheduleAfterCommit(
    String memberId, String routineId, String stepId, String description, CharacterType characterType,
    String seedKey
  ) {
    if (description == null || description.isBlank()) {
      return;
    }
    if (!TransactionSynchronizationManager.isSynchronizationActive()) {
      return;
    }
    TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
      @Override
      public void afterCommit() {
        executor.execute(() -> fill(memberId, routineId, stepId, description, characterType, seedKey));
      }
    });
  }

  /**
   * 그림을 만들어 저장하고 경로를 채운다. 어떤 실패도 밖으로 내지 않는다.
   *
   * <p>돈을 쓰기 직전에 두 관문을 본다 (#368). 걸리면 그림만 건너뛰고 카드는 그대로 둔다 —
   * 클라가 기본 그림으로 채운다. 그림이 실패했을 때와 같은 결과다.
   * <ol>
   *   <li>서비스 전체 하루 비용 상한</li>
   *   <li>회원별 추가 그림 횟수 — 추가·삭제를 되풀이해도 끝이 있게</li>
   * </ol>
   * 상한을 먼저 본다. 상한 때문에 건너뛴 그림이 회원의 횟수를 깎으면 안 된다.
   */
  void fill(
    String memberId, String routineId, String stepId, String description, CharacterType characterType,
    String seedKey
  ) {
    // 이 스레드는 요청 스레드가 아니라 회원 맥락이 없다(addStep 은 세우지 않는다). 여기서 세워야
    // 그림 호출 기록에 회원이 남는다 — 전에는 회원 없이 남아 계정별로는 볼 수 없었다 (#368).
    AiCallContext.setMemberId(memberId);
    try {
      // 그새 카드(또는 일과·이룸이)가 지워졌으면 그림을 만들지 않는다 — 한 장 한 장이 돈이다 (다중 보호자 E18).
      // 비용 관문보다 먼저 본다. 없는 카드 때문에 회원의 그림 횟수가 깎이면 안 된다.
      if (!routineStepRepository.existsById(stepId)) {
        log.warn("그림을 채울 카드가 없어 그만둔다: routineId={}, stepId={}", routineId, stepId);
        return;
      }
      if (aiDailyBudgetGuard.isReached()) {
        log.warn("AI 하루 비용 상한 — 추가 카드 그림을 건너뛰고 기본 그림으로 둔다: routineId={}, stepId={}",
          routineId, stepId);
        return;
      }
      if (!routineStepImageThrottle.tryAcquire(memberId)) {
        log.warn("추가 카드 그림이 너무 잦다 — 이번 그림은 건너뛴다: memberId={}, routineId={}, stepId={}",
          memberId, routineId, stepId);
        return;
      }
      // 직접 추가한 카드엔 영어 장면이 없다 — FLUX 면 CardImageGenerator 가 번역한다 (#373).
      GeneratedImage image = cardImageGenerator.generate(
        new CardImageGenerator.CardImageRequest(description, null, characterType, seedKey));
      if (image == null) {
        log.warn("추가 카드 이미지가 비어 돌아왔다: routineId={}, stepId={}", routineId, stepId);
        return;
      }
      // 추가 카드는 stepId를 batchId로 써서 자기 폴더에 담는다.
      // 일과 생성 때의 batchId에 섞으면 그 배치를 되돌릴 때(deleteBatch)
      // 나중에 추가한 그림까지 함께 지워진다.
      String imagePath = routineImageStorage.save(stepId, 1, image);
      if (routineStepRepository.updateImagePath(stepId, imagePath) == 0) {
        // 그림을 만드는 사이 지워졌다 (E18 — 나가기·일과 삭제·카드 삭제). 아무도 가리키지 않는 파일을
        // 남기지 않는다. 다시 시도하지 않는다.
        log.warn("그림을 만드는 사이 카드가 지워져 그림을 버린다: routineId={}, stepId={}", routineId, stepId);
        routineImageStorage.deleteBatch(stepId);
        return;
      }
      log.info("추가 카드 이미지 완료: routineId={}, stepId={}", routineId, stepId);
    } catch (Exception e) {
      log.warn("추가 카드 이미지 실패 — 기본 그림으로 둔다: routineId={}, stepId={}",
        routineId, stepId, e);
    } finally {
      AiCallContext.clear();
    }
  }
}
