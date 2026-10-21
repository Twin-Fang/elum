package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.atLeastOnce;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.notification.core.event.RoutineSentEvent;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineGroupResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineGroup;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineGroupRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Collection;
import java.util.Comparator;
import java.util.List;
import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.context.ApplicationEventPublisher;

/// 일과관리 묶음(#806): 구성원 규칙(원본만 · 한 묶음 · 2개 이상) · 풀기 · 복사 · 묶음째 보내기 · 권한
/// 저장소는 메모리 목록으로 흉내 내 묶음 구성 변화를 결과로 확인한다
@ExtendWith(MockitoExtension.class)
class RoutineGroupServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private RoutineRepository routineRepository;
  @Mock
  private RoutineGroupRepository routineGroupRepository;
  @Mock
  private ProfileAccessGuard profileAccessGuard;
  @Mock
  private RoutineStepSpeechQueue routineStepSpeechQueue;
  @Mock
  private ApplicationEventPublisher eventPublisher;

  private final List<Routine> storedRoutines = new ArrayList<>();
  private final AtomicInteger idSequence = new AtomicInteger();
  private final Profile profile = profileOf("profile-1");

  private RoutineLibraryService routineLibraryService;
  private RoutineGroupService routineGroupService;

  @BeforeEach
  void setUp() {
    RoutineGroupMembership membership = new RoutineGroupMembership(routineRepository, routineGroupRepository);
    routineLibraryService = new RoutineLibraryService(routineRepository, profileAccessGuard, routineStepSpeechQueue,
      membership, eventPublisher);
    routineGroupService = new RoutineGroupService(routineGroupRepository, routineRepository, profileAccessGuard,
      routineLibraryService, membership);

    // 메모리 저장소: 묶음 구성원 조회 · ID 조회 · 저장
    lenient().when(routineRepository.findAllByGroupIdOrderByGroupOrderAsc(anyString())).thenAnswer(invocation ->
      storedRoutines.stream()
        .filter(routine -> invocation.getArgument(0).equals(routine.getGroupId()))
        .sorted(Comparator.comparing(Routine::getGroupOrder))
        .toList());
    lenient().when(routineRepository.findAllById(any())).thenAnswer(invocation -> {
      Collection<String> ids = invocation.getArgument(0);
      return storedRoutines.stream().filter(routine -> ids.contains(routine.getId())).toList();
    });
    lenient().when(routineRepository.save(any(Routine.class))).thenAnswer(invocation -> {
      Routine routine = invocation.getArgument(0);
      routine.setId("saved-" + idSequence.incrementAndGet());
      storedRoutines.add(routine);
      return routine;
    });
    lenient().when(routineGroupRepository.save(any(RoutineGroup.class))).thenAnswer(invocation -> {
      RoutineGroup group = invocation.getArgument(0);
      group.setId("group-new-" + idSequence.incrementAndGet());
      return group;
    });
    lenient().when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    lenient().when(profileAccessGuard.isGuardianOf("member-1", "profile-1")).thenReturn(true);
  }

  @Test
  @DisplayName("묶음 만들기는 받은 차례를 지키고, 옮겨 온 일과의 옛 묶음이 1개만 남으면 그 묶음을 푼다")
  void create_keepsOrder_andDissolvesPreviousGroupBelowTwo() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    Routine third = original("routine-c");
    putInGroup("group-old", first, second);

    RoutineGroupResponse response = routineGroupService.create(GUARDIAN, "  아침 묶음 ", List.of("routine-c", "routine-a"));

    assertThat(response.name()).isEqualTo("아침 묶음");
    assertThat(response.routineIds()).containsExactly("routine-c", "routine-a");
    assertThat(third.getGroupOrder()).isZero();
    assertThat(first.getGroupId()).isEqualTo(response.id());
    assertThat(first.getGroupOrder()).isEqualTo(1);
    // 옛 묶음에 하나만 남아 풀림 — 일과는 지우지 않는다
    assertThat(second.getGroupId()).isNull();
    verify(routineGroupRepository).deleteById("group-old");
    verify(routineRepository, never()).delete(any());
  }

  @Test
  @DisplayName("묶음 만들기 거절: 2개 미만 TOO_SMALL · 보낸 일과/임시저장/다른 이룸이 일과 INVALID_MEMBER · 이름 13자 INVALID_INPUT_VALUE")
  void create_rejectsTooSmall_invalidMembers_andBadName() {
    original("routine-a");
    original("routine-b").setSourceRoutineId("routine-a");
    original("routine-c").setStatus(RoutineStatus.PENDING_REVIEW);
    original("routine-d").setProfile(profileOf("profile-2"));
    original("routine-e");

    assertCreateFails(List.of("routine-a"), ErrorCode.ROUTINE_GROUP_TOO_SMALL);
    assertCreateFails(List.of("routine-a", "routine-b"), ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
    assertCreateFails(List.of("routine-a", "routine-c"), ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
    assertCreateFails(List.of("routine-a", "routine-d"), ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
    assertCreateFails(List.of("routine-a", "missing"), ErrorCode.ROUTINE_GROUP_INVALID_MEMBER);
    assertThatThrownBy(() -> routineGroupService.create(GUARDIAN, "가".repeat(13), List.of("routine-a", "routine-e")))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.INVALID_INPUT_VALUE);
    verify(routineGroupRepository, never()).save(any());
  }

  @Test
  @DisplayName("구성 바꾸기는 빠진 일과를 내보내고 새 차례로 줄 세운다 — 1개로 줄이면 TOO_SMALL")
  void replaceRoutines_reordersAndRemoves_rejectsTooSmall() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    Routine third = original("routine-c");
    when(routineGroupRepository.findById("group-1")).thenReturn(Optional.of(group("group-1", "아침")));
    putInGroup("group-1", first, second, third);

    RoutineGroupResponse response = routineGroupService.replaceRoutines(GUARDIAN, "group-1",
      List.of("routine-c", "routine-a"));

    assertThat(response.routineIds()).containsExactly("routine-c", "routine-a");
    assertThat(third.getGroupOrder()).isZero();
    assertThat(first.getGroupOrder()).isEqualTo(1);
    assertThat(second.getGroupId()).isNull();
    assertThatThrownBy(() -> routineGroupService.replaceRoutines(GUARDIAN, "group-1", List.of("routine-c")))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_GROUP_TOO_SMALL);
    assertThat(third.getGroupId()).isEqualTo("group-1");
  }

  @Test
  @DisplayName("묶음 풀기는 묶음만 지우고 일과는 남긴다")
  void delete_ungroupsWithoutDeletingRoutines() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    when(routineGroupRepository.findById("group-1")).thenReturn(Optional.of(group("group-1", "아침")));
    putInGroup("group-1", first, second);

    routineGroupService.delete(GUARDIAN, "group-1");

    assertThat(first.getGroupId()).isNull();
    assertThat(second.getGroupOrder()).isNull();
    verify(routineGroupRepository).deleteById("group-1");
    verify(routineRepository, never()).delete(any());
  }

  @Test
  @DisplayName("묶음 만들기는 구성원 중 가장 앞 칸 자리를 묶음이 받고 낱개 칸 자리는 비운다 — 자리를 정한 일과가 없으면 맨 뒤")
  void create_takesSmallestLibraryOrder_orAppendsAtEnd() {
    Routine first = original("routine-a");
    first.setLibraryOrder(5);
    Routine second = original("routine-b");
    second.setLibraryOrder(2);
    Routine third = original("routine-c");
    Routine fourth = original("routine-d");
    when(routineGroupRepository.maxDisplayOrder("profile-1")).thenReturn(3);
    when(routineRepository.maxLibraryOrder("profile-1")).thenReturn(7);

    RoutineGroup createdByOrder = createdGroupOf(List.of("routine-a", "routine-b"));
    RoutineGroup createdAtEnd = createdGroupOf(List.of("routine-c", "routine-d"));

    assertThat(createdByOrder.getDisplayOrder()).isEqualTo(2);
    assertThat(first.getLibraryOrder()).isNull();
    assertThat(second.getLibraryOrder()).isNull();
    // 묶음 칸 3, 낱개 칸 7 중 큰 쪽 다음
    assertThat(createdAtEnd.getDisplayOrder()).isEqualTo(8);
    assertThat(third.getLibraryOrder()).isNull();
    assertThat(fourth.getLibraryOrder()).isNull();
  }

  @Test
  @DisplayName("묶음 풀기는 풀린 일과가 묶음이 있던 칸 자리를 이어받는다 — 1개만 남아 풀릴 때도 같다")
  void delete_andDissolveBelowTwo_freedRoutinesTakeGroupPosition() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    Routine lonelyRemaining = original("routine-c");
    Routine leaving = original("routine-d");
    RoutineGroup folder = group("group-1", "아침");
    folder.setDisplayOrder(4);
    RoutineGroup shrinking = group("group-2", "저녁");
    shrinking.setDisplayOrder(6);
    when(routineGroupRepository.findById("group-1")).thenReturn(Optional.of(folder));
    when(routineGroupRepository.findById("group-2")).thenReturn(Optional.of(shrinking));
    putInGroup("group-1", first, second);
    putInGroup("group-2", lonelyRemaining, leaving);
    when(routineRepository.findById("routine-d")).thenReturn(Optional.of(leaving));

    routineGroupService.delete(GUARDIAN, "group-1");
    routineLibraryService.removeFromLibrary(GUARDIAN, "routine-d");

    assertThat(first.getLibraryOrder()).isEqualTo(4);
    assertThat(second.getLibraryOrder()).isEqualTo(4);
    assertThat(lonelyRemaining.getLibraryOrder()).isEqualTo(6);
  }

  @Test
  @DisplayName("묶음 복사: 이름에만 '복사'(12자 안, 원래 이름 쪽을 자름) · 일과는 제목 그대로 일과관리 전용 복사본 · 같은 차례")
  void copy_copiesMembersAsLibraryOnly_andSuffixesGroupName() {
    Routine first = original("routine-a");
    first.setTitle("양치");
    Routine second = original("routine-b");
    second.setTitle("세수");
    when(routineGroupRepository.findById("group-1")).thenReturn(Optional.of(group("group-1", "가나다라마바사아자차카")));
    putInGroup("group-1", first, second);

    RoutineGroupResponse response = routineGroupService.copy(GUARDIAN, "group-1");

    assertThat(response.name()).isEqualTo("가나다라마바사아자 복사");
    assertThat(response.id()).isNotEqualTo("group-1");
    List<Routine> copies = storedMembersOf(response.id());
    assertThat(copies).extracting(Routine::getTitle).containsExactly("양치", "세수");
    assertThat(copies).allSatisfy(copy -> {
      assertThat(copy.isLibraryOnly()).isTrue();
      assertThat(copy.getSourceRoutineId()).isNull();
    });
    assertThat(response.routineIds()).containsExactlyElementsOf(copies.stream().map(Routine::getId).toList());
    // 원래 묶음은 그대로
    assertThat(first.getGroupId()).isEqualTo("group-1");
  }

  @Test
  @DisplayName("묶음째 보내기: 차례대로 오늘 일과 + 묶음 스냅샷, 오늘 보낸 일과는 건너뜀 — 모두 보냈으면 ROUTINE_ALREADY_SENT_TODAY")
  void send_createsTodayRoutinesInOrder_skipsAlreadySent() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    Routine third = original("routine-c");
    when(routineGroupRepository.findById("group-1")).thenReturn(Optional.of(group("group-1", "아침 묶음")));
    putInGroup("group-1", first, second, third);
    when(routineRepository.existsBySourceRoutineIdAndScheduledAtBetween(anyString(), any(), any()))
      .thenAnswer(invocation -> "routine-b".equals(invocation.getArgument(0)));

    List<RoutineResponse> sent = routineGroupService.send(GUARDIAN, "group-1");

    assertThat(sent).extracting(RoutineResponse::sourceRoutineId).containsExactly("routine-a", "routine-c");
    assertThat(sent).extracting(RoutineResponse::sentGroupOrder).containsExactly(0, 2);
    assertThat(sent).allSatisfy(response -> {
      assertThat(response.sentGroupId()).isEqualTo("group-1");
      assertThat(response.sentGroupName()).isEqualTo("아침 묶음");
      // 오늘 일과는 묶음 구성원이 아니다 — 일과관리 묶음에 섞이지 않게
      assertThat(response.groupId()).isNull();
      assertThat(response.scheduledAt().toLocalDate()).isEqualTo(LocalDate.now());
    });

    when(routineRepository.existsBySourceRoutineIdAndScheduledAtBetween(anyString(), any(), any())).thenReturn(true);
    assertThatThrownBy(() -> routineGroupService.send(GUARDIAN, "group-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_ALREADY_SENT_TODAY);
  }

  @Test
  @DisplayName("묶음째 보내기는 일과를 여러 개 만들어도 일과 보냄 이벤트를 첫 일과 id 로 한 번만 낸다")
  void groupSend_publishesOneRoutineSent() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    when(routineGroupRepository.findById("group-1")).thenReturn(Optional.of(group("group-1", "아침 묶음")));
    putInGroup("group-1", first, second);
    when(routineRepository.existsBySourceRoutineIdAndScheduledAtBetween(anyString(), any(), any())).thenReturn(false);

    List<RoutineResponse> sent = routineGroupService.send(GUARDIAN, "group-1");

    verify(eventPublisher, times(1)).publishEvent(any(Object.class));
    verify(eventPublisher).publishEvent(new RoutineSentEvent(sent.get(0).id(), "profile-1", "member-1"));
  }

  @Test
  @DisplayName("일과관리에서 지운 일과는 묶음에서 빠지고, 1개만 남은 묶음은 풀린다")
  void removeFromLibrary_dissolvesGroupBelowTwo() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    putInGroup("group-1", first, second);
    when(routineRepository.findById("routine-a")).thenReturn(Optional.of(first));

    routineLibraryService.removeFromLibrary(GUARDIAN, "routine-a");

    assertThat(first.isLibraryHidden()).isTrue();
    assertThat(first.getGroupId()).isNull();
    assertThat(second.getGroupId()).isNull();
    verify(routineGroupRepository).deleteById("group-1");
  }

  @Test
  @DisplayName("권한: 이룸이 휴대폰은 DEVICE_LINK_FORBIDDEN_FOR_ELUMI, 다른 이룸이 묶음·없는 묶음은 ROUTINE_GROUP_NOT_FOUND")
  void authorization_elumiAndOtherProfile_refused() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    when(routineGroupRepository.findById("group-1")).thenReturn(Optional.of(group("group-1", "아침")));
    putInGroup("group-1", first, second);
    Caller elumi = Caller.elumi("member-1", "link-1");
    Caller otherGuardian = Caller.guardian("member-9");

    assertThatThrownBy(() -> routineGroupService.send(elumi, "group-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    assertThatThrownBy(() -> routineGroupService.delete(otherGuardian, "group-1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_GROUP_NOT_FOUND);
    assertThatThrownBy(() -> routineGroupService.rename(GUARDIAN, "missing", "저녁"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_GROUP_NOT_FOUND);
    assertThat(first.getGroupId()).isEqualTo("group-1");
    verify(routineGroupRepository, never()).deleteById(any());
  }

  @Test
  @DisplayName("묶음 목록은 구성원을 차례대로 싣고, 다른 경로로 1개까지 줄어든 묶음은 뺀다")
  void getGroups_listsMembersInOrder_skipsShrunkGroups() {
    Routine first = original("routine-a");
    Routine second = original("routine-b");
    Routine lonely = original("routine-c");
    putInGroup("group-1", second, first);
    putInGroup("group-2", lonely);
    when(routineGroupRepository.findAllByProfileIdOrderByDisplayOrderAscCreatedAtAsc("profile-1"))
      .thenReturn(List.of(group("group-1", "아침"), group("group-2", "저녁")));
    when(routineRepository.findAllByGroupIdInOrderByGroupOrderAsc(anyCollection())).thenAnswer(invocation -> {
      Collection<String> groupIds = invocation.getArgument(0);
      return storedRoutines.stream().filter(routine -> groupIds.contains(routine.getGroupId()))
        .sorted(Comparator.comparing(Routine::getGroupOrder)).toList();
    });

    List<RoutineGroupResponse> groups = routineGroupService.getGroups(GUARDIAN);

    assertThat(groups).extracting(RoutineGroupResponse::id).containsExactly("group-1");
    assertThat(groups.get(0).routineIds()).containsExactly("routine-b", "routine-a");
  }

  private RoutineGroup createdGroupOf(List<String> routineIds) {
    RoutineGroupResponse response = routineGroupService.create(GUARDIAN, "아침", routineIds);
    ArgumentCaptor<RoutineGroup> saved = ArgumentCaptor.forClass(RoutineGroup.class);
    verify(routineGroupRepository, atLeastOnce()).save(saved.capture());
    return saved.getAllValues().stream().filter(group -> group.getId().equals(response.id())).findFirst().orElseThrow();
  }

  private void assertCreateFails(List<String> routineIds, ErrorCode expected) {
    assertThatThrownBy(() -> routineGroupService.create(GUARDIAN, "아침", routineIds))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", expected);
  }

  private List<Routine> storedMembersOf(String groupId) {
    return storedRoutines.stream().filter(routine -> groupId.equals(routine.getGroupId()))
      .sorted(Comparator.comparing(Routine::getGroupOrder)).toList();
  }

  private void putInGroup(String groupId, Routine... routines) {
    for (int order = 0; order < routines.length; order++) {
      routines[order].setGroupId(groupId);
      routines[order].setGroupOrder(order);
    }
  }

  private RoutineGroup group(String id, String name) {
    RoutineGroup group = new RoutineGroup();
    group.setId(id);
    group.setProfile(profile);
    group.setCreatedBy("member-1");
    group.setName(name);
    return group;
  }

  private static Profile profileOf(String id) {
    Profile profile = new Profile();
    profile.setId(id);
    return profile;
  }

  /// 보낸 상태의 원본 하나 (카드 1장, 사흘 전 일과) — 메모리 저장소에 넣음
  private Routine original(String id) {
    Routine routine = new Routine();
    routine.setId(id);
    routine.setProfile(profile);
    routine.setCreatedBy("member-1");
    routine.setTitle("아침 준비");
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("원문");
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setScheduledAt(LocalDate.now().minusDays(3).atTime(9, 0));
    routine.setLanguage(AppLocale.KO);
    RoutineStep step = new RoutineStep();
    step.setId(id + "-step-1");
    step.setRoutine(routine);
    step.setStepOrder(1);
    step.setTitle("양치하기");
    step.setCompleted(false);
    routine.setSteps(new ArrayList<>(List.of(step)));
    storedRoutines.add(routine);
    return routine;
  }
}
