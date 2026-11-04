package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineMemoryResponse;
import com.chuseok22.elumserver.routine.core.RoutineMemoryLine;
import com.chuseok22.elumserver.routine.core.RoutineMemorySafetyFilter;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemory;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Optional;
import java.util.Set;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 보호자의 AI 메모 관리 (#1082): 보기, 줄 통째 바꾸기, 켜기/끄기, 모두 지우기, 이룸이 정리 시 지우기
 * 권한: 이룸이를 돌보는 보호자(MANAGE) + Pro(ROUTINE_MEMORY). Free 는 보기만 (빈 응답)
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineMemoryService {

  /// 지운 AI 줄 기억 최대 수 (같은 줄을 다시 만들지 않게)
  static final int MAX_DISMISSED_LINES = 20;

  private final ProfileAccessGuard profileAccessGuard;
  private final EntitlementService entitlementService;
  private final RoutineMemoryRepository routineMemoryRepository;
  private final RoutineMemoryRows routineMemoryRows;
  private final RoutineRepository routineRepository;

  /// 보기: Free > 빈 응답(available=false) / 행 없음 > 켜짐·빈 줄
  public RoutineMemoryResponse get(Caller caller) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    if (!isAvailable(caller)) {
      return RoutineMemoryResponse.unavailable();
    }
    return toResponse(routineMemoryRepository.findByProfileId(profile.getId()));
  }

  /**
   * 줄 통째 바꾸기: 권한 > 검증(10줄·60자·금지 낱말) > 출처 정하기(같은 AI 줄은 AI, 그 외 GUARDIAN) > 빠진 AI 줄은 지운 줄로 기억
   * 화면에 보이는 전체를 받음 — 줄 하나 고치기·지우기도 이 한 경로
   */
  @Transactional
  public RoutineMemoryResponse replaceLines(Caller caller, List<String> requestedLines) {
    Profile profile = requireAvailableProfile(caller);
    List<String> texts = validatedTexts(requestedLines);

    RoutineMemory memory = routineMemoryRows.findOrCreate(profile.getId());
    List<RoutineMemoryLine> before = RoutineMemoryJson.readLines(memory.getLines());
    Set<String> aiTexts = new LinkedHashSet<>();
    before.stream().filter(line -> line.source() == RoutineMemoryLine.Source.AI).forEach(line -> aiTexts.add(line.text()));

    List<RoutineMemoryLine> after = texts.stream()
      .map(text -> new RoutineMemoryLine(text,
        aiTexts.contains(text) ? RoutineMemoryLine.Source.AI : RoutineMemoryLine.Source.GUARDIAN))
      .toList();
    List<String> removedAiTexts = aiTexts.stream().filter(text -> !texts.contains(text)).toList();

    memory.setLines(RoutineMemoryJson.writeLines(after));
    memory.setDismissedLines(RoutineMemoryJson.writeTexts(
      rememberDismissed(RoutineMemoryJson.readTexts(memory.getDismissedLines()), removedAiTexts)));
    log.info("[routine memory] lines replaced : profileId={}, lines={}, dismissed={}",
      profile.getId(), after.size(), removedAiTexts.size());
    return toResponse(Optional.of(memory));
  }

  /// 켜기/끄기. 끄면 일과 만들기에 넣지 않고 새 확정도 배우지 않음 (줄은 남음)
  @Transactional
  public RoutineMemoryResponse setEnabled(Caller caller, Boolean enabled) {
    if (enabled == null) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    Profile profile = requireAvailableProfile(caller);
    RoutineMemory memory = routineMemoryRows.findOrCreate(profile.getId());
    memory.setEnabled(enabled);
    log.info("[routine memory] enabled changed : profileId={}, enabled={}", profile.getId(), enabled);
    return toResponse(Optional.of(memory));
  }

  /// 모두 지우기: 줄·지운 줄 비움 + 이 이룸이 일과의 AI 처음 카드 스냅샷 비움 (예시·다음 갱신에서도 빠짐). 켜짐 상태는 그대로
  @Transactional
  public RoutineMemoryResponse clear(Caller caller) {
    Profile profile = requireAvailableProfile(caller);
    RoutineMemory memory = routineMemoryRows.findOrCreate(profile.getId());
    memory.setLines(RoutineMemoryJson.writeLines(List.of()));
    memory.setDismissedLines(RoutineMemoryJson.writeTexts(List.of()));
    memory.setLastBuiltAt(null);
    int clearedRoutineCount = routineRepository.clearAiDraftCardsOfProfile(profile.getId(), LocalDateTime.now());
    log.info("[routine memory] cleared : profileId={}, clearedRoutines={}", profile.getId(), clearedRoutineCount);
    return toResponse(Optional.of(memory));
  }

  /**
   * 이룸이 정리(보호자 나가기·이룸이 삭제·탈퇴): 메모 행 지움 + 남은 일과 스냅샷 비움 (부르는 쪽 트랜잭션)
   * 나간 보호자가 고친 카드에서 배운 줄이 남은 보호자 메모에 섞여 남지 않게, 함께 돌보던 이룸이도 메모를 지움
   */
  @Transactional
  public void forgetProfile(String profileId) {
    int deletedMemoryCount = routineMemoryRepository.deleteByProfileId(profileId);
    int clearedRoutineCount = routineRepository.clearAiDraftCardsOfProfile(profileId, LocalDateTime.now());
    if (deletedMemoryCount > 0 || clearedRoutineCount > 0) {
      log.info("[routine memory] forgotten : profileId={}, memories={}, clearedRoutines={}",
        profileId, deletedMemoryCount, clearedRoutineCount);
    }
  }

  /// 요청 줄 검증: 빈 줄 버림 > 같은 줄 하나로 > 10줄·60자 넘으면 400 > 금지 낱말·연락처면 400 (NOT_ALLOWED)
  static List<String> validatedTexts(List<String> requestedLines) {
    if (requestedLines == null) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<String> texts = requestedLines.stream()
      .filter(line -> line != null && !line.isBlank())
      .map(String::trim)
      .distinct()
      .toList();
    if (texts.size() > RoutineMemoryLine.MAX_LINES
      || texts.stream().anyMatch(text -> text.length() > RoutineMemorySafetyFilter.MAX_LINE_LENGTH)) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    if (texts.stream().anyMatch(text -> !RoutineMemorySafetyFilter.isAllowed(text))) {
      throw new CustomException(ErrorCode.ROUTINE_MEMORY_LINE_NOT_ALLOWED);
    }
    return texts;
  }

  /// 새로 지운 줄을 앞에, 최근 20개만
  static List<String> rememberDismissed(List<String> dismissed, List<String> newlyDismissed) {
    List<String> combined = new ArrayList<>(newlyDismissed);
    dismissed.stream().filter(text -> !combined.contains(text)).forEach(combined::add);
    return combined.stream().limit(MAX_DISMISSED_LINES).toList();
  }

  private Profile requireAvailableProfile(Caller caller) {
    Profile profile = profileAccessGuard.profileFor(caller, ProfileAction.MANAGE);
    if (!isAvailable(caller)) {
      throw new CustomException(ErrorCode.ROUTINE_MEMORY_PRO_REQUIRED);
    }
    return profile;
  }

  private boolean isAvailable(Caller caller) {
    return entitlementService.isAllowed(caller.memberId(), Entitlement.ROUTINE_MEMORY);
  }

  /// 저장된 순서 그대로 (보호자가 보낸 순서, AI 갱신 뒤에는 보호자 줄 먼저)
  private static RoutineMemoryResponse toResponse(Optional<RoutineMemory> memory) {
    if (memory.isEmpty()) {
      return new RoutineMemoryResponse(true, true, List.of(), null);
    }
    List<RoutineMemoryResponse.LineResponse> lines = RoutineMemoryJson.readLines(memory.get().getLines()).stream()
      .map(line -> new RoutineMemoryResponse.LineResponse(line.text(), line.source()))
      .toList();
    return new RoutineMemoryResponse(true, memory.get().isEnabled(), lines, memory.get().getLastBuiltAt());
  }
}
