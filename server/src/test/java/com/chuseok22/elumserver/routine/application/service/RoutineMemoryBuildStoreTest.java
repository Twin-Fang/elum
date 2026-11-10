package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.core.RoutineCardText;
import com.chuseok22.elumserver.routine.core.RoutineMemoryLine;
import com.chuseok22.elumserver.routine.infrastructure.ai.RoutineMemoryAi;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineMemory;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineMemoryRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * AI 메모 갱신의 준비·반영 (#1082). 깨지면 원문이 AI 로 가거나, 진단 줄이 저장되거나, 보호자 줄이 덮이거나, 끈 메모가 계속 배운다
 */
@ExtendWith(MockitoExtension.class)
class RoutineMemoryBuildStoreTest {

  private static final String PROFILE_ID = "profile-1";
  private static final String RAW_INPUT = "원문-보호자가-적은-글";
  private static final ZoneId ZONE = ZoneId.of("Asia/Seoul");
  private static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 5, 12, 0);

  @Mock private RoutineRepository routineRepository;
  @Mock private RoutineMemoryRepository routineMemoryRepository;
  @Mock private EntitlementService entitlementService;
  @Mock private RoutineMemoryRows routineMemoryRows;
  private RoutineMemoryBuildStore store;

  @BeforeEach
  void setUp() {
    store = new RoutineMemoryBuildStore(routineRepository, routineMemoryRepository, entitlementService,
      routineMemoryRows, Clock.fixed(NOW.atZone(ZONE).toInstant(), ZONE));
  }

  private Routine editedRoutine(String id) {
    Routine routine = RoutinePersonalizationProviderTest.routine("손 씻기",
      List.of(new RoutineCardText("손을 씻어요", "비누로 씻어요")),
      List.of(new RoutineCardText("손을 닦아요", "비누로 닦아요")));
    routine.setId(id);
    routine.setCreatedBy("member-1");
    routine.setRawInputText(RAW_INPUT);
    routine.setSanitizedInputText(RAW_INPUT);
    Profile profile = new Profile();
    profile.setId(PROFILE_ID);
    profile.setNickname("하늘이");
    routine.setProfile(profile);
    return routine;
  }

  private void givenPending(Routine... routines) {
    when(routineRepository.findAllByProfileIdAndAiDraftCardsIsNotNullAndMemoryReflectedAtIsNullAndStatusInOrderByCreatedAtDesc(
      eq(PROFILE_ID), any())).thenReturn(List.of(routines));
  }

  @Test
  @DisplayName("준비: AI 입력에는 처음·확정 카드 글만 있고 보호자 입력 원문은 없다")
  void prepare_sendsCardsOnlyNeverRawInput() {
    Routine routine = editedRoutine("r1");
    givenPending(routine);
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_MEMORY)).thenReturn(true);

    RoutineMemoryBuildStore.BuildJob job = store.prepare(PROFILE_ID);

    String userContent = RoutineMemoryAi.toJson(job.input());
    assertThat(userContent).contains("손을 씻어요 / 비누로 씻어요", "손을 닦아요 / 비누로 닦아요");
    assertThat(userContent).doesNotContain(RAW_INPUT);
    assertThat(job.pendingRoutineIds()).containsExactly("r1");
  }

  @Test
  @DisplayName("준비: 보호자가 메모를 껐으면 AI 를 부르지 않고 반영 표시만 (꺼 둔 동안은 배우지 않음)")
  void prepare_disabledMarksReflectedWithoutJob() {
    Routine routine = editedRoutine("r1");
    givenPending(routine);
    RoutineMemory memory = new RoutineMemory();
    memory.setEnabled(false);
    when(routineMemoryRepository.findByProfileId(PROFILE_ID)).thenReturn(Optional.of(memory));

    assertThat(store.prepare(PROFILE_ID)).isNull();
    assertThat(routine.getMemoryReflectedAt()).isEqualTo(NOW);
  }

  @Test
  @DisplayName("준비: 하루 안에 이미 갱신했고 고친 일과가 5개 미만이면 미룬다 (반영 표시도 안 함)")
  void prepare_withinIntervalWaits() {
    Routine routine = editedRoutine("r1");
    givenPending(routine);
    when(entitlementService.isAllowed("member-1", Entitlement.ROUTINE_MEMORY)).thenReturn(true);
    RoutineMemory memory = new RoutineMemory();
    memory.setLastBuiltAt(NOW.minusHours(3));
    when(routineMemoryRepository.findByProfileId(PROFILE_ID)).thenReturn(Optional.of(memory));

    assertThat(store.prepare(PROFILE_ID)).isNull();
    assertThat(routine.getMemoryReflectedAt()).isNull();
  }

  @Test
  @DisplayName("반영: 보호자 줄은 앞에 그대로, AI 줄 중 진단 표현·지운 줄은 버리고 일과를 반영 표시")
  void apply_keepsGuardianLinesAndDropsForbiddenAndDismissed() {
    RoutineMemory memory = new RoutineMemory();
    memory.setLines(RoutineMemoryJson.writeLines(List.of(
      new RoutineMemoryLine("보상은 스티커예요", RoutineMemoryLine.Source.GUARDIAN),
      new RoutineMemoryLine("옛 AI 줄", RoutineMemoryLine.Source.AI))));
    memory.setDismissedLines(RoutineMemoryJson.writeTexts(List.of("카드를 크게 합쳐요")));
    when(routineMemoryRows.findOrCreate(PROFILE_ID)).thenReturn(memory);
    Routine routine = editedRoutine("r1");
    when(routineRepository.findAllById(List.of("r1"))).thenReturn(List.of(routine));
    RoutineMemoryBuildStore.BuildJob job = new RoutineMemoryBuildStore.BuildJob(
      PROFILE_ID, List.of("r1"),
      RoutineMemoryAi.MemoryInput.of(List.of(), List.of(), List.of(), List.of(), 9), "member-1", com.chuseok22.elumserver.common.locale.AppLocale.KO, "하늘이");

    List<RoutineMemoryLine> saved = store.apply(job, List.of(
      "'손을 씻어요' 대신 '손을 닦아요'라고 써요", "자폐가 있어 짧게 나눠요", "카드를 크게 합쳐요"));

    assertThat(saved).extracting(RoutineMemoryLine::text)
      .containsExactly("보상은 스티커예요", "'손을 씻어요' 대신 '손을 닦아요'라고 써요");
    assertThat(saved.get(1).source()).isEqualTo(RoutineMemoryLine.Source.AI);
    assertThat(memory.getLastBuiltAt()).isEqualTo(NOW);
    assertThat(routine.getMemoryReflectedAt()).isEqualTo(NOW);
  }

  @Test
  @DisplayName("반영: AI 가 maxLines 보다 많이 줘도 maxLines 줄까지만 저장한다 — 보호자 줄 자리가 AI 줄에 밀린다")
  void apply_cutsAiLinesAtMaxLines() {
    RoutineMemory memory = new RoutineMemory();
    when(routineMemoryRows.findOrCreate(PROFILE_ID)).thenReturn(memory);
    when(routineRepository.findAllById(List.of("r1"))).thenReturn(List.of(editedRoutine("r1")));
    RoutineMemoryBuildStore.BuildJob job = new RoutineMemoryBuildStore.BuildJob(
      PROFILE_ID, List.of("r1"),
      RoutineMemoryAi.MemoryInput.of(List.of(), List.of(), List.of(), List.of(), 2), "member-1",
      com.chuseok22.elumserver.common.locale.AppLocale.KO, "하늘이");

    List<RoutineMemoryLine> saved = store.apply(job, List.of("줄 하나예요", "줄 둘이에요", "줄 셋이에요", "줄 넷이에요"));

    assertThat(saved).extracting(RoutineMemoryLine::text).containsExactly("줄 하나예요", "줄 둘이에요");
  }

  @Test
  @DisplayName("갱신 시점: 처음이면 바로, 하루 지나면, 또는 고친 일과 5개면 하루 안이라도")
  void isBuildDue_rules() {
    RoutineMemory recent = new RoutineMemory();
    recent.setLastBuiltAt(NOW.minusHours(1));
    RoutineMemory old = new RoutineMemory();
    old.setLastBuiltAt(NOW.minusHours(25));

    assertThat(RoutineMemoryBuildStore.isBuildDue(null, 1, NOW)).isTrue();
    assertThat(RoutineMemoryBuildStore.isBuildDue(old, 1, NOW)).isTrue();
    assertThat(RoutineMemoryBuildStore.isBuildDue(recent, 1, NOW)).isFalse();
    assertThat(RoutineMemoryBuildStore.isBuildDue(recent, 5, NOW)).isTrue();
  }

}
