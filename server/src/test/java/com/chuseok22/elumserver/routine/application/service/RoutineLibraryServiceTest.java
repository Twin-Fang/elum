package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineStepSpeechStorage;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 일과관리(#804): 보내기 하루 한 번 · 복사본은 홈에 안 뜸 · 지우기는 기록을 남김 · 제목 수정
@ExtendWith(MockitoExtension.class)
class RoutineLibraryServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private RoutineRepository routineRepository;
  @Mock
  private RoutineGroupMembership routineGroupMembership;
  @Mock
  private ProfileAccessGuard profileAccessGuard;
  @Mock
  private RoutineStepSpeechQueue routineStepSpeechQueue;
  @Mock
  private RoutineImageStorage routineImageStorage;
  @Mock
  private RoutineStepSpeechStorage routineStepSpeechStorage;

  @InjectMocks
  private RoutineLibraryService routineLibraryService;
  @InjectMocks
  private RoutineQueryService routineQueryService;
  @InjectMocks
  private RoutineService routineService;

  @Test
  @DisplayName("보내기는 원본 카드로 오늘 일과를 만들고 원본 ID를 남긴다 — 같은 날 두 번째는 ROUTINE_ALREADY_SENT_TODAY")
  void send_createsTodayCopy_andRejectsSecondSendSameDay() {
    Routine original = originalRoutine("routine-1", LocalDate.now().minusDays(3).atTime(9, 0));
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(original));
    when(routineRepository.existsBySourceRoutineIdAndScheduledAtBetween(eq("routine-1"), any(), any()))
      .thenReturn(false, true);
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(invocation -> invocation.getArgument(0));

    RoutineResponse response = routineLibraryService.send(GUARDIAN, "routine-1");

    assertThat(response.sourceRoutineId()).isEqualTo("routine-1");
    Routine copy = saved.getValue();
    assertThat(copy.isLibraryOnly()).isFalse();
    assertThat(copy.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(copy.getScheduledAt().toLocalDate()).isEqualTo(LocalDate.now());
    assertThat(copy.getSteps()).extracting(RoutineStep::getTitle).containsExactly("양치하기");
    assertThat(copy.getSteps()).extracting(RoutineStep::getCompleted).containsExactly(false);

    // 같은 날 다시 보내면 오늘 목록에 같은 일과가 둘 뜬다
    assertThatThrownBy(() -> routineLibraryService.send(GUARDIAN, "routine-1"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_ALREADY_SENT_TODAY);
    verify(routineRepository).save(any());
  }

  @Test
  @DisplayName("원본이 이미 오늘 일과면 보내지 않는다 / 보낸 일과는 원본이 아니라 보낼 수 없다")
  void send_rejectsOriginalOnTodayHome_andSentCopy() {
    Routine scheduledToday = originalRoutine("routine-1", LocalDate.now().atTime(9, 0));
    Routine sentCopy = originalRoutine("routine-2", LocalDate.now().minusDays(1).atTime(9, 0));
    sentCopy.setSourceRoutineId("routine-1");
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(scheduledToday));
    when(routineRepository.findById("routine-2")).thenReturn(Optional.of(sentCopy));

    assertThatThrownBy(() -> routineLibraryService.send(GUARDIAN, "routine-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_ALREADY_SENT_TODAY);
    assertThatThrownBy(() -> routineLibraryService.send(GUARDIAN, "routine-2"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_INVALID_STATUS);
    verify(routineRepository, never()).save(any());
  }

  @Test
  @DisplayName("복사하기는 일과관리에만 있는 새 원본을 만든다 — 홈 목록(전체·지난)에는 뜨지 않는다")
  void copy_createsLibraryOnlyOriginal_hiddenFromHomeLists() {
    Routine original = originalRoutine("routine-1", LocalDate.now().minusDays(3).atTime(9, 0));
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(original));
    ArgumentCaptor<Routine> saved = ArgumentCaptor.forClass(Routine.class);
    when(routineRepository.save(saved.capture())).thenAnswer(invocation -> invocation.getArgument(0));

    RoutineResponse response = routineLibraryService.copy(GUARDIAN, "routine-1");

    Routine copy = saved.getValue();
    assertThat(response.title()).isEqualTo("아침 준비 복사");
    assertThat(response.sourceRoutineId()).isNull();
    assertThat(copy.isLibraryOnly()).isTrue();
    assertThat(copy.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);

    // 홈 목록 두 곳이 복사본을 거른다 (오늘 목록은 쿼리가 거른다 — RoutineRepositoryDerivedQueryTest)
    copy.setId("routine-copy");
    copy.setScheduledAt(LocalDate.now().minusDays(1).atTime(9, 0));
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(original.getProfile());
    when(routineRepository.findAllByProfileId("profile-1")).thenReturn(List.of(original, copy));
    when(routineRepository.findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc(
      eq("profile-1"), anyList(), any(LocalDateTime.class))).thenReturn(List.of(copy, original));

    assertThat(routineQueryService.getMyRoutines(GUARDIAN)).extracting(RoutineResponse::id).containsExactly("routine-1");
    assertThat(routineQueryService.getPastRoutines(GUARDIAN)).extracting(RoutineResponse::id).containsExactly("routine-1");
  }

  @Test
  @DisplayName("일과관리 목록은 보낸 상태만 묻는다 — 임시저장은 승인 전이라 빠진다")
  void getLibraryRoutines_asksSentStatusesOnly() {
    Profile profile = profile();
    when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    when(routineRepository.findLibraryOriginals(eq("profile-1"), anyList()))
      .thenReturn(List.of(originalRoutine("routine-1", LocalDateTime.now())));

    assertThat(routineQueryService.getLibraryRoutines(GUARDIAN)).extracting(RoutineResponse::id).containsExactly("routine-1");

    ArgumentCaptor<List<RoutineStatus>> statuses = ArgumentCaptor.forClass(List.class);
    verify(routineRepository).findLibraryOriginals(eq("profile-1"), statuses.capture());
    assertThat(statuses.getValue()).containsExactlyInAnyOrder(RoutineStatus.CONFIRMED, RoutineStatus.COMPLETED);
  }

  @Test
  @DisplayName("일과관리 지우기: 기록 있는 원본은 숨기기만 하고, 기록 없는 복사본은 지운다")
  void removeFromLibrary_hidesOriginalWithHistory_deletesUntouchedCopy() {
    Routine originalWithHistory = originalRoutine("routine-1", LocalDate.now().minusDays(3).atTime(9, 0));
    originalWithHistory.getSteps().get(0).setCompleted(true);
    Routine untouchedCopy = originalRoutine("routine-2", LocalDateTime.now());
    untouchedCopy.setLibraryOnly(true);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(originalWithHistory));
    when(routineRepository.findById("routine-2")).thenReturn(Optional.of(untouchedCopy));
    when(routineRepository.existsBySourceRoutineId("routine-2")).thenReturn(false);

    routineLibraryService.removeFromLibrary(GUARDIAN, "routine-1");
    routineLibraryService.removeFromLibrary(GUARDIAN, "routine-2");

    assertThat(originalWithHistory.isLibraryHidden()).isTrue();
    verify(routineRepository, never()).delete(originalWithHistory);
    verify(routineRepository).delete(untouchedCopy);
  }

  @Test
  @DisplayName("일과관리 지우기는 만든 사람만 — 다른 보호자는 ROUTINE_NOT_CREATOR 이고 아무것도 바뀌지 않는다")
  void removeFromLibrary_nonCreator_refused() {
    Routine original = originalRoutine("routine-1", LocalDate.now().minusDays(3).atTime(9, 0));
    Caller otherGuardian = Caller.guardian("member-2");
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(original));
    doThrow(new CustomException(ErrorCode.ROUTINE_NOT_CREATOR))
      .when(profileAccessGuard).checkRoutine(otherGuardian, "profile-1", "member-1", RoutineAction.EDIT);

    assertThatThrownBy(() -> routineLibraryService.removeFromLibrary(otherGuardian, "routine-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_NOT_CREATOR);
    assertThat(original.isLibraryHidden()).isFalse();
    verify(routineRepository, never()).delete(any());
  }

  @Test
  @DisplayName("제목 수정: 앞뒤 공백을 지워 이 일과만 바꾼다 — 공백만 오면 INVALID_INPUT_VALUE")
  void rename_trimsTitle_andRejectsBlank() {
    Routine original = originalRoutine("routine-1", LocalDate.now().minusDays(3).atTime(9, 0));
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(original));

    RoutineResponse response = routineService.rename(GUARDIAN, "routine-1", "  저녁 준비  ");

    assertThat(response.title()).isEqualTo("저녁 준비");
    assertThatThrownBy(() -> routineService.rename(GUARDIAN, "routine-1", "   "))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INVALID_INPUT_VALUE);
    assertThat(original.getTitle()).isEqualTo("저녁 준비");
  }

  private Profile profile() {
    Profile profile = new Profile();
    profile.setId("profile-1");
    return profile;
  }

  /// 보낸 상태의 원본 하나 (카드 1장, 만든 사람 member-1)
  private Routine originalRoutine(String id, LocalDateTime scheduledAt) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setProfile(profile());
    routine.setCreatedBy("member-1");
    routine.setTitle("아침 준비");
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("원문");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setScheduledAt(scheduledAt);
    routine.setLanguage(AppLocale.KO);
    RoutineStep step = new RoutineStep();
    step.setId(id + "-step-1");
    step.setRoutine(routine);
    step.setStepOrder(1);
    step.setTitle("양치하기");
    step.setCompleted(false);
    routine.setSteps(new ArrayList<>(List.of(step)));
    return routine;
  }
}
