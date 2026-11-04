package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.application.service.CardImageGenerator;
import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.ai.core.GeneratedImage;
import com.chuseok22.elumserver.ai.core.NicknamePlaceholder;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.ImageStyle;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineStepImageThrottle;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 카드 그림 다시 그리기: 대상 확인 > 하루 비용 상한 > 크레딧 예약(IMAGE_REGENERATE) > 횟수 제한 > 그림 생성 > 새 열쇠 저장 > 카드 교체·정산 > 옛 그림 정리
 * 응답을 기다리는 동기 호출 (앱이 진행 표시 후 새 그림·실패 코드를 바로 받음). 실패하면 예약 반환·새 파일 삭제, 카드 그림은 그대로
 *
 * <p>단가는 예약이 정한다 — 무료 다시 그리기 권한(Pro)이 있고 하루 한도 안이면 0, 아니면 정책 단가.
 * 그림 제공자·품질은 카드 그림과 같은 {@link CardImageGenerator} 를 탄다 (고품질은 회원 권한일 때만, 호출 문맥의 회원으로 판정).
 */
@Slf4j
@Service
public class RoutineStepImageRegenerateService {

  /// 크레딧 작업 멱등 키 앞부분 (요청마다 새 작업: image-regenerate:{UUID})
  static final String REQUEST_KEY_PREFIX = "image-regenerate:";

  private final RoutineRepository routineRepository;
  private final RoutineStepRepository routineStepRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final CardImageGenerator cardImageGenerator;
  private final RoutineImageStorage routineImageStorage;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;
  private final RoutineStepImageThrottle routineStepImageThrottle;
  private final CreditReservationService creditReservationService;
  /// 대상 읽기 · 카드 교체+정산을 각각 짧은 트랜잭션으로 (그림 생성 수 초 동안 DB 연결을 잡지 않음)
  private final TransactionTemplate transaction;

  public RoutineStepImageRegenerateService(
    RoutineRepository routineRepository, RoutineStepRepository routineStepRepository,
    ProfileAccessGuard profileAccessGuard, CardImageGenerator cardImageGenerator,
    RoutineImageStorage routineImageStorage, AiDailyBudgetGuard aiDailyBudgetGuard,
    RoutineStepImageThrottle routineStepImageThrottle, CreditReservationService creditReservationService,
    PlatformTransactionManager transactionManager
  ) {
    this.routineRepository = routineRepository;
    this.routineStepRepository = routineStepRepository;
    this.profileAccessGuard = profileAccessGuard;
    this.cardImageGenerator = cardImageGenerator;
    this.routineImageStorage = routineImageStorage;
    this.aiDailyBudgetGuard = aiDailyBudgetGuard;
    this.routineStepImageThrottle = routineStepImageThrottle;
    this.creditReservationService = creditReservationService;
    this.transaction = new TransactionTemplate(transactionManager);
  }

