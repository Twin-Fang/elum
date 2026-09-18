package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.infrastructure.client.GeminiImageClient;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;
import org.springframework.transaction.annotation.Transactional;
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
 * <h2>지키는 세 가지</h2>
 *
 * <ul>
 *   <li><b>응답을 붙잡지 않는다</b> — 별도 스레드에서 돈다. Gemini 호출은 몇 초 걸린다.
 *       클라는 {@code imagePath}가 빌 동안 "그림 만드는 중"을 띄운다 (#198 §9).</li>
 *   <li><b>커밋 뒤에 시작한다</b> — 트랜잭션이 롤백되면 카드가 없는데 그림 파일만 남는다.</li>
 *   <li><b>실패해도 삼킨다</b> — 카드 추가는 이미 성공했고 받아 줄 응답이 없다.
 *       {@code imagePath}를 {@code null}로 두면 클라가 기본 그림으로 채운다
 *       (서비스 원칙 6 — 어떤 실패에서도 끝까지 진행된다).</li>
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

  private final GeminiImageClient geminiImageClient;
  private final RoutineImageStorage routineImageStorage;
  private final RoutineStepRepository routineStepRepository;

  /// 가상 스레드라 몇 초짜리 HTTP 대기에 OS 스레드를 묶어 두지 않는다.
  private final ExecutorService executor = Executors.newVirtualThreadPerTaskExecutor();

  /**
   * 지금 트랜잭션이 커밋되면 그림 생성을 시작하도록 예약한다.
   *
   * <p>트랜잭션 밖에서 불리거나 설명이 비어 있으면 아무 일도 하지 않는다 —
   * 빈 프롬프트로 부르면 돈만 쓰고 엉뚱한 그림이 나온다.
   */
  public void scheduleAfterCommit(
    String routineId, String stepId, String description, CharacterType characterType
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
        executor.execute(() -> fill(routineId, stepId, description, characterType));
      }
    });
  }

  /** 그림을 만들어 저장하고 경로를 채운다. 어떤 실패도 밖으로 내지 않는다. */
  void fill(String routineId, String stepId, String description, CharacterType characterType) {
    try {
      GeneratedImage image =
        geminiImageClient.generateImage(description, characterType);
      if (image == null) {
        log.warn("추가 카드 이미지가 비어 돌아왔다: routineId={}, stepId={}", routineId, stepId);
        return;
      }
      // 추가 카드는 stepId를 batchId로 써서 자기 폴더에 담는다.
      // 일과 생성 때의 batchId에 섞으면 그 배치를 되돌릴 때(deleteBatch)
      // 나중에 추가한 그림까지 함께 지워진다.
      String imagePath = routineImageStorage.save(stepId, 1, image);
      persistImagePath(stepId, imagePath);
      log.info("추가 카드 이미지 완료: routineId={}, stepId={}", routineId, stepId);
    } catch (Exception e) {
      log.warn("추가 카드 이미지 실패 — 기본 그림으로 둔다: routineId={}, stepId={}",
        routineId, stepId, e);
    }
  }

  /**
   * 이미지 경로만 따로 커밋한다.
   *
   * <p>원래 트랜잭션은 이미 끝났으므로 새로 연다. 카드가 그새 지워졌으면 아무 일도 하지
   * 않는다 — 보호자가 추가하자마자 지울 수 있다.
   */
  @Transactional
  public void persistImagePath(String stepId, String imagePath) {
    routineStepRepository.findById(stepId).ifPresent(step -> step.setImagePath(imagePath));
  }
}
