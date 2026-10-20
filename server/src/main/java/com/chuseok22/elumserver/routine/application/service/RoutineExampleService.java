package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExample;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCatalog;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleStep;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 온보딩 예시 일과 (#803): 고른 분류의 예시를 실제 일과로 생성
 * AI·크레딧·보유 한도 없음. 이룸이 프로필당 한 벌만 (두 번째 요청은 빈 목록)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineExampleService {

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final EnabledLocales enabledLocales;
  private final RoutineStepSpeechQueue routineStepSpeechQueue;

  /**
   * 예시 일과 생성: 검증 > 이미 만들었는지 확인 > 분류별 생성 > 저장
   */
  @Transactional
  public List<RoutineResponse> create(Caller caller, List<String> categoryCodes) {
    Set<RoutineExampleCategory> categories = toCategories(categoryCodes);
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);

    // 이미 있으면 그대로 (재시도·재설치 공통)
    if (routineRepository.existsByProfileIdAndIsExampleTrue(profile.getId())) {
      log.info("[routine example] skipped : already created, profileId={}", profile.getId());
      return List.of();
    }

    // 문장 언어: 한국어 화면이면 ko, 그 외는 en (ja·zh·es 문장 없음)
    AppLocale language = enabledLocales.resolveContentLocale(CurrentLocale.get()) == AppLocale.KO
      ? AppLocale.KO
      : AppLocale.EN;
    int nextDisplayOrder = routineRepository.maxDisplayOrder(profile.getId()) + 1;

    List<Routine> routines = new ArrayList<>();
    for (RoutineExampleCategory category : categories) {
      for (RoutineExample example : RoutineExampleCatalog.of(category)) {
        routines.add(toRoutine(example, caller.memberId(), profile, language, nextDisplayOrder++));
      }
    }

    List<Routine> saved = routineRepository.saveAll(routines);
    routineStepSpeechQueue.enqueueAfterCommit(
      saved.stream().flatMap(routine -> routine.getSteps().stream()).map(RoutineStep::getId).toList());
    log.info("[routine example] created : profileId={}, categories={}, routines={}",
      profile.getId(), categories, saved.size());
    return saved.stream().map(RoutineResponse::from).toList();
  }

  /**
   * 분류 코드 목록 > 분류 집합 (요청 순서 유지, 중복 제거). 빈 목록·모르는 코드 > 400
   */
  private Set<RoutineExampleCategory> toCategories(List<String> categoryCodes) {
    if (categoryCodes == null || categoryCodes.isEmpty()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    Set<RoutineExampleCategory> categories = new LinkedHashSet<>();
    for (String code : categoryCodes) {
      RoutineExampleCategory category = RoutineExampleCategory.fromCode(code);
      if (category == null) {
        throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
      }
      categories.add(category);
    }
    return categories;
  }

  /**
   * 예시 1개 > 오늘 할 CONFIRMED 일과 (RoutineService.duplicate 와 같은 필드 구성)
   */
  private Routine toRoutine(RoutineExample example, String memberId, Profile profile, AppLocale language,
    int displayOrder) {
    boolean isKorean = language == AppLocale.KO;
    String title = isKorean ? example.titleKo() : example.titleEn();

    Routine routine = new Routine();
    routine.setProfile(profile);
    routine.setCreatedBy(memberId);
    // 보호자 원문이 없어 제목으로 채움 (NOT NULL)
    routine.setRawInputText(title);
    routine.setSanitizedInputText(title);
    routine.setTitle(title);
    routine.setLanguage(language);
    routine.setScheduledAt(LocalDate.now().atTime(example.scheduledTime()));
    // 보호자가 고른 예시라 승인 없이 바로 이룸이에게 보임
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setDisplayOrder(displayOrder);
    routine.setIsExample(true);

    List<RoutineStep> steps = new ArrayList<>();
    int order = 1;
    for (RoutineExampleStep exampleStep : example.steps()) {
      RoutineStep step = new RoutineStep();
      step.setRoutine(routine);
      step.setStepOrder(order++);
      String text = isKorean ? exampleStep.textKo() : exampleStep.textEn();
      step.setTitle(text);
      // 카드 문장이 한 줄뿐이라 설명도 같은 문장 (NOT NULL)
      step.setDescription(text);
      step.setPictogramId(exampleStep.pictogramId());
      step.setExampleImageId(exampleStep.exampleImageId());
      step.setCompleted(false);
      steps.add(step);
    }
    routine.setSteps(steps);
    return routine;
  }
}
