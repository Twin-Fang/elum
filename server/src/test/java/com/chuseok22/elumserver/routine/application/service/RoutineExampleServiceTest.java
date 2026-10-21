package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.ProfileAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineResponse;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExample;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCatalog;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutineExampleCategory;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import java.time.LocalDate;
import java.util.List;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

@ExtendWith(MockitoExtension.class)
class RoutineExampleServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private RoutineRepository routineRepository;
  @Mock
  private ProfileAccessGuard profileAccessGuard;
  @Mock
  private EnabledLocales enabledLocales;
  @Mock
  private RoutineStepSpeechQueue routineStepSpeechQueue;

  @InjectMocks
  private RoutineExampleService routineExampleService;

  private final Profile profile = new Profile();

  @BeforeEach
  void setUp() {
    profile.setId("profile-1");
    lenient().when(profileAccessGuard.profileFor(eq(GUARDIAN), any(ProfileAction.class))).thenReturn(profile);
    lenient().when(enabledLocales.resolveContentLocale(any())).thenReturn(AppLocale.KO);
    lenient().when(routineRepository.existsByProfileIdAndIsExampleTrue("profile-1")).thenReturn(false);
    lenient().when(routineRepository.maxDisplayOrder("profile-1")).thenReturn(5);
    lenient().when(routineRepository.saveAll(anyList())).thenAnswer(invocation -> invocation.getArgument(0));
  }

  @Test
  @DisplayName("분류마다 예시 2개를 CONFIRMED · 오늘 날짜로 만든다 — 아니면 이룸이 기기에 안 보인다")
  void createsTwoConfirmedExamplesPerCategory() {
    List<RoutineResponse> responses =
      routineExampleService.create(GUARDIAN, List.of("MORNING_EVENING", "SCHOOL_STUDY"));

    List<Routine> saved = captureSaved();
    assertThat(saved).hasSize(4);
    assertThat(responses).hasSize(4).allMatch(RoutineResponse::isExample);

    RoutineExample first = RoutineExampleCatalog.of(RoutineExampleCategory.MORNING_EVENING).get(0);
    Routine morning = saved.get(0);
    assertThat(morning.getTitle()).isEqualTo(first.titleKo());
    assertThat(morning.getStatus()).isEqualTo(RoutineStatus.CONFIRMED);
    assertThat(morning.getIsExample()).isTrue();
    assertThat(morning.getCreatedBy()).isEqualTo("member-1");
    assertThat(morning.getProfile()).isSameAs(profile);
    assertThat(morning.getScheduledAt()).isEqualTo(LocalDate.now().atTime(first.scheduledTime()));
    assertThat(morning.getRawInputText()).isEqualTo(first.titleKo());
    assertThat(morning.getSteps()).extracting(RoutineStep::getTitle)
      .containsExactlyElementsOf(first.steps().stream().map(s -> s.textKo()).toList());
    assertThat(morning.getSteps()).extracting(RoutineStep::getPictogramId)
      .containsExactlyElementsOf(first.steps().stream().map(s -> s.pictogramId()).toList());
    assertThat(morning.getSteps()).extracting(RoutineStep::getExampleImageId)
      .containsExactlyElementsOf(first.steps().stream().map(s -> s.exampleImageId()).toList());
    assertThat(morning.getSteps()).extracting(RoutineStep::getStepOrder).containsExactly(1, 2, 3, 4, 5);
    // description 은 NOT NULL 컬럼 — 비면 저장이 실패한다
    assertThat(morning.getSteps()).extracting(RoutineStep::getDescription)
      .containsExactlyElementsOf(first.steps().stream().map(s -> s.textKo()).toList());
    // 기존 일과 뒤로, 카탈로그 순서대로
    assertThat(saved).extracting(Routine::getDisplayOrder).containsExactly(6, 7, 8, 9);
    verify(routineStepSpeechQueue).enqueueAfterCommit(anyList());
  }

  @Test
  @DisplayName("콘텐츠 언어가 한국어면 한국어 문장 · KO")
  void koreanContentLocaleUsesKoreanText() {
    routineExampleService.create(GUARDIAN, List.of("OUTSIDE"));

    Routine bus = captureSaved().get(0);
    assertThat(bus.getLanguage()).isEqualTo(AppLocale.KO);
    assertThat(bus.getTitle()).isEqualTo("버스 타기");
  }

  @Test
  @DisplayName("콘텐츠 언어가 한국어가 아니면 영어 문장 · EN — 일본어 일과에 영어 글이 들어가 음성이 어긋나지 않게")
  void otherContentLocaleUsesEnglishText() {
    when(enabledLocales.resolveContentLocale(any())).thenReturn(AppLocale.JA);

    routineExampleService.create(GUARDIAN, List.of("OUTSIDE"));

    Routine bus = captureSaved().get(0);
    assertThat(bus.getLanguage()).isEqualTo(AppLocale.EN);
    assertThat(bus.getTitle()).isEqualTo("Taking the bus");
    assertThat(bus.getSteps().get(0).getTitle()).isEqualTo("Walk to the bus stop");
  }

  @Test
  @DisplayName("이미 예시가 있으면 아무것도 만들지 않는다 — 재시도·재설치로 두 벌 생기지 않게")
  void secondCallCreatesNothing() {
    when(routineRepository.existsByProfileIdAndIsExampleTrue("profile-1")).thenReturn(true);

    List<RoutineResponse> responses = routineExampleService.create(GUARDIAN, List.of("OUTSIDE"));

    assertThat(responses).isEmpty();
    verify(routineRepository, never()).saveAll(anyList());
  }

  @Test
  @DisplayName("빈 목록 · 모르는 분류 코드는 400")
  void rejectsEmptyOrUnknownCategory() {
    assertThatThrownBy(() -> routineExampleService.create(GUARDIAN, List.of()))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
    assertThatThrownBy(() -> routineExampleService.create(GUARDIAN, null))
      .isInstanceOf(CustomException.class);
    assertThatThrownBy(() -> routineExampleService.create(GUARDIAN, List.of("OUTSIDE", "FOO")))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE);
    verify(routineRepository, never()).saveAll(anyList());
  }

  @Test
  @DisplayName("같은 분류를 두 번 보내도 한 번만 만든다")
  void duplicateCategoryCodesCreatedOnce() {
    routineExampleService.create(GUARDIAN, List.of("OUTSIDE", "OUTSIDE"));

    assertThat(captureSaved()).hasSize(2);
  }

  @SuppressWarnings("unchecked")
  private List<Routine> captureSaved() {
    ArgumentCaptor<List<Routine>> captor = ArgumentCaptor.forClass(List.class);
    verify(routineRepository).saveAll(captor.capture());
    return captor.getValue();
  }
}
