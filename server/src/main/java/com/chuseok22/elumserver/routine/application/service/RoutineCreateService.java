package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.credit.application.service.CreditQueryService;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.application.service.CreditSettlement;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.constant.RewardPreset;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

/// 일과 생성과 생성 전 질문. AI 를 부르는 동안 DB 커넥션을 잡지 않도록 메서드마다 트랜잭션을 끊는다.
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineCreateService {

  /// 멱등 키 최대 길이 — ai_credit_job.request_key 가 varchar(255) 다. 넘으면 저장에서 터지기 전에 400.
  private static final int IDEMPOTENCY_KEY_MAX_LENGTH = 255;

  /// 반환 사유 최대 길이 — ai_credit_job.fail_reason 이 varchar(500) 다.
  private static final int RELEASE_REASON_MAX_LENGTH = 200;

  private final RoutineAiPipeline routineAiPipeline;
  private final RoutineImageStorage routineImageStorage;
  private final RoutineRequestCooldownGuard routineRequestCooldownGuard;
  private final RoutineQuotaGuard routineQuotaGuard;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineCreationWriter routineCreationWriter;
  private final CreditReservationService creditReservationService;
  private final CreditQueryService creditQueryService;
  private final EnabledLocales enabledLocales;

  // 질문 생성은 실패해도 항상 200을 반환한다(fail-open, RoutineAiPipeline.generateQuestion 참고).
  // Gemini 호출(수 초 소요 가능) 동안 DB 커넥션을 점유하지 않도록 create()와 동일하게
  // 클래스 레벨 readOnly 트랜잭션을 중단시킨다.
  @Transactional(propagation = Propagation.NOT_SUPPORTED)
  public RoutineQuestionResponse generateQuestion(Caller caller, RoutineQuestionRequest request) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    // 질문은 차감이 없지만 곧 일과 생성으로 이어진다. 잔액이 모자라면 여기서 막는다(스펙 §3) — 아래 AI 실패
    // 대체(fail-open)와 달리 이 거절은 403 으로 그대로 나간다. 목표와 무관하게 본다: 질문을 건너뛰는 목표여도
    // 다음 단계인 카드 만들기에서 같은 이유로 막힌다.
    creditQueryService.requireCanStartRoutine(caller.memberId());

    Set<SupportGoal> goals = profile.getSupportGoals();
    boolean needsQuestion = goals.contains(SupportGoal.PREPARE_ITEMS) || goals.contains(SupportGoal.PREPARE_NEW);
    if (!needsQuestion) {
      return new RoutineQuestionResponse(false, List.of());
    }

    // AI 호출 로그에 요청 회원을 연결한다. finally에서 반드시 비워 스레드 재사용 시
    // 다른 회원에게 새어 들어가지 않게 한다.
    AiCallContext.setMemberId(caller.memberId());
    try {
      // 입력 글을 가공하지 않고 넘긴다 — AI DLP(로컬 LLM 마스킹)는 해커톤 POC 라 쓰지 않는다 (#377).
      RoutineAiPipeline.RoutineQuestionResult result =
        routineAiPipeline.generateQuestion(profile.getNickname(), goals, request.rawInputText());
      List<RoutineQuestionResponse.QuestionItem> questions = result.questions().stream()
        .map(item -> new RoutineQuestionResponse.QuestionItem(item.question(), toOptionItems(item.options())))
        .toList();
      return new RoutineQuestionResponse(true, questions);
    } finally {
      AiCallContext.clear();
    }
  }

  private List<RoutineQuestionResponse.QuestionItem.OptionItem> toOptionItems(
    List<RoutineAiPipeline.RoutineQuestionResult.QuestionResultItem.OptionResult> options
  ) {
    return options.stream()
      .map(option -> new RoutineQuestionResponse.QuestionItem.OptionItem(option.emoji(), option.label()))
      .toList();
  }

  // Gemini 호출(수십 초 소요 가능) 동안 DB 커넥션을 점유하지 않도록 클래스 레벨
  // readOnly 트랜잭션을 이 메서드에서만 명시적으로 중단시킨다. routine은 신규 엔티티라
  // 지연 로딩 걱정이 없으므로 안전하다.
  //
  // 크레딧 (#407): 프로필 확인 뒤 예약 → AI → 저장 트랜잭션에서 정산, 실패하면 반환.
  // 비용 상한까지 모든 거절을 예약 앞에 둔다 — 거절될 요청이 예약·원장을 남기지 않게.
  @Transactional(propagation = Propagation.NOT_SUPPORTED)
  public RoutineResponse create(Caller caller, RoutineCreateRequest request, String idempotencyKey) {
    String requestKey = requestKeyOf(idempotencyKey);
    // 같은 키가 이미 끝났으면 쿨다운·한도·예산보다 먼저 돌려준다. 응답을 놓친 재전송은 새 생성이 아니다 —
    // 한도를 막 채운 요청이나 30초 안의 재전송이 막히면 이미 청구된 일과를 받을 길이 없다.
    // 키가 없으면(구버전 앱) 서버가 방금 만든 키라 찾을 것이 없다.
    if (idempotencyKey != null && !idempotencyKey.isBlank()) {
      Optional<String> settledRoutineId = creditReservationService.findSettledRoutineId(caller.memberId(), requestKey);
      if (settledRoutineId.isPresent()) {
        log.info("같은 멱등 키의 일과를 돌려준다(한도 검사 전, AI 재호출 없음): memberId={}, routineId={}",
          caller.memberId(), settledRoutineId.get());
        return routineCreationWriter.loadSaved(caller, settledRoutineId.get());
      }
    }

    routineRequestCooldownGuard.guard(caller.memberId());
    // 쿨다운이 몰아치기를 막고, 여기서 오늘·이번 주에 얼마나 썼는지를 본다(크레딧이 켜져 있으면 보유 수만).
    routineQuotaGuard.guard(caller.memberId());
    // 계정과 무관하게 서비스 전체가 오늘 쓴 비용을 본다 (#368). 셋 다 AI 를 부르기 전이라
    // 거절해도 비용이 0 이다.
    aiDailyBudgetGuard.guard();

    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);

    // 같은 키로 다시 오면(앱의 "다시 하기"·응답 유실 재전송) 이미 끝난 일과를 돌려주고 AI 를 다시 부르지 않는다.
    // 키가 없으면(구버전 앱) 요청마다 새 키 — 멱등은 없지만 크레딧은 똑같이 센다.
    CreditReservation reservation = creditReservationService.reserve(
      caller.memberId(), CreditJobKind.ROUTINE_CREATE, requestKey, true);
    if (reservation.outcome() == CreditReservation.Outcome.ALREADY_SETTLED) {
      // 선조회와 예약 사이에 같은 키가 끝난 경우다(동시 재전송).
      log.info("같은 멱등 키의 일과를 돌려준다(AI 재호출 없음): memberId={}, routineId={}",
        caller.memberId(), reservation.routineId());
      return routineCreationWriter.loadSaved(caller, reservation.routineId());
    }
    String creditJobId = reservation.isReserved() ? reservation.jobId() : null;

    // AI 호출 로그에 요청 회원을 연결한다 (텍스트·이미지 병렬 생성까지 전파).
    // 입력 글과 답변은 가공하지 않고 넘긴다. 예전의 AI DLP(로컬 LLM 마스킹)는 해커톤 POC 였고
    // 실패하면 원문을 그대로 넘기는 fail-open 이라 보장도 아니면서 호출마다 수 초가 걸렸다 (#377).
    List<String> answers = request.answers() == null ? List.of() : request.answers();
    RoutineAiPipeline.RoutineGenerationResult generation;
    AiCallContext.setMemberId(caller.memberId());
    // 호출 기록에 작업 id 를 달아 작업 하나의 실제 USD 를 대조한다. 그림 가상 스레드에도 전파된다.
    AiCallContext.setCreditJobId(creditJobId);
    try {
      generation = routineAiPipeline.generateForCreate(
        request.rawInputText(), profile.getNickname(), profile.getSupportGoals(), answers,
        profile.getCharacter(), profile.getImageStyle(), profile.getId()
      );
    } catch (RuntimeException e) {
      // 만들지 못했으면 청구하지 않는다 — 예약을 돌려준다.
      releaseCredit(creditJobId, "AI 생성 실패", e);
      throw e;
    } finally {
      AiCallContext.clear();
    }

    // 이룸이·만든 사람·순서 번호는 저장기가 이룸이 행을 잠근 뒤 채운다 (E17).
    Routine routine = new Routine();
    // 일과의 콘텐츠 언어 - 만든 요청의 화면 언어를 켜진 언어 목록에 비춰 정한다 (다국어 #526). 보호자가 고르지 않는다.
    // 헤더가 없는 옛 앱은 KO 라 지금과 같다. 필터가 심은 값이라 요청 스레드에서만 읽는다.
    routine.setLanguage(enabledLocales.resolveContentLocale(CurrentLocale.get()));
    routine.setRawInputText(request.rawInputText());
    // 가공하지 않으므로 원문과 같다. 컬럼을 없애는 것은 마이그레이션이 필요해 따로 한다 (#377).
    routine.setSanitizedInputText(request.rawInputText());
    routine.setTitle(generation.title());
    // scheduledAt은 비워서 보낼 수 있다. DB는 NOT NULL이므로 **서버가 채운다** —
    // 클라이언트도 지금 시각을 그대로 넣고 있었다(오늘 목록에 떠야 하므로). 값을 요구하면
    // 빠뜨린 호출 하나가 AI를 다 태운 뒤 DB에서 터진다 (이슈 #215).
    routine.setScheduledAt(
      request.scheduledAt() != null ? request.scheduledAt() : LocalDateTime.now()
    );
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    // 보상은 선택 항목이다. 보호자가 건너뛰면 null로 남고 이룸이 화면에서 보상 UI를 띄우지 않는다.
    routine.setRewardText(RoutineRules.trimReward(request.rewardText()));
    routine.setRewardPresetKey(RewardPreset.normalize(request.rewardPresetKey()));
    routine.setSteps(toStepEntities(routine, generation.steps()));

    // 청구할 그림 수 = 카드에 실제로 붙은 그림. 실패해 비어 있는 카드는 세지 않는다.
    int imageCount = (int) routine.getSteps().stream().filter(step -> step.getImagePath() != null).count();

    // 이미지는 여기 오기 전에 이미 디스크에 쓰였다. 저장이 실패하면 — 그사이 이 보호자가 나가 거절된
    // 경우(E17)를 포함해 — 아무도 참조하지 않는 파일이 남으므로 방금 만든 것만 되돌린다 (이슈 #215).
    // 정산은 저장과 같은 트랜잭션이라 함께 되돌아간다. 예약은 따로 돌려준다.
    RoutineCreationWriter.SavedRoutine saved;
    try {
      saved = routineCreationWriter.save(caller.memberId(), profile.getId(), routine, creditJobId, imageCount);
    } catch (RuntimeException e) {
      routineImageStorage.deleteBatch(generation.batchId());
      releaseCredit(creditJobId, "일과 저장 실패", e);
      throw e;
    }
    RoutineResponse response = RoutineResponse.from(saved.routine());
    CreditSettlement settlement = saved.settlement();
    if (settlement == null) {
      return response;
    }
    return response.withCredit(new RoutineResponse.CreditUsage(
      saved.routine().getSteps().size(), imageCount, settlement.charged(), settlement.balanceAfter()));
  }

  /// 앱이 보낸 멱등 키. 없으면(구버전 앱) 서버가 만든다.
  private static String requestKeyOf(String idempotencyKey) {
    if (idempotencyKey == null || idempotencyKey.isBlank()) {
      return UUID.randomUUID().toString();
    }
    String key = idempotencyKey.trim();
    if (key.length() > IDEMPOTENCY_KEY_MAX_LENGTH) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    return key;
  }

  /// 예약을 돌려준다. 크레딧이 꺼져 예약이 없으면 할 일이 없다. release 는 던지지 않는다 — 원래 실패를 가리지 않게.
  private void releaseCredit(String creditJobId, String what, RuntimeException cause) {
    if (creditJobId == null) {
      return;
    }
    String detail = cause instanceof CustomException custom
      ? custom.getErrorCode().name()
      : cause.getClass().getSimpleName();
    String reason = what + ": " + detail;
    creditReservationService.release(creditJobId,
      reason.length() > RELEASE_REASON_MAX_LENGTH ? reason.substring(0, RELEASE_REASON_MAX_LENGTH) : reason);
  }

  private List<RoutineStep> toStepEntities(Routine routine, List<RoutineAiPipeline.GeneratedStep> steps) {
    return steps.stream()
      .map(step -> {
        RoutineStep entity = new RoutineStep();
        entity.setRoutine(routine);
        entity.setStepOrder(step.order());
        entity.setDescription(step.description());
        entity.setTitle(step.title());
        entity.setImagePath(step.imagePath());
        entity.setPictogramId(step.pictogramId());
        return entity;
      })
      .toList();
  }
}
