package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.ai.core.AiCallContext;
import com.chuseok22.elumserver.ai.core.FluxSeed;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditQueryService;
import com.chuseok22.elumserver.credit.application.service.CreditReservation;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.credit.application.service.CreditSettlement;
import com.chuseok22.elumserver.credit.core.CreditJobKind;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.CharacterType;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.application.dto.request.RewardUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineQuestionRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepCreateRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepUpdateRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RecentRewardResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineQuestionResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineAiPipeline;
import com.chuseok22.elumserver.routine.infrastructure.constant.RewardPreset;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineSuggestionCatalog;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.guard.RoutineRequestCooldownGuard;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.Set;
import java.util.UUID;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineService {

  /// 보상 설정 화면 입력칸 아래에 띄울 "최근에 정한 보상" 개수.
  /// 시안(1082:4801)이 칩을 2·2 넷으로 그린다 — 셋이면 둘째 줄이 한 칸만 차 2·1 로 선다 (#380).
  /// 그 이상은 고르는 부담만 늘어난다.
  private static final int RECENT_REWARD_LIMIT = 4;

  /// 보호자 홈 "지난 일과" 노출 개수. 전부 내려주면 오늘 할 일이 묻힌다.
  private static final int PAST_ROUTINE_LIMIT = 10;

  /// 보상 텍스트 최대 길이. 아동 화면에 한 줄로 들어가야 하고,
  /// 길어질수록 글을 읽는 사용자에게도 부담이 된다.
  private static final int REWARD_TEXT_MAX_LENGTH = 100;

  /// 한 일과에 담을 수 있는 카드 수 상한 (이슈 #199).
  ///
  /// AI 생성 경로가 이미 같은 값으로 막혀 있다(`RoutineAiPipeline.MAX_STEPS`, 프롬프트도
  /// "1개 이상 10개 이하"). 같은 값으로 맞춰야 **기존 일과 중 상한을 넘는 것이 없다** —
  /// 더 낮게 잡으면 AI가 만든 일과가 처음부터 상한 초과 상태가 된다.
  ///
  /// 카드 1장을 추가할 때마다 AI 이미지가 1회 생성된다. 다만 이 상한은 비용의 천장이
  /// 아니다 — 지우면 자리가 다시 나서 추가·삭제를 되풀이할 수 있다. 그림 횟수는
  /// {@link RoutineStepImageFiller}가 따로 묶는다 (#368).
  private static final int STEP_MAX_COUNT = 10;

  /// 멱등 키 최대 길이 — ai_credit_job.request_key 가 varchar(255) 다. 넘으면 저장에서 터지기 전에 400.
  private static final int IDEMPOTENCY_KEY_MAX_LENGTH = 255;
  /// 반환 사유 최대 길이 — ai_credit_job.fail_reason 이 varchar(500) 다.
  private static final int RELEASE_REASON_MAX_LENGTH = 200;

  private final RoutineRepository routineRepository;
  private final ProfileRepository profileRepository;
  private final RoutineAiPipeline routineAiPipeline;
  private final RoutineImageStorage routineImageStorage;
  private final RoutineRequestCooldownGuard routineRequestCooldownGuard;
  private final RoutineQuotaGuard routineQuotaGuard;
  private final AiDailyBudgetGuard aiDailyBudgetGuard;
  private final RoutineStepImageFiller routineStepImageFiller;
  private final ProfileAccessGuard profileAccessGuard;
  private final RoutineCreationWriter routineCreationWriter;
  private final RoutineStepRepository routineStepRepository;
  private final CreditReservationService creditReservationService;
  private final CreditQueryService creditQueryService;

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
        profile.getCharacter(), profile.getId()
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
    routine.setRewardText(trimReward(request.rewardText()));
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

  @Transactional
  public RoutineResponse confirm(Caller caller, String routineId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    if (routine.getStatus() != RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    routine.setStatus(RoutineStatus.CONFIRMED);
    // 승인한 날이 곧 그 일과를 하는 날이다.
    // 날짜 선택 UI를 두지 않는 대신, 미리 만들어 둔 일과를 그날 승인하면 그날 일과가 된다.
    // (아이 홈은 scheduledAt이 오늘인 CONFIRMED만 조회하므로 이 갱신이 없으면 미리 만든 일과가 뜨지 않는다)
    routine.setScheduledAt(LocalDate.now().atTime(9, 0));
    return RoutineResponse.from(routine);
  }

  /// 보상만 수정한다. 일과를 만든 뒤에도 보호자가 바꿀 수 있어야
  /// "보호자가 관리한다"가 성립한다 (2026-09-13 자문).
  @Transactional
  public RoutineResponse updateReward(Caller caller, String routineId, RewardUpdateRequest request) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    routine.setRewardText(trimReward(request.rewardText()));
    routine.setRewardPresetKey(RewardPreset.normalize(request.rewardPresetKey()));
    return RoutineResponse.from(routine);
  }

  /// 최근에 사용한 보상 최대 4개. 보상 설정 화면 입력칸 아래에 띄워 두 번째 일과부터는
  /// 탭 한 번으로 끝나게 한다 — 온보딩을 늘리지 않고 입력 부담을 줄이는 방법이다.
  public List<RecentRewardResponse> getRecentRewards(Caller caller) {
    LinkedHashMap<String, RecentRewardResponse> unique = new LinkedHashMap<>();
    for (Routine routine : routineRepository
      .findTop30ByProfileIdAndRewardTextIsNotNullOrderByCreatedAtDesc(profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId())) {
      String text = routine.getRewardText();
      if (text == null || text.isBlank()) {
        continue;
      }
      // 같은 보상이 여러 일과에 쓰였으면 가장 최근 것 하나만 남긴다.
      unique.putIfAbsent(text, new RecentRewardResponse(text, routine.getRewardPresetKey()));
      if (unique.size() >= RECENT_REWARD_LIMIT) {
        break;
      }
    }
    return List.copyOf(unique.values());
  }

  /// 지난 일과를 오늘 일과로 복제한다. **AI를 호출하지 않는다** —
  /// 매일 같은 준비를 하는 경우 탭 한 번으로 끝나야 재사용 가치가 있다.
  ///
  /// 원문(`rawInputText`·`sanitizedInputText`)은 복사하지 않는다. 원문을 계속 들고 다니지 않는다는
  /// 서비스 원칙에 맞추고, 복제본은 카드만 있으면 수행에 지장이 없다.
  @Transactional
  public RoutineResponse duplicate(Caller caller, String routineId) {
    Routine origin = getRoutineFor(caller, routineId, RoutineAction.COPY);

    Routine copy = new Routine();
    copy.setProfile(origin.getProfile());
    // 복제본은 복제한 사람의 일과다. 원본을 누가 만들었든 원본은 그대로 남는다.
    copy.setCreatedBy(caller.memberId());
    copy.setRawInputText(origin.getTitle());
    copy.setSanitizedInputText(origin.getTitle());
    copy.setTitle(origin.getTitle());
    copy.setScheduledAt(LocalDate.now().atTime(9, 0));
    // 이미 검토를 거친 카드라 다시 승인받지 않는다. 바로 오늘 할 일이 된다.
    copy.setStatus(RoutineStatus.CONFIRMED);
    copy.setRewardText(origin.getRewardText());
    copy.setRewardPresetKey(origin.getRewardPresetKey());

    List<RoutineStep> copiedSteps = new ArrayList<>();
    for (RoutineStep step : origin.getSteps()) {
      RoutineStep copied = new RoutineStep();
      copied.setRoutine(copy);
      copied.setStepOrder(step.getStepOrder());
      copied.setTitle(step.getTitle());
      copied.setDescription(step.getDescription());
      // 이미지는 새로 만들지 않고 그대로 쓴다 — 재생성은 비용이고 같은 행동이면 같은 그림이면 된다.
      copied.setImagePath(step.getImagePath());
      copied.setCompleted(false);
      copiedSteps.add(copied);
    }
    copy.setSteps(copiedSteps);

    return RoutineResponse.from(routineRepository.save(copy));
  }

  /// 임시저장(`PENDING_REVIEW`) 일과만 삭제한다.
  ///
  /// 승인된 일과는 지우지 않는다 — 수행률 추이의 원본 데이터이고,
  /// 보호자가 "이 날은 왜 못 했지"를 확인하는 근거다.
  @Transactional
  public void delete(Caller caller, String routineId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    if (routine.getStatus() != RoutineStatus.PENDING_REVIEW) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }
    routineRepository.delete(routine);
  }

  /// 보호자 홈 "지난 일과" — 오늘 이전 것만 최신순 10개.
  /// 전부 내려주면 목록이 계속 쌓여 오늘 할 일이 묻힌다.
  ///
  /// 프로필을 계정에서 떼어낸 뒤로 profileId와 memberId는 서로 다른 값이다.
  /// 여기에 memberId를 그대로 넘기고 있어서 **어떤 일과도 걸리지 않았다** —
  /// 모든 보호자에게 지난 일과가 빈 칸으로 보였다. 같은 실수를 오늘 일과에서
  /// 한 번 고쳤는데(getTodayRoutines) 이곳이 함께 고쳐지지 않았다.
  ///
  /// 보낸 일과(CONFIRMED·COMPLETED)만 준다 — 오늘 일과와 같은 기준이다 (#353).
  /// 상태를 거르지 않으면 오늘 만들다 둔 임시저장이 내일 지난 일과에 뜬다 (#387).
  public List<RoutineResponse> getPastRoutines(Caller caller) {
    return routineRepository
      .findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
        profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId(),
        List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED),
        LocalDate.now().atStartOfDay())
      .stream()
      .limit(PAST_ROUTINE_LIMIT)
      .map(RoutineResponse::from)
      .toList();
  }

  /// 보호자 홈 "임시저장" — 카드는 만들었지만 아직 아이에게 보내지 않은 일과.
  public List<RoutineResponse> getDraftRoutines(Caller caller) {
    return routineRepository
      .findAllByProfileIdAndStatusOrderByCreatedAtDesc(profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId(), RoutineStatus.PENDING_REVIEW)
      .stream()
      .map(RoutineResponse::from)
      .toList();
  }

  /// 보상 텍스트 정리. 공백만 남으면 없는 것으로 본다.
  /// 길이는 화면에서 막지만 서버도 잘라둔다 — 클라이언트만 믿지 않는다.
  private String trimReward(String text) {
    if (text == null) {
      return null;
    }
    String trimmed = text.trim();
    if (trimmed.isEmpty()) {
      return null;
    }
    return trimmed.length() > REWARD_TEXT_MAX_LENGTH
      ? trimmed.substring(0, REWARD_TEXT_MAX_LENGTH)
      : trimmed;
  }

  @Transactional
  public RoutineResponse completeStep(Caller caller, String routineId, String stepId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.PROGRESS);
    if (routine.getStatus() != RoutineStatus.CONFIRMED) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    List<RoutineStep> steps = routine.getSteps();
    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    if (Boolean.TRUE.equals(targetStep.getCompleted())) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_ALREADY_COMPLETED);
    }

    boolean hasIncompletePriorStep = steps.stream()
      .filter(step -> step.getStepOrder() < targetStep.getStepOrder())
      .anyMatch(step -> !Boolean.TRUE.equals(step.getCompleted()));
    if (hasIncompletePriorStep) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_ORDER_VIOLATION);
    }

    LocalDateTime now = LocalDateTime.now();
    targetStep.setCompleted(true);
    targetStep.setCompletedAt(now);
    // 별은 쿼리로 더한다 — 두 기기가 동시에 체크해도 하나가 사라지지 않는다 (E25).
    profileRepository.addStars(routine.getProfile().getId(), 1);

    boolean allCompleted = steps.stream().allMatch(step -> Boolean.TRUE.equals(step.getCompleted()));
    if (allCompleted) {
      routine.setStatus(RoutineStatus.COMPLETED);
      routine.setCompletedAt(now);
    }

    return RoutineResponse.from(routine);
  }

  @Transactional
  public RoutineResponse cancelStep(Caller caller, String routineId, String stepId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.PROGRESS);
    if (routine.getStatus() != RoutineStatus.CONFIRMED && routine.getStatus() != RoutineStatus.COMPLETED) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    List<RoutineStep> steps = routine.getSteps();
    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    if (!Boolean.TRUE.equals(targetStep.getCompleted())) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_NOT_COMPLETED);
    }

    boolean hasLaterCompletedStep = steps.stream()
      .filter(step -> step.getStepOrder() > targetStep.getStepOrder())
      .anyMatch(step -> Boolean.TRUE.equals(step.getCompleted()));
    if (hasLaterCompletedStep) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_CANCEL_ORDER_VIOLATION);
    }

    targetStep.setCompleted(false);
    targetStep.setCompletedAt(null);
    profileRepository.addStars(routine.getProfile().getId(), -1);

    if (routine.getStatus() == RoutineStatus.COMPLETED) {
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setCompletedAt(null);
    }

    return RoutineResponse.from(routine);
  }

  // 오프라인 퍼스트 클라이언트가 "이 일과의 완료 집합은 이것이다"를 통째로 보낸다.
  // 단계별 complete/cancel과 달리 **순서를 검사하지 않고** 최종 상태로 맞춘다 —
  // 오프라인 재전송에서 요청 하나가 거부돼 뒤가 연쇄로 무너지는 문제(이슈 #139)를
  // 구조적으로 없애기 위함. 별은 완료 수의 차이만큼만 움직여 같은 요청을 여러 번
  // 보내도 결과가 같다(멱등).
  @Transactional
  public RoutineResponse syncProgress(Caller caller, String routineId, List<String> completedStepIds) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.PROGRESS);
    if (routine.getStatus() != RoutineStatus.CONFIRMED && routine.getStatus() != RoutineStatus.COMPLETED) {
      throw new CustomException(ErrorCode.ROUTINE_INVALID_STATUS);
    }

    List<RoutineStep> steps = routine.getSteps();
    Set<String> target = new HashSet<>(completedStepIds);
    Set<String> known = steps.stream().map(RoutineStep::getId).collect(Collectors.toSet());
    if (!known.containsAll(target)) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND);
    }

    LocalDateTime now = LocalDateTime.now();
    int before = countCompleted(steps);
    for (RoutineStep step : steps) {
      boolean shouldComplete = target.contains(step.getId());
      boolean isCompleted = Boolean.TRUE.equals(step.getCompleted());
      if (shouldComplete && !isCompleted) {
        step.setCompleted(true);
        step.setCompletedAt(now);
      } else if (!shouldComplete && isCompleted) {
        step.setCompleted(false);
        step.setCompletedAt(null);
      }
      // 이미 완료였고 여전히 완료면 completedAt을 건드리지 않는다 — 처음 완료한 시각이 기록이다.
    }
    int after = countCompleted(steps);

    // 완료 수의 차이만큼만 움직인다(멱등). 변화가 없으면 쿼리도 보내지 않는다.
    if (after != before) {
      profileRepository.addStars(routine.getProfile().getId(), after - before);
    }

    boolean allCompleted = !steps.isEmpty() && after == steps.size();
    if (allCompleted) {
      if (routine.getStatus() != RoutineStatus.COMPLETED) {
        routine.setStatus(RoutineStatus.COMPLETED);
        routine.setCompletedAt(now);
      }
    } else {
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setCompletedAt(null);
    }

    return RoutineResponse.from(routine);
  }

  private int countCompleted(List<RoutineStep> steps) {
    return (int) steps.stream().filter(step -> Boolean.TRUE.equals(step.getCompleted())).count();
  }

  @Transactional
  public RoutineResponse updateStep(
    Caller caller, String routineId, String stepId, RoutineStepUpdateRequest request
  ) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    requireEditableRoutine(routine);

    List<RoutineStep> steps = routine.getSteps();
    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    // 보낸 필드만 반영한다. 예전에는 넘어온 값을 그대로 덮어써서, 순서만 보내면
    // 제목·설명이 null로 지워졌다.
    if (request.title() != null) {
      targetStep.setTitle(request.title());
    }
    if (request.description() != null) {
      targetStep.setDescription(request.description());
    }
    if (request.stepOrder() != null) {
      moveStep(steps, targetStep, request.stepOrder());
    }

    return RoutineResponse.from(routine);
  }

  /**
   * 카드를 원하는 자리로 옮기고 나머지를 1..N으로 다시 채운다 (이슈 #199).
   *
   * <p>화면은 화살표로 한 칸씩 민다. 클라가 낙관적으로 먼저 반영하고 실패하면 되돌리므로,
   * 서버는 <b>항상 연속된 값</b>으로 정규화해 응답한다 — 값이 겹치거나 비면 다음 이동에서
   * 순서가 튄다.
   *
   * <p>범위를 벗어난 값은 막지 않고 끝으로 붙인다. 화살표를 끝에서 한 번 더 눌렀을 때
   * 400을 던지면 화면이 되돌아가야 하는데, 사용자가 보기엔 아무 일도 아니다.
   */
  private void moveStep(List<RoutineStep> steps, RoutineStep target, int desiredOrder) {
    List<RoutineStep> ordered = new ArrayList<>(steps);
    ordered.sort(Comparator.comparingInt(RoutineStep::getStepOrder));
    ordered.remove(target);

    int index = Math.clamp(desiredOrder - 1, 0, ordered.size());
    ordered.add(index, target);

    for (int i = 0; i < ordered.size(); i++) {
      ordered.get(i).setStepOrder(i + 1);
    }
  }

  /**
   * 카드를 고칠 수 있는 상태인지 본다 (이슈 #199).
   *
   * <p>예전에는 {@code PENDING_REVIEW}만 허용했다. 전문가 자문의 필수 요구가
   * <i>"생성된 카드를 수정·순서 변경·삭제할 수 있어야 한다. 쉽게."</i> 라서,
   * <b>이룸이에게 보낸 뒤에도</b> 고칠 수 있어야 한다.
   *
   * <p>지금은 모든 상태를 허용하므로 막는 경우가 없다. 그래도 메서드를 두는 이유는
   * 다시 조일 자리를 한 곳으로 모아 두기 위함이다 — 호출부 네 곳에 흩어지면
   * 한 군데만 고쳐져 어긋난다.
   */
  private void requireEditableRoutine(Routine routine) {
    // 현재는 PENDING_REVIEW · CONFIRMED · COMPLETED 모두 허용한다.
  }

  @Transactional
  public RoutineResponse deleteStep(Caller caller, String routineId, String stepId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    requireEditableRoutine(routine);

    List<RoutineStep> steps = routine.getSteps();
    if (steps.size() <= 1) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_MIN_COUNT);
    }

    RoutineStep targetStep = steps.stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));

    // 이미 별을 받은 카드를 지우면 그 별도 함께 거둔다 (이슈 #199).
    // 별은 "완료한 카드 수"를 따라간다 — completeStep(+1) · cancelStep(-1) ·
    // syncProgress(증감분)가 모두 그 규칙이다. 카드가 사라졌는데 별만 남으면
    // 이룸이 화면의 별 개수가 무엇을 센 것인지 설명할 수 없게 된다.
    // 보호자가 스스로 카드를 지울 때의 동작이다. 나가기에 의한 삭제는 별을 건드리지 않는다 (명세 4-3).
    if (Boolean.TRUE.equals(targetStep.getCompleted())) {
      profileRepository.addStars(routine.getProfile().getId(), -1);
    }

    steps.remove(targetStep);
    renumberSteps(steps);
    refreshCompletionStatus(routine);

    return RoutineResponse.from(routine);
  }

  /**
   * 보호자가 카드를 한 장 직접 추가한다 (이슈 #199).
   *
   * <p><b>그림을 기다리지 않는다.</b> 이미지 생성은 몇 초 걸리는데 응답을 그때까지
   * 붙잡으면 화면이 멈춘다. 카드를 먼저 만들어 응답하고, 그림은 커밋 뒤에 채운다.
   * 클라는 {@code imagePath}가 빌 동안 "그림 만드는 중"을 띄운다 (#198 §9).
   *
   * <p><b>그림이 실패해도 카드 추가는 성공한다.</b> {@code imagePath}를 {@code null}로
   * 두고 끝낸다 — 클라가 기본 그림으로 채운다 (서비스 원칙 6).
   *
   * <p>하루 비용 상한이나 회원별 그림 횟수에 걸려도 같다 — 카드는 추가하고 그림만
   * 건너뛴다 (#368). 그래서 여기에는 일과 만들기의 쿨다운·한도를 걸지 않는다.
   *
   * <p><b>그림은 {@code generateImage=true} 일 때만 만든다 (#407).</b> 크레딧이 켜져 있으면 이 트랜잭션 안에서
   * 그림 1장을 예약한다(초과 허용 없음). 모자라거나 계정이 멈춰 있으면 카드는 저장하고 그림만 건너뛰며 응답에
   * 까닭을 싣는다. 예약 거절은 예약 트랜잭션이 정상으로 끝난 뒤 던져지므로 이 트랜잭션은 롤백 전용이 되지 않는다.
   * 장부 오류(AI_CREDIT_UNAVAILABLE)는 카드까지 실패시킨다 — 그 경우 예약 안에서 난 예외가 이 트랜잭션을
   * 이미 롤백 전용으로 만들어 카드만 저장할 수 없고, 장부 오류는 막는다(fail-closed).
   */
  @Transactional
  public RoutineResponse addStep(
    Caller caller, String routineId, RoutineStepCreateRequest request
  ) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    requireEditableRoutine(routine);

    List<RoutineStep> steps = routine.getSteps();
    if (steps.size() >= STEP_MAX_COUNT) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_MAX_COUNT);
    }

    RoutineStep step = new RoutineStep();
    step.setRoutine(routine);
    step.setTitle(request.title().trim());
    step.setDescription(request.descriptionOrEmpty());
    // 맨 뒤에 붙인다. 뒤이어 renumberSteps가 1..N으로 정규화하므로
    // 기존 값이 비어 있거나 겹쳐 있어도 결과는 연속값이 된다.
    step.setStepOrder(steps.size() + 1);
    step.setCompleted(false);
    steps.add(step);
    renumberSteps(steps);

    // 카드가 늘면 "전부 완료" 상태가 깨진다 — COMPLETED였다면 CONFIRMED로 되돌린다.
    refreshCompletionStatus(routine);

    // 지금 저장해 id 를 받는다. 목록에만 넣으면 커밋 때에야 id 가 매겨져, 그림 예약·정산에 넘길 카드 id 가
    // 비어 있다 — 예전에는 그래서 그림 채우기가 "카드 없음"으로 끝났다.
    routineStepRepository.save(step);

    if (!request.wantsImage() || step.getDescription().isBlank()) {
      return RoutineResponse.from(routine);
    }

    String creditJobId;
    try {
      // 카드 추가는 멱등 키가 없다 — 요청마다 새 작업이다.
      CreditReservation reservation = creditReservationService.reserve(
        caller.memberId(), CreditJobKind.CARD_IMAGE, "card-image:" + UUID.randomUUID(), false);
      creditJobId = reservation.isReserved() ? reservation.jobId() : null;
    } catch (CustomException e) {
      if (e.getErrorCode() == ErrorCode.AI_CREDIT_INSUFFICIENT
        || e.getErrorCode() == ErrorCode.AI_CREDIT_ACCOUNT_FROZEN) {
        log.info("크레딧 거절 — 카드만 저장하고 그림은 건너뛴다: memberId={}, routineId={}, reason={}",
          caller.memberId(), routineId, e.getErrorCode());
        return RoutineResponse.from(routine).withImageSkippedReason(e.getErrorCode().name());
      }
      throw e;
    }

    // 커밋된 뒤에 그림을 만든다. 트랜잭션 안에서 돌리면 Gemini 호출(수 초) 동안
    // DB 커넥션을 붙잡고, 롤백되면 방금 쓴 이미지 파일이 고아로 남는다. 롤백되면 예약도 함께 사라진다.
    routineStepImageFiller.scheduleAfterCommit(
      caller.memberId(), routineId, step.getId(), step.getDescription(), routine.getProfile().getCharacter(),
      FluxSeed.routineKey(routine.getProfile().getId(), routine.getTitle()), creditJobId);

    return RoutineResponse.from(routine);
  }

  /**
   * 카드가 늘거나 줄었을 때 일과의 완료 상태를 다시 계산한다 (이슈 #199).
   *
   * <p>{@code syncProgress}가 쓰는 규칙과 같다 — 전부 완료면 COMPLETED, 아니면 CONFIRMED.
   * 검토 중(PENDING_REVIEW)인 일과는 아직 이룸이에게 가지 않았으므로 건드리지 않는다.
   */
  private void refreshCompletionStatus(Routine routine) {
    if (routine.getStatus() == RoutineStatus.PENDING_REVIEW) {
      return;
    }
    List<RoutineStep> steps = routine.getSteps();
    boolean allCompleted =
      !steps.isEmpty() && steps.stream().allMatch(s -> Boolean.TRUE.equals(s.getCompleted()));
    if (allCompleted) {
      if (routine.getStatus() != RoutineStatus.COMPLETED) {
        routine.setStatus(RoutineStatus.COMPLETED);
        routine.setCompletedAt(LocalDateTime.now());
      }
    } else {
      routine.setStatus(RoutineStatus.CONFIRMED);
      routine.setCompletedAt(null);
    }
  }

  // 삭제 후 남은 단계들의 stepOrder를 1..N으로 다시 채운다. PENDING_REVIEW 단계는 완료 이력이
  // 전혀 없어 재채번이 완료/취소 순서 검증 로직과 충돌하지 않는다.
  private void renumberSteps(List<RoutineStep> steps) {
    List<RoutineStep> ordered = steps.stream()
      .sorted(Comparator.comparingInt(RoutineStep::getStepOrder))
      .toList();
    for (int i = 0; i < ordered.size(); i++) {
      ordered.get(i).setStepOrder(i + 1);
    }
  }

  public RoutineResponse getRoutine(Caller caller, String routineId) {
    return RoutineResponse.from(getRoutineFor(caller, routineId, RoutineAction.VIEW));
  }

  public List<RoutineResponse> getMyRoutines(Caller caller) {
    return routineRepository.findAllByProfileId(profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId()).stream()
      .map(RoutineResponse::from)
      .toList();
  }

  // 아이 홈 화면 "오늘 할 일" 리스트용. 보호자 승인 전(PENDING_REVIEW) 일과는 제외하고,
  // scheduledAt이 오늘(KST) 안에 있는 CONFIRMED/COMPLETED 일과만 예정 시각 순으로 반환한다.
  public List<RoutineResponse> getTodayRoutines(Caller caller) {
    LocalDate today = LocalDate.now();
    LocalDateTime startOfDay = today.atStartOfDay();
    LocalDateTime endOfDay = today.atTime(LocalTime.MAX);
    // 프로필을 계정에서 떼어낸 뒤로 profileId와 memberId가 다른 값이 됐는데, 여기만
    // memberId를 그대로 넘기고 있었다. 그 상태로는 어떤 일과도 걸리지 않는다.
    // 보이는 순서 → 예정 시각 차례로 줄 세운다.
    List<Routine> routines = routineRepository.findTodayOrdered(
      profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId(),
      List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED), startOfDay, endOfDay
    );
    return routines.stream().map(RoutineResponse::from).toList();
  }

  // count는 프론트가 요청한 반환 개수다. 1 미만이거나 카탈로그 전체 개수를 초과하면
  // 항상 이 범위 안에서만 뽑을 수 있으므로 잘못된 요청으로 간주해 거부한다.
  public List<RoutineSuggestionResponse> getSuggestions(int count) {
    if (count < 1 || count > RoutineSuggestionCatalog.ALL.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<RoutineSuggestionResponse> pool = new ArrayList<>(RoutineSuggestionCatalog.ALL);
    Collections.shuffle(pool);
    return List.copyOf(pool.subList(0, count));
  }

  public RoutineImageStorage.ImageContent getStepImage(Caller caller, String routineId, String stepId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.VIEW);
    RoutineStep targetStep = routine.getSteps().stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
    // 이미지 생성에 실패해 imagePath가 null인 단계는 이미지가 없다. Path.of(null) NPE 대신
    // 404로 명확히 응답한다(클라이언트는 이미지 자리를 비워 렌더링).
    if (targetStep.getImagePath() == null) {
      throw new CustomException(ErrorCode.ROUTINE_STEP_IMAGE_NOT_FOUND);
    }
    return routineImageStorage.read(targetStep.getImagePath());
  }

  /**
   * 홈 목록의 순서를 통째로 다시 매긴다.
   *
   * <p>보낸 차례대로 1부터 번호를 붙인다. 일부만 보내 부분 갱신하는 방식이 아니라
   * <b>화면에 보이는 전체를 그대로 보낸다</b> — 부분 갱신은 두 사람이 동시에 순서를
   * 바꿀 때 뒤엉킨다.
   *
   * <p>하나라도 남의 것이거나 없는 것이 섞이면 <b>아무것도 바꾸지 않고</b> 거부한다.
   * 절반만 반영되면 화면과 서버의 순서가 어긋나 더 나쁘다.
   *
   * <p>그사이 목록이 늘거나 줄었으면 409 다 (다중 보호자 E24). 보호자가 여럿이면(또는 한 보호자가 휴대폰
   * 둘로) 옛 목록을 보고 동시에 순서를 보낼 수 있다. 비교 기준은 앱이 실제로 보내는 목록 — 보호자 홈의
   * 오늘 목록(단계가 있는 것)이다.
   */
  @Transactional
  public void reorder(Caller caller, List<String> routineIds) {
    if (routineIds == null || routineIds.isEmpty()) {
      return;
    }
    // 같은 값이 두 번 오면 번호가 겹쳐 순서가 뒤엉킨다.
    if (new HashSet<>(routineIds).size() != routineIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    List<Routine> routines = routineRepository.findAllById(routineIds);
    // 보낸 일과가 그사이 지워졌다 — 화면이 옛 목록이다.
    if (routines.size() != routineIds.size()) {
      throw new CustomException(ErrorCode.ROUTINE_ORDER_CONFLICT);
    }

    Map<String, Routine> byId = new HashMap<>();
    for (Routine routine : routines) {
      if (!routine.getProfile().getId().equals(profile.getId())) {
        throw new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED);
      }
      byId.put(routine.getId(), routine);
    }
    // 그사이 오늘 일과가 늘었다 — 보낸 목록으로는 새 일과의 자리를 알 수 없다.
    if (hasTodayRoutineMissingFrom(profile.getId(), byId.keySet())) {
      throw new CustomException(ErrorCode.ROUTINE_ORDER_CONFLICT);
    }

    for (int i = 0; i < routineIds.size(); i++) {
      byId.get(routineIds.get(i)).setDisplayOrder(i + 1);
    }
  }

  /**
   * 지금 오늘 목록에 있는데 보낸 목록에 없는 일과가 있는가.
   *
   * <p>앱은 오늘 목록 중 단계가 있는 것만 보내고, 방금 저장한 일과를 앞에 더해 보낸다
   * (today_routine_section.dart homeRoutinesProvider). 같은 기준으로 세야 멀쩡한 요청을 409 로 막지 않는다
   * — 보낸 목록에만 있는 일과는 문제가 아니다.
   */
  private boolean hasTodayRoutineMissingFrom(String profileId, Set<String> sent) {
    LocalDate today = LocalDate.now();
    return routineRepository.findTodayOrdered(
        profileId, List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED),
        today.atStartOfDay(), today.atTime(LocalTime.MAX))
      .stream()
      .filter(routine -> !routine.getSteps().isEmpty())
      .anyMatch(routine -> !sent.contains(routine.getId()));
  }

  /**
   * 일과 안의 행동 단계 순서를 바꾼다.
   *
   * <p>{@link #reorder}(일과 순서)와 같은 방식이다 — <b>화면에 보이는 전체를 그대로
   * 받아 통째로 다시 매긴다.</b> 부분 갱신은 두 곳에서 동시에 바꿀 때 뒤엉킨다.
   *
   * <p><b>하나라도 어긋나면 아무것도 바꾸지 않는다.</b> 절반만 반영되면 화면과 서버가
   * 어긋나 더 나쁘다 — 보호자는 자기가 바꾼 순서를 봤는데 이룸이 휴대폰에는 다른
   * 차례로 뜬다.
   */
  @Transactional
  public void reorderSteps(Caller caller, String routineId, List<String> stepIds) {
    if (stepIds == null || stepIds.isEmpty()) {
      return;
    }
    // 같은 값이 두 번 오면 번호가 겹쳐 순서가 뒤엉킨다.
    if (new HashSet<>(stepIds).size() != stepIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Routine routine = getRoutineFor(caller, routineId, RoutineAction.EDIT);
    List<RoutineStep> steps = routine.getSteps();

    // 일부만 보내면 빠진 단계의 차례가 어디인지 알 수 없다. 전체가 와야 한다.
    if (steps.size() != stepIds.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }

    Map<String, RoutineStep> byId = new HashMap<>();
    for (RoutineStep step : steps) {
      byId.put(step.getId(), step);
    }
    // 남의 일과 단계나 없는 단계가 섞이면 멈춘다.
    for (String stepId : stepIds) {
      if (!byId.containsKey(stepId)) {
        throw new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND);
      }
    }

    for (int i = 0; i < stepIds.size(); i++) {
      byId.get(stepIds.get(i)).setStepOrder(i + 1);
    }
  }

  /**
   * 일과 하나를 꺼내며 이 요청자가 이 동작을 해도 되는지 묻는다 (다중 보호자 명세 4-2).
   *
   * <p>판단은 {@link ProfileAccessGuard} 한 곳에서 한다. 예전에는 "프로필의 주인 = 요청자"를 여기서 직접
   * 비교했는데, 보호자가 여럿이 되면 주인이 하나가 아니고 이룸이 휴대폰은 연결로 이룸이가 정해진다.
   * 어떤 상태 검사보다 먼저 부른다 — 거절될 요청이 무엇도 바꾸지 않게.
   */
  private Routine getRoutineFor(Caller caller, String routineId, RoutineAction action) {
    Routine routine = routineRepository.findById(routineId)
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_NOT_FOUND));
    profileAccessGuard.checkRoutine(caller, routine.getProfile().getId(), routine.getCreatedBy(), action);
    return routine;
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
        return entity;
      })
      .toList();
  }
}
