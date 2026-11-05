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
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepImageRedrawRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepImageCandidateResponse;
import com.chuseok22.elumserver.routine.core.GuardianImageRequest;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineStepImageThrottle;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.util.Objects;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 카드 그림 새로 그리기(다시 그리기·처음 그리기): 권한 > 요청 정리 > 대상 확인 > 하루 비용 상한 > 크레딧 예약 > 횟수 제한 > 그림 생성 > 후보 저장·정산
 * 카드 그림은 바꾸지 않음 — 후보만 남기고 보호자가 고르면 {@link RoutineStepImageCandidateService} 가 바꿈. 실패하면 예약 반환·새 파일 삭제
 *
 * <p>단가: AI 그림 카드 = IMAGE_REGENERATE (Pro 하루 무료 한도 안이면 0), 그림 없는 카드 = CARD_IMAGE (무료 한도 밖).
 * 그림을 그렸으면 보호자가 원래 그림을 골라도 돌려주지 않음 (정산은 후보 저장 때).
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
  private final RoutineAiPicturePolicy routineAiPicturePolicy;
  /// 대상 읽기 · 후보 저장+정산을 각각 짧은 트랜잭션으로 (그림 생성 수 초 동안 DB 연결을 잡지 않음)
  private final TransactionTemplate transaction;

  public RoutineStepImageRegenerateService(
    RoutineRepository routineRepository, RoutineStepRepository routineStepRepository,
    ProfileAccessGuard profileAccessGuard, CardImageGenerator cardImageGenerator,
    RoutineImageStorage routineImageStorage, AiDailyBudgetGuard aiDailyBudgetGuard,
    RoutineStepImageThrottle routineStepImageThrottle, CreditReservationService creditReservationService,
    RoutineAiPicturePolicy routineAiPicturePolicy, PlatformTransactionManager transactionManager
  ) {
    this.routineRepository = routineRepository;
    this.routineStepRepository = routineStepRepository;
    this.profileAccessGuard = profileAccessGuard;
    this.cardImageGenerator = cardImageGenerator;
    this.routineImageStorage = routineImageStorage;
    this.aiDailyBudgetGuard = aiDailyBudgetGuard;
    this.routineStepImageThrottle = routineStepImageThrottle;
    this.creditReservationService = creditReservationService;
    this.routineAiPicturePolicy = routineAiPicturePolicy;
    this.transaction = new TransactionTemplate(transactionManager);
  }

  /**
   * 카드 한 장의 새 그림 후보를 그린다 (카드 그림은 그대로)
   *
   * @throws CustomException AI_IMAGE_NOT_ALLOWED · INVALID_INPUT_VALUE · ROUTINE_NOT_FOUND · ROUTINE_STEP_NOT_FOUND · 권한 코드 ·
   *                         ROUTINE_STEP_IMAGE_NOT_REGENERATABLE · AI_DAILY_BUDGET_EXCEEDED · AI_CREDIT_* ·
   *                         ROUTINE_REQUEST_TOO_FREQUENT · ROUTINE_STEP_IMAGE_REGENERATE_FAILED
   */
  public RoutineStepImageCandidateResponse drawCandidate(
    Caller caller, String routineId, String stepId, RoutineStepImageRedrawRequest request
  ) {
    routineAiPicturePolicy.requireAiPicture(caller.memberId());
    RoutineStepImageRedrawRequest redrawRequest = request == null ? RoutineStepImageRedrawRequest.EMPTY : request;
    String guardianRequest = GuardianImageRequest.compose(redrawRequest.requestText(), redrawRequest.hints());
    DrawTarget target = readTarget(caller, routineId, stepId);
    aiDailyBudgetGuard.guard();
    String creditJobId = reserveCredit(caller.memberId(), target.isFirstPicture());
    // 후보를 저장·정산했으면 null. 그 밖의 모든 출구는 finally 에서 이 까닭으로 반환 (성공·실패 공통)
    String releaseReason = "그림 그리기 중단";
    String newKey = null;
    try {
      requireNotTooFrequent(caller.memberId(), stepId);
      GeneratedImage image = generate(caller.memberId(), creditJobId, target, guardianRequest);
      newKey = saveImage(stepId, image);
      String replacedCandidateKey = storeCandidateAndSettle(target, newKey, creditJobId);
      releaseReason = null;
      deleteIfPresent(replacedCandidateKey);
      log.info("[routine image regenerate] candidate ready : routineId={}, stepId={}, firstPicture={}, hasRequest={}",
        routineId, stepId, target.isFirstPicture(), guardianRequest != null);
      return new RoutineStepImageCandidateResponse(stepId, newKey, target.isFirstPicture());
    } catch (CustomException e) {
      releaseReason = "그림 그리기 실패: " + e.getErrorCode().name();
      throw e;
    } catch (RuntimeException e) {
      log.warn("[routine image regenerate] failed : routineId={}, stepId={}", routineId, stepId, e);
      releaseReason = "그림 그리기 실패: " + e.getClass().getSimpleName();
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_REGENERATE_FAILED);
    } finally {
      AiCallContext.clear();
      if (releaseReason != null) {
        // 후보로 남지 않은 새 그림은 지움
        deleteIfPresent(newKey);
        releaseCredit(creditJobId, releaseReason);
      }
    }
  }

  /// 대상 확인 (권한 EDIT, 카드 있음, 다시 그리기·처음 그리기 대상) > 그림에 필요한 값만 꺼냄
  private DrawTarget readTarget(Caller caller, String routineId, String stepId) {
    return transaction.execute(status -> {
      Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, RoutineAction.EDIT);
      RoutineStep step = routine.getSteps().stream()
        .filter(candidate -> candidate.getId().equals(stepId))
        .findFirst()
        .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
      ImageStyle imageStyle = routine.getProfile().getImageStyle();
      if (!isDrawable(step, imageStyle)) {
        log.info("[routine image regenerate] rejected 409 : not a drawable card, stepId={}", stepId);
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
      }
      String nickname = routine.getProfile().getNickname();
      AppLocale language = routine.getLanguage() == null ? AppLocale.KO : routine.getLanguage();
      // 그림 AI 로 나가는 글은 이룸이 이름을 자리표시로 (저장값은 그대로)
      return new DrawTarget(
        routineId, stepId, step.getImagePath(), step.getImagePath() == null, language,
        NicknamePlaceholder.mask(step.getDescription(), nickname, language),
        NicknamePlaceholder.mask(step.getTitle(), nickname, language),
        NicknamePlaceholder.mask(routine.getTitle(), nickname, language),
        routine.getProfile().getCharacter(),
        FluxSeed.routineKey(routine.getProfile().getId(), routine.getTitle()),
        imageStyle);
    });
  }

  /**
   * 새로 그릴 수 있는 카드인가 3개: 설명 있음, 이룸이 그림 방식이 직접 사진 아님,
   * 그림이 AI 그림(다시 그리기) 또는 그림 없음(처음 그리기 — 픽토그램·예시 이미지 카드). 보호자 사진·가져온 그림은 제외
   */
  private static boolean isDrawable(RoutineStep step, ImageStyle imageStyle) {
    boolean hasDescription = step.getDescription() != null && !step.getDescription().isBlank();
    boolean isPictureReplaceable = step.getImagePath() == null || RoutineImageStorage.isAiDrawn(step.getImagePath());
    return hasDescription && isPictureReplaceable && imageStyle != ImageStyle.PHOTO_ONLY;
  }

  /// 크레딧 예약 (꺼져 있으면 null): 처음 그리기는 카드 그림 단가, 다시 그리기는 무료 한도가 있는 다시 그리기 단가
  private String reserveCredit(String memberId, boolean isFirstPicture) {
    CreditJobKind kind = isFirstPicture ? CreditJobKind.CARD_IMAGE : CreditJobKind.IMAGE_REGENERATE;
    CreditReservation reservation = creditReservationService.reserve(
      memberId, kind, REQUEST_KEY_PREFIX + UUID.randomUUID(), false);
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
  private GeneratedImage generate(String memberId, String creditJobId, DrawTarget target, String guardianRequest) {
    AiCallContext.setMemberId(memberId);
    AiCallContext.setCreditJobId(creditJobId);
    AiCallContext.setContentLocale(target.language());
    GeneratedImage image = cardImageGenerator.generate(new CardImageGenerator.CardImageRequest(
      target.description(), null, target.characterType(), target.seedKey(), target.imageStyle(),
      target.routineTitle(), target.stepTitle(), guardianRequest));
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
   * 후보 저장 + 정산을 한 트랜잭션에서 (정산 실패면 저장도 되돌림) > 밀려난 옛 후보 열쇠 (없으면 null)
   * 그리는 사이 카드가 지워졌으면 ROUTINE_STEP_NOT_FOUND, 그림이 바뀌었으면 NOT_REGENERATABLE (새 그림은 버림)
   */
  private String storeCandidateAndSettle(DrawTarget target, String newKey, String creditJobId) {
    return transaction.execute(status -> {
      RoutineStep step = routineStepRepository.findById(target.stepId())
        .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
      if (!Objects.equals(target.oldImagePath(), step.getImagePath())) {
        log.info("[routine image regenerate] rejected 409 : picture changed while drawing, stepId={}", target.stepId());
        throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_REGENERATABLE);
      }
      String replacedCandidateKey = step.getImageCandidatePath();
      step.setImageCandidatePath(newKey);
      if (creditJobId != null) {
        creditReservationService.settle(creditJobId, 0, 1, target.routineId(), target.stepId());
      }
      return replacedCandidateKey;
    });
  }

  /// 파일 정리 (없으면 할 일 없음). 저장소가 실패를 삼킴
  private void deleteIfPresent(String key) {
    if (key != null) {
      routineImageStorage.delete(key);
    }
  }

  private void releaseCredit(String creditJobId, String reason) {
    if (creditJobId != null) {
      creditReservationService.release(creditJobId, reason);
    }
  }

  /// 그림을 그리는 데 필요한 값 (트랜잭션 밖으로 엔티티를 들고 나가지 않음)
  private record DrawTarget(
    String routineId, String stepId, String oldImagePath, boolean isFirstPicture, AppLocale language,
    String description, String stepTitle, String routineTitle,
    CharacterType characterType, String seedKey, ImageStyle imageStyle
  ) {

  }
}
