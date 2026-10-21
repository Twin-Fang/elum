package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.routine.application.dto.response.RecentRewardResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineSuggestionCatalog;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.LocalTime;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Optional;
import java.util.Collection;
import java.util.Map;
import java.util.stream.Collectors;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/// 일과 조회. 쓰지 않으므로 클래스 전체가 읽기 전용 트랜잭션이다.
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class RoutineQueryService {

  /// 보상 설정 화면 입력칸 아래에 띄울 "최근에 정한 보상" 개수.
  /// 시안(1082:4801)이 칩을 2·2 넷으로 그린다 — 셋이면 둘째 줄이 한 칸만 차 2·1 로 선다.
  /// 그 이상은 고르는 부담만 늘어난다.
  private static final int RECENT_REWARD_LIMIT = 4;

  /// 보호자 홈 "지난 일과" 노출 개수. 전부 내려주면 오늘 할 일이 묻힌다.
  private static final int PAST_ROUTINE_LIMIT = 10;

  private final RoutineRepository routineRepository;
  private final RoutineImageStorage routineImageStorage;
  private final RoutineStepSpeechStorage routineStepSpeechStorage;
  private final ProfileAccessGuard profileAccessGuard;

  /// 일과 제목 묶음 조회 (id > 제목). 크레딧 사용 내역이 일과 제목을 붙일 때 쓴다.
  /// 지워졌거나 없는 id 는 결과에 없다.
  public Map<String, String> findTitlesByIds(Collection<String> routineIds) {
    if (routineIds.isEmpty()) {
      return Map.of();
    }
    return routineRepository.findAllById(routineIds).stream()
      .collect(Collectors.toMap(Routine::getId, Routine::getTitle));
  }

  /// 일과 제목 묶음 조회 (id > 제목), 주어진 이룸이에 속한 일과만. 알림 목록이 접근 가능한 이룸이의 일과만 보이게 쓴다.
  /// 지워졌거나 다른 이룸이의 일과는 결과에 없다.
  public Map<String, String> titlesOf(Collection<String> routineIds, Collection<String> accessibleProfileIds) {
    if (routineIds.isEmpty() || accessibleProfileIds.isEmpty()) {
      return Map.of();
    }
    return routineRepository.findAllByIdInAndProfileIdIn(routineIds, accessibleProfileIds).stream()
      .collect(Collectors.toMap(Routine::getId, Routine::getTitle, (first, second) -> first));
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

  /// 보호자 홈 "지난 일과" — 오늘 이전 것만 최신순 10개.
  /// 전부 내려주면 목록이 계속 쌓여 오늘 할 일이 묻힌다.
  ///
  /// 프로필을 계정에서 떼어낸 뒤로 profileId와 memberId는 서로 다른 값이다.
  /// 여기에 memberId를 그대로 넘기고 있어서 **어떤 일과도 걸리지 않았다** —
  /// 모든 보호자에게 지난 일과가 빈 칸으로 보였다. 같은 실수를 오늘 일과에서
  /// 한 번 고쳤는데(getTodayRoutines) 이곳이 함께 고쳐지지 않았다.
  ///
  /// 보낸 일과(CONFIRMED·COMPLETED)만 준다 — 오늘 일과와 같은 기준이다.
  /// 상태를 거르지 않으면 오늘 만들다 둔 임시저장이 내일 지난 일과에 뜬다.
  public List<RoutineResponse> getPastRoutines(Caller caller) {
    return routineRepository
      .findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
        profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId(),
        List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED),
        LocalDate.now().atStartOfDay())
      .stream()
      // 일과관리 복사본은 보낸 적이 없어 지난 일과가 아니다 (#804). 개수 자르기 전에 거른다
      .filter(routine -> !routine.isLibraryOnly())
      .limit(PAST_ROUTINE_LIMIT)
      .map(RoutineResponse::from)
      .toList();
  }

  /// 보호자 홈 "임시저장" — 카드는 만들었지만 아직 아이에게 보내지 않은 일과.
  public List<RoutineResponse> getDraftRoutines(Caller caller) {
    // 임시저장은 전부 승인 전이라 이룸이 토큰에는 줄 것이 없다.
    if (caller.isElumi()) {
      return List.of();
    }
    return routineRepository
      .findAllByProfileIdAndStatusOrderByCreatedAtDesc(profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId(), RoutineStatus.PENDING_REVIEW)
      .stream()
      .map(RoutineResponse::from)
      .toList();
  }

  public RoutineResponse getRoutine(Caller caller, String routineId) {
    return RoutineResponse.from(getRoutineFor(caller, routineId, RoutineAction.VIEW));
  }

  public List<RoutineResponse> getMyRoutines(Caller caller) {
    return routineRepository.findAllByProfileId(profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId()).stream()
      // 이룸이 토큰은 승인 전 일과를 받지 않는다 — 보호자 승인 후에만 이룸이에게 노출한다.
      // 임시저장·설정이 쓰는 보호자 호출은 전체를 그대로 받는다.
      .filter(r -> !caller.isElumi() || r.getStatus() != RoutineStatus.PENDING_REVIEW)
      // 일과관리 복사본은 홈에 뜨지 않는다 — 목록은 일과관리 API 가 따로 준다 (#804)
      .filter(r -> !r.isLibraryOnly())
      .map(RoutineResponse::from)
      .toList();
  }

  /// 일과관리 목록: 보낸 상태(CONFIRMED·COMPLETED)의 원본만, 칸 순서(libraryOrder, 없으면 맨 뒤) > 최신순 (#804, #844)
  /// 보내기로 만든 일과·일과관리에서 지운 원본·임시저장은 빠진다
  public List<RoutineResponse> getLibraryRoutines(Caller caller) {
    return routineRepository
      .findLibraryOriginals(profileAccessGuard.profileFor(caller, ProfileAction.VIEW).getId(),
        List.of(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED))
      .stream()
      // 안정 정렬 — 같은 번호·번호 없음은 쿼리의 최신순 유지
      .sorted(Comparator.comparing(Routine::getLibraryOrder, Comparator.nullsLast(Comparator.naturalOrder())))
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
    // 요청 언어의 목록. 한 벌이 갖춰지지 않은 언어는 en → ko 로 대체된다. 헤더 없으면 ALL(ko) 그대로다.
    List<RoutineSuggestionResponse> catalog = RoutineSuggestionCatalog.forLocale(CurrentLocale.get());
    if (count < 1 || count > catalog.size()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    List<RoutineSuggestionResponse> pool = new ArrayList<>(catalog);
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
   * 단계 음성 조회: 권한 확인 > 열쇠 > WAV. 아직 없으면 빈 값 (#675)
   */
  public Optional<StepSpeech> getStepSpeech(Caller caller, String routineId, String stepId) {
    Routine routine = getRoutineFor(caller, routineId, RoutineAction.VIEW);
    RoutineStep targetStep = routine.getSteps().stream()
      .filter(step -> step.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
    String speechKey = targetStep.getSpeechPath();
    if (speechKey == null) {
      return Optional.empty();
    }
    return routineStepSpeechStorage.read(speechKey).map(wav -> new StepSpeech(speechKey, wav));
  }

  /// 단계 음성: 열쇠(앱 캐시 이름·ETag), WAV
  public record StepSpeech(String speechKey, byte[] wav) {

  }

  private Routine getRoutineFor(Caller caller, String routineId, RoutineAction action) {
    return RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, action);
  }
}
