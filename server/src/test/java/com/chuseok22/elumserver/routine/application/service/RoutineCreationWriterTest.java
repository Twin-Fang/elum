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
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
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

  @InjectMocks
  private RoutineCreationWriter writer;

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

    assertThatThrownBy(() -> writer.save("A", "p1", new Routine()))
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

    Routine saved = writer.save("A", "p1", new Routine());

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

    assertThatThrownBy(() -> writer.save("A", "p1", new Routine()))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.PROFILE_NOT_FOUND);
  }
}