  /**
   * 카드 한 장의 AI 그림을 새로 그려 바꾼다
   *
   * @throws CustomException ROUTINE_NOT_FOUND · ROUTINE_STEP_NOT_FOUND · 권한 코드 · ROUTINE_STEP_IMAGE_NOT_REGENERATABLE ·
   *                         AI_DAILY_BUDGET_EXCEEDED · AI_CREDIT_* · ROUTINE_REQUEST_TOO_FREQUENT · ROUTINE_STEP_IMAGE_REGENERATE_FAILED
   */
  public RoutineStepResponse regenerate(Caller caller, String routineId, String stepId) {
    RegenerateTarget target = readTarget(caller, routineId, stepId);
    aiDailyBudgetGuard.guard();
    String creditJobId = reserveCredit(caller.memberId());
    // 그림을 붙이고 정산했으면 null. 그 밖의 모든 출구는 finally 에서 이 까닭으로 반환 (성공·실패 공통)
    String releaseReason = "다시 그리기 중단";
    String newKey = null;
    try {
      requireNotTooFrequent(caller.memberId(), stepId);
      GeneratedImage image = generate(caller.memberId(), creditJobId, target);
      newKey = saveImage(stepId, image);
      RoutineStepResponse response = replaceAndSettle(target, newKey, creditJobId);
      releaseReason = null;
      deleteOldIfUnreferenced(target.oldImagePath(), stepId);
      log.info("[routine image regenerate] done : routineId={}, stepId={}", routineId, stepId);
      return response;
    } catch (CustomException e) {
      releaseReason = "다시 그리기 실패: " + e.getErrorCode().name();
      throw e;
    } catch (RuntimeException e) {
      log.warn("[routine image regenerate] failed : routineId={}, stepId={}", routineId, stepId, e);
      releaseReason = "다시 그리기 실패: " + e.getClass().getSimpleName();
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_REGENERATE_FAILED);
    } finally {
      AiCallContext.clear();
      if (releaseReason != null) {
        // 카드에 붙지 않은 새 그림은 남기지 않음
        if (newKey != null) {
          routineImageStorage.delete(newKey);
        }
        releaseCredit(creditJobId, releaseReason);
      }
    }
  }

  /// 대상 확인 (권한 EDIT, 카드 있음, AI 그림 카드, 설명 있음, 직접 사진 방식 아님) > 그림에 필요한 값만 꺼냄
  private RegenerateTarget readTarget(Caller caller, String routineId, String stepId) {
    return transaction.execute(status -> {
      Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, RoutineAction.EDIT);
      RoutineStep step = routine.getSteps().stream()
        .filter(candidate -> candidate.getId().equals(stepId))
        .findFirst()
        .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
      ImageStyle imageStyle = routine.getProfile().getImageStyle();
      if (!isRegeneratable(step, imageStyle)) {
        log.info("[routine image regenerate] rejected 409 : not an AI picture card, stepId={}", stepId);
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
      }
      String nickname = routine.getProfile().getNickname();
      AppLocale language = routine.getLanguage() == null ? AppLocale.KO : routine.getLanguage();
      // 그림 AI 로 나가는 글은 이룸이 이름을 자리표시로 (저장값은 그대로)
      return new RegenerateTarget(
        routineId, stepId, step.getImagePath(), language,
        NicknamePlaceholder.mask(step.getDescription(), nickname, language),
        NicknamePlaceholder.mask(step.getTitle(), nickname, language),
        NicknamePlaceholder.mask(routine.getTitle(), nickname, language),
        routine.getProfile().getCharacter(),
        FluxSeed.routineKey(routine.getProfile().getId(), routine.getTitle()),
        imageStyle);
    });
  }

  /// 다시 그릴 수 있는 카드인가 3개: AI 그림이 붙어 있음, 설명 있음, 이룸이 그림 방식이 직접 사진 아님
  private static boolean isRegeneratable(RoutineStep step, ImageStyle imageStyle) {
    return RoutineImageStorage.isAiDrawn(step.getImagePath())
      && step.getDescription() != null && !step.getDescription().isBlank()
      && imageStyle != ImageStyle.PHOTO_ONLY;
  }

  /// 크레딧 예약 (꺼져 있으면 null). 거절(부족·동결·장부 오류)은 그대로 던져 앱이 코드를 보임
  private String reserveCredit(String memberId) {
    CreditReservation reservation = creditReservationService.reserve(
      memberId, CreditJobKind.IMAGE_REGENERATE, REQUEST_KEY_PREFIX + UUID.randomUUID(), false);
    return reservation.isReserved() ? reservation.jobId() : null;
  }

  /// 회원별 그림 횟수 제한 (카드 추가 그림과 같은 창). 예약 뒤에 보아 상한 거절이 횟수를 깎지 않게
  private void requireNotTooFrequent(String memberId, String stepId) {
    if (!routineStepImageThrottle.tryAcquire(memberId)) {
      log.info("[routine image regenerate] rejected 429 : too frequent, memberId={}, stepId={}", memberId, stepId);
      throw new CustomException(ErrorCode.ROUTINE_REQUEST_TOO_FREQUENT);
    }
  }

  /// 그림 생성. 호출 기록·고품질 판정에 회원·크레딧 작업·일과 언어를 세움
  private GeneratedImage generate(String memberId, String creditJobId, RegenerateTarget target) {
    AiCallContext.setMemberId(memberId);
    AiCallContext.setCreditJobId(creditJobId);
    AiCallContext.setContentLocale(target.language());
    GeneratedImage image = cardImageGenerator.generate(new CardImageGenerator.CardImageRequest(
      target.description(), null, target.characterType(), target.seedKey(), target.imageStyle(),
      target.routineTitle(), target.stepTitle()));
    if (image == null) {
      log.warn("[routine image regenerate] failed : empty image, stepId={}", target.stepId());
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_REGENERATE_FAILED);
    }
    return image;
  }

  /// 새 열쇠로 저장. 쓰기 실패는 사진 문구 대신 다시 그리기 실패로 알림
  private String saveImage(String stepId, GeneratedImage image) {
    try {
      return routineImageStorage.saveRegenerated(stepId, image);
    } catch (CustomException e) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_REGENERATE_FAILED);
    }
  }

  /**
   * 카드 그림 교체 + 정산을 한 트랜잭션에서 (정산 실패면 교체도 되돌림)
   * 그리는 사이 카드가 지워졌으면 ROUTINE_STEP_NOT_FOUND, 사진 등으로 바뀌었으면 NOT_REGENERATABLE (새 그림은 버림)
   */
  private RoutineStepResponse replaceAndSettle(RegenerateTarget target, String newKey, String creditJobId) {
    return transaction.execute(status -> {
      RoutineStep step = routineStepRepository.findById(target.stepId())
        .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
      if (!target.oldImagePath().equals(step.getImagePath())) {
        log.info("[routine image regenerate] rejected 409 : picture changed while drawing, stepId={}", target.stepId());
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
      }
      step.setImagePath(newKey);
      // 보호자가 그림을 바꿈 > 예시 표시 지움
      RoutineRules.clearExampleMark(step.getRoutine());
      if (creditJobId != null) {
        creditReservationService.settle(creditJobId, 0, 1, target.routineId(), target.stepId());
      }
      return RoutineStepResponse.from(step);
    });
  }

  /// 옛 그림 정리: 복제 일과가 같은 열쇠를 쓰면 남김. 실패해도 요청은 성공 (경고만)
  private void deleteOldIfUnreferenced(String oldKey, String stepId) {
    try {
      if (routineStepRepository.existsByImagePathAndIdNot(oldKey, stepId)) {
        return;
      }
      routineImageStorage.delete(oldKey);
    } catch (RuntimeException e) {
      log.warn("[routine image regenerate] old picture not deleted : stepId={}, key={}", stepId, oldKey, e);
    }
  }

  private void releaseCredit(String creditJobId, String reason) {
    if (creditJobId != null) {
      creditReservationService.release(creditJobId, reason);
    }
  }

  /// 그림을 그리는 데 필요한 값 (트랜잭션 밖으로 엔티티를 들고 나가지 않음)
  private record RegenerateTarget(
    String routineId, String stepId, String oldImagePath, AppLocale language,
    String description, String stepTitle, String routineTitle,
    CharacterType characterType, String seedKey, ImageStyle imageStyle
  ) {

  }
}
