package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.application.service.CreditReservationService;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InOrder;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineCreationWriterTest {

  @Mock
  private ProfileRepository profileRepository;

  @Mock
  private ProfileAccessGuard profileAccessGuard;

  @Mock
  private RoutineRepository routineRepository;

  @Mock
  private CreditReservationService creditReservationService;

  @InjectMocks
  private RoutineCreationWriter writer;

  private static final Caller GUARDIAN_A = Caller.guardian("A");

  private Profile profile() {
    Profile profile = new Profile();
    profile.setId("p1");
    return profile;
  }

  @Test
  @DisplayName("E17 AI 가 만드는 사이 그 보호자가 나갔으면 저장하지 않는다 — 나간 사람의 일과가 남는다")
  void e17_guardianLeftDuringGeneration_doesNotSave() {
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.of(profile()));
    doThrow(new CustomException(ErrorCode.PROFILE_ACCESS_DENIED)).when(profileAccessGuard).requireGuardianOf("A", "p1");

    assertThatThrownBy(() -> writer.save("A", "p1", new Routine(), null, 0).routine())
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_ACCESS_DENIED);
    verify(routineRepository, never()).save(any());
  }

  @Test
  @DisplayName("E17 이룸이 행을 잠근 뒤에 관계를 확인한다 — 나가기와 차례를 맞춘다")
  void e17_locksProfileBeforeCheckingRelation() {
    Profile profile = profile();
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.of(profile));
    when(routineRepository.maxDisplayOrder("p1")).thenReturn(4);
    when(routineRepository.save(any(Routine.class))).thenAnswer(i -> i.getArgument(0));

    Routine saved = writer.save("A", "p1", new Routine(), null, 0).routine();

    InOrder order = inOrder(profileRepository, profileAccessGuard, routineRepository);
    order.verify(profileRepository).findByIdForUpdate("p1");
    order.verify(profileAccessGuard).requireGuardianOf("A", "p1");
    order.verify(routineRepository).save(saved);
    assertThat(saved.getProfile()).isSameAs(profile);
    assertThat(saved.getCreatedBy()).isEqualTo("A");
    // 순서 번호도 잠근 뒤에 매긴다 — 두 사람이 동시에 만들어도 번호가 겹치지 않는다
    assertThat(saved.getDisplayOrder()).isEqualTo(5);
  }

  @Test
  @DisplayName("E5 AI 가 만드는 사이 이룸이가 지워졌으면 PROFILE_NOT_FOUND")
  void profileRemovedDuringGeneration_notFound() {
    when(profileRepository.findByIdForUpdate("p1")).thenReturn(Optional.empty());

    assertThatThrownBy(() -> writer.save("A", "p1", new Routine(), null, 0).routine())
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_NOT_FOUND);
  }

  // --- 멱등 재요청의 저장된 일과 ---

  private Routine savedRoutine() {
    Routine routine = new Routine();
    routine.setId("r1");
    routine.setTitle("병원 다녀오기");
    routine.setProfile(profile());
    routine.setCreatedBy("A");
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    routine.setSteps(List.of());
    return routine;
  }

  @Test
  @DisplayName("같은 키로 다시 와도 그 사이 이룸이에서 나간 보호자에게는 저장된 일과를 주지 않는다")
  void loadSaved_guardianLeft_denied() {
    when(routineRepository.findById("r1")).thenReturn(Optional.of(savedRoutine()));
    doThrow(new CustomException(ErrorCode.ROUTINE_ACCESS_DENIED))
      .when(profileAccessGuard).checkRoutine(GUARDIAN_A, "p1", "A", RoutineAction.VIEW);

    assertThatThrownBy(() -> writer.loadSaved(GUARDIAN_A, "r1"))
      .isInstanceOf(CustomException.class)
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.ROUTINE_ACCESS_DENIED);
  }

  @Test
  @DisplayName("아직 연결된 보호자에게는 저장된 일과를 돌려준다 — 보기 권한으로 확인한다")
  void loadSaved_stillGuardian_returnsRoutine() {
    when(routineRepository.findById("r1")).thenReturn(Optional.of(savedRoutine()));

    assertThat(writer.loadSaved(GUARDIAN_A, "r1").id()).isEqualTo("r1");
    verify(profileAccessGuard).checkRoutine(GUARDIAN_A, "p1", "A", RoutineAction.VIEW);
  }
}
