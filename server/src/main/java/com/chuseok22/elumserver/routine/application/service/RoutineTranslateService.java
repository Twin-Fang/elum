package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.RoutineTranslationDraft;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.application.service.CreditSettlement;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.core.RoutineTranslationLanguages;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineTranslationAi;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;
import java.util.Locale;
import java.util.Optional;
import java.util.UUID;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 다른 언어로 만들기 (#1077): 권한·상태·언어 확인 > 크레딧 예약 > AI 번역(트랜잭션 밖) > 사본 저장·정산
 * 사본 = 일과관리에만 있는 새 원본 (그림·픽토그램 재사용, 그림 크레딧 없음). 실패하면 사본 없이 예약 반환
 * 보호자 원문(rawInputText)은 AI 로 보내지 않음 — 확정된 카드 글·제목·보상 이름만
 */
@Slf4j
@Service
public class RoutineTranslateService {

  /// 사본 제목 최대 길이 (일과관리 복사본과 같음, routine.title 255 보다 넉넉히 짧게)
  private static final int TRANSLATED_TITLE_MAX_LENGTH = 100;
  /// 멱등 키 최대 길이 (ai_credit_job.request_key varchar(255))
  private static final int IDEMPOTENCY_KEY_MAX_LENGTH = 255;
  /// 서버가 만드는 멱등 키 접두 (앱이 키를 안 보냈을 때)
  private static final String GENERATED_KEY_PREFIX = "routine-translate:";

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final EntitlementService entitlementService;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;
  private final CreditReservationService creditReservationService;
  private final RoutineCreationWriter routineCreationWriter;
  private final RoutineLibraryService routineLibraryService;
  private final RoutineTranslationAi routineTranslationAi;
  private final TransactionTemplate readOnlyTransaction;
  private final TransactionTemplate writeTransaction;

  public RoutineTranslateService(
    RoutineRepository routineRepository, ProfileAccessGuard profileAccessGuard,
    EntitlementService entitlementService, AiDailyBudgetGuard aiDailyBudgetGuard,
    CreditReservationService creditReservationService, RoutineCreationWriter routineCreationWriter,
    RoutineLibraryService routineLibraryService, RoutineTranslationAi routineTranslationAi,
    PlatformTransactionManager transactionManager
  ) {
    this.routineRepository = routineRepository;
    this.profileAccessGuard = profileAccessGuard;
    this.entitlementService = entitlementService;
    this.aiDailyBudgetGuard = aiDailyBudgetGuard;
    this.creditReservationService = creditReservationService;
    this.routineCreationWriter = routineCreationWriter;
    this.routineLibraryService = routineLibraryService;
    this.routineTranslationAi = routineTranslationAi;
    this.readOnlyTransaction = new TransactionTemplate(transactionManager);
    this.readOnlyTransaction.setReadOnly(true);
    this.writeTransaction = new TransactionTemplate(transactionManager);
  }

  /**
   * 일과 하나를 다른 언어 사본으로: 원문 읽기 > 같은 키면 저장된 사본 > 비용 상한 > 예약 > 번역 > 저장·정산
   * 거절(권한·요금제·상태·언어·상한)은 전부 예약 앞 — 거절될 요청이 예약·원장을 남기지 않게
   *
   * @param language 대상 언어 코드 (ko, en …)
   * @param idempotencyKey 앱이 누를 때마다 만든 키. 같은 키로 다시 오면 AI 를 다시 부르지 않고 저장된 사본
   */
  public RoutineResponse translate(Caller caller, String routineId, String language, String idempotencyKey) {
    AppLocale targetLanguage = parseLanguage(language);
    SourceRoutine source = readOnlyTransaction.execute(status -> readSource(caller, routineId, targetLanguage));
    String requestKey = requestKeyOf(idempotencyKey);
    Optional<String> settledRoutineId = idempotencyKey == null || idempotencyKey.isBlank()
      ? Optional.empty()
      : creditReservationService.findSettledRoutineId(caller.memberId(), requestKey);
    if (settledRoutineId.isPresent()) {
      log.info("[routine translate] same key, returning saved copy : routineId={}", settledRoutineId.get());
      return routineCreationWriter.loadSaved(caller, settledRoutineId.get());
    }
    aiDailyBudgetGuard.guard();

    CreditReservation reservation = creditReservationService.reserve(
      caller.memberId(), CreditJobKind.ROUTINE_TRANSLATE, requestKey, false);
    if (reservation.outcome() == CreditReservation.Outcome.ALREADY_SETTLED) {
      return routineCreationWriter.loadSaved(caller, reservation.routineId());
    }
    String creditJobId = reservation.isReserved() ? reservation.jobId() : null;

    RoutineTranslationDraft translated = translateTexts(caller, source, targetLanguage, creditJobId);
    try {
      return writeTransaction.execute(status -> saveCopy(caller, source, translated, targetLanguage, creditJobId));
    } catch (RuntimeException e) {
      releaseCredit(creditJobId, "번역 사본 저장 실패", e);
      throw e;
    }
  }

  /// 원문 읽기: 권한(복제와 같음) > 요금제 > 상태(임시저장 제외) > 카드 있음 > 언어(대상 목록·원문과 다름)
  private SourceRoutine readSource(Caller caller, String routineId, AppLocale targetLanguage) {
    Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId,
      RoutineAction.COPY);
    entitlementService.requireAllowed(caller.memberId(), Entitlement.ROUTINE_TRANSLATE);
    // 임시저장은 보호자 승인 전 카드라 번역 사본이 승인을 건너뛰게 됨 (서비스 원칙 3)
    if (routine.getStatus() == RoutineStatus.PENDING_REVIEW || routine.getSteps().isEmpty()) {
      log.info("[routine translate] rejected 409 : not translatable, routineId={}, status={}, stepCount={}",
        routineId, routine.getStatus(), routine.getSteps().size());
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    AppLocale sourceLanguage = routine.getLanguage() == null ? AppLocale.KO : routine.getLanguage();
    if (!RoutineTranslationLanguages.canTranslate(sourceLanguage, targetLanguage)) {
      log.info("[routine translate] rejected 400 : language not allowed, source={}, target={}",
        sourceLanguage.code(), targetLanguage.code());
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<RoutineTranslationDraft.StepText> steps = routine.getSteps().stream()
      .map(step -> new RoutineTranslationDraft.StepText(step.getTitle(), step.getDescription()))
      .toList();
    return new SourceRoutine(routine.getId(), sourceLanguage, routine.getProfile().getNickname(),
      new RoutineTranslationDraft(routine.getTitle(), routine.getRewardText(), steps));
  }

  /// AI 번역 (트랜잭션 밖, 호출 기록에 회원·작업·대상 언어). 실패하면 예약 반환 후 그대로 던짐
  private RoutineTranslationDraft translateTexts(
    Caller caller, SourceRoutine source, AppLocale targetLanguage, String creditJobId
  ) {
    AiCallContext.setMemberId(caller.memberId());
    AiCallContext.setContentLocale(targetLanguage);
    AiCallContext.setCreditJobId(creditJobId);
    try {
      return routineTranslationAi.translate(source.draft(), source.nickname(), source.language(), targetLanguage);
    } catch (RuntimeException e) {
      releaseCredit(creditJobId, "AI 번역 실패", e);
      throw e;
    } finally {
      AiCallContext.clear();
    }
  }

  /**
   * 사본 저장: 원문 다시 읽기(권한) > 그사이 카드 수가 바뀌었으면 실패 > 카드 복사(그림 재사용) > 번역 글·언어 입히기 > 저장 > 정산
   * 정산은 이 트랜잭션에 합류 — 정산이 실패하면 사본도 함께 되돌아감
   */
  private RoutineResponse saveCopy(
    Caller caller, SourceRoutine source, RoutineTranslationDraft translated, AppLocale targetLanguage,
    String creditJobId
  ) {
    Routine original = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, source.routineId(),
      RoutineAction.COPY);
    if (original.getSteps().size() != translated.steps().size()) {
      log.warn("[routine translate] failed 502 : steps changed during translation, routineId={}", source.routineId());
      throw new CustomException(ErrorCode.ROUTINE_TRANSLATE_FAILED);
    }
    Routine copy = routineLibraryService.newLibraryCopyOf(original, caller.memberId(), false);
    applyTranslation(copy, translated, targetLanguage);
    Routine saved = routineLibraryService.saveCopy(copy);
    log.info("[routine translate] saved : sourceRoutineId={}, copyRoutineId={}, source={}, target={}, stepCount={}",
      source.routineId(), saved.getId(), source.language().code(), targetLanguage.code(), saved.getSteps().size());
    RoutineResponse response = RoutineResponse.from(saved);
    if (creditJobId == null) {
      return response;
    }
    CreditSettlement settlement = creditReservationService.settle(
      creditJobId, saved.getSteps().size(), 0, saved.getId(), null);
    return response.withCredit(new RoutineResponse.CreditUsage(
      saved.getSteps().size(), 0, settlement.charged(), settlement.balanceAfter()));
  }

  /// 번역 글 입히기: 제목(원문 자리도 번역 제목 — 보호자 원문은 사본에 남기지 않음), 보상, 카드 제목·설명 (차례대로), 언어
  private static void applyTranslation(Routine copy, RoutineTranslationDraft translated, AppLocale targetLanguage) {
    String title = truncate(translated.title(), TRANSLATED_TITLE_MAX_LENGTH);
    copy.setTitle(title);
    copy.setRawInputText(title);
    copy.setSanitizedInputText(title);
    copy.setLanguage(targetLanguage);
    if (copy.getRewardText() != null) {
      copy.setRewardText(RoutineRules.trimReward(translated.rewardText()));
    }
    List<RoutineStep> steps = copy.getSteps();
    for (int index = 0; index < steps.size(); index++) {
      RoutineTranslationDraft.StepText text = translated.steps().get(index);
      RoutineStep step = steps.get(index);
      // 옛 카드는 제목 칸이 비어 있음 > 번역 제목이 있어도 원문처럼 비워 둠 (카드 모양 유지)
      step.setTitle(step.getTitle() == null ? null : text.title());
      step.setDescription(text.description());
    }
  }

  /// 대상 언어 코드 > 언어 (비었거나 모르는 코드는 400)
  private static AppLocale parseLanguage(String language) {
    if (language == null || language.isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return AppLocale.findByCode(language.trim().toLowerCase(Locale.ROOT))
      .orElseThrow(() -> new CustomException(ErrorCode.INVALID_INPUT_VALUE));
  }

  private static String requestKeyOf(String idempotencyKey) {
    if (idempotencyKey == null || idempotencyKey.isBlank()) {
      return GENERATED_KEY_PREFIX + UUID.randomUUID();
    }
    String key = idempotencyKey.trim();
    if (key.length() > IDEMPOTENCY_KEY_MAX_LENGTH) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return key;
  }

  private static String truncate(String text, int maxLength) {
    return text.length() > maxLength ? text.substring(0, maxLength).stripTrailing() : text;
  }

  /// 예약 반환 (크레딧 꺼짐이면 할 일 없음). release 는 던지지 않음 — 원래 실패를 가리지 않게
  private void releaseCredit(String creditJobId, String what, RuntimeException cause) {
    if (creditJobId == null) {
      return;
    }
    String detail = cause instanceof CustomException custom
      ? custom.getErrorCode().name()
      : cause.getClass().getSimpleName();
    creditReservationService.release(creditJobId, what + ": " + detail);
  }

  /// 트랜잭션 밖으로 들고 나가는 원문 (엔티티 대신 글만)
  private record SourceRoutine(String routineId, AppLocale language, String nickname, RoutineTranslationDraft draft) {

  }
}
