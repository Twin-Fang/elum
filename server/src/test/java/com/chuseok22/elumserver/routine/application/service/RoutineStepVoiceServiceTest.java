package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.core.GuardianVoiceAudio;
import com.chuseok22.elumserver.routine.core.GuardianVoiceAudioFixture;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineStepRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.GuardianVoiceStorage;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;

/**
 * 보호자 목소리 (#787): Pro 문, 검사, 권한, 지우기, 이룸이 재생 조건
 * 파일 정리(GuardianVoiceFiles)는 실제 객체 + 가짜 저장소로 둬 지워졌는지를 저장소 호출로 본다
 */
@ExtendWith(MockitoExtension.class)
class RoutineStepVoiceServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");
  private static final Caller ELUMI = Caller.elumi("member-1", "link-1");
  private static final String OLD_KEY = "member-1/0f8fad5b-d9cb-469f-a165-70867728950e.m4a";
  private static final String NEW_KEY = "member-1/7c9e6679-7425-40de-944b-e07fc1f90ae7.m4a";

  @Mock private RoutineRepository routineRepository;
  @Mock private RoutineStepRepository routineStepRepository;
  @Mock private ProfileAccessGuard profileAccessGuard;
  @Mock private GuardianVoiceStorage guardianVoiceStorage;
  @Mock private EntitlementService entitlementService;

  private RoutineStepVoiceService service;

  @BeforeEach
  void setUp() {
    GuardianVoiceFiles files = new GuardianVoiceFiles(guardianVoiceStorage, routineStepRepository);
    service = new RoutineStepVoiceService(routineRepository, profileAccessGuard, guardianVoiceStorage, files,
      entitlementService);
  }

  private static MultipartFile voice(byte[] bytes) {
    return new MockMultipartFile("voice", "voice.m4a", "audio/mp4", bytes);
  }

  // ── 올리기 ────────────────────────────────────────────

  @Test
  @DisplayName("Pro 보호자가 올리면 새 열쇠로 바뀌고, 다른 카드가 안 가리키는 옛 녹음은 지운다")
  void upload_replacesKeyAndDeletesOld() {
    Routine routine = routine(OLD_KEY);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    byte[] audio = GuardianVoiceAudioFixture.m4aOfMillis(4_000);
    when(guardianVoiceStorage.save("member-1", audio)).thenReturn(NEW_KEY);
    when(routineStepRepository.existsByGuardianVoicePath(OLD_KEY)).thenReturn(false);

    RoutineStepResponse response = service.upload(GUARDIAN, "routine-1", "step-1", voice(audio));

    assertThat(response.guardianVoicePath()).isEqualTo(NEW_KEY);
    assertThat(routine.getSteps().get(0).getGuardianVoicePath()).isEqualTo(NEW_KEY);
    verify(profileAccessGuard).checkRoutine(GUARDIAN, "profile-1", "member-1", RoutineAction.EDIT);
    verify(guardianVoiceStorage).delete(OLD_KEY);
  }

  @Test
  @DisplayName("복제한 일과가 옛 녹음을 아직 가리키면 옛 파일을 지우지 않는다")
  void upload_keepsSharedOldFile() {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine(OLD_KEY)));
    when(guardianVoiceStorage.save(any(), any())).thenReturn(NEW_KEY);
    when(routineStepRepository.existsByGuardianVoicePath(OLD_KEY)).thenReturn(true);

    service.upload(GUARDIAN, "routine-1", "step-1", voice(GuardianVoiceAudioFixture.m4aOfMillis(2_000)));

    verify(guardianVoiceStorage, never()).delete(OLD_KEY);
  }

  @Test
  @DisplayName("Pro 가 아니면 403 NOT_ALLOWED, 파일을 읽거나 쓰지 않는다")
  void upload_rejectsFree() {
    Routine routine = routine(null);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    doThrow(new CustomException(Entitlement.GUARDIAN_VOICE.rejectionCode())).when(entitlementService).requireAllowed("member-1", Entitlement.GUARDIAN_VOICE);

    assertRejected(() -> service.upload(GUARDIAN, "routine-1", "step-1",
      voice(GuardianVoiceAudioFixture.m4aOfMillis(2_000))), ErrorCode.GUARDIAN_VOICE_NOT_ALLOWED);

    verifyNoInteractions(guardianVoiceStorage);
    assertThat(routine.getSteps().get(0).getGuardianVoicePath()).isNull();
  }

  @Test
  @DisplayName("1MB 초과·형식 아님·15초 초과는 저장하지 않고 거절하며 옛 녹음을 그대로 둔다")
  void upload_rejectsInvalidAudio() {
    Routine routine = routine(OLD_KEY);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertRejected(() -> service.upload(GUARDIAN, "routine-1", "step-1",
      voice(new byte[(int) GuardianVoiceAudio.MAX_BYTES + 1])), ErrorCode.GUARDIAN_VOICE_TOO_LARGE);
    assertRejected(() -> service.upload(GUARDIAN, "routine-1", "step-1",
      voice("RIFF0000WAVEfmt ".getBytes())), ErrorCode.GUARDIAN_VOICE_INVALID_TYPE);
    assertRejected(() -> service.upload(GUARDIAN, "routine-1", "step-1",
      voice(GuardianVoiceAudioFixture.m4aOfMillis(30_000))), ErrorCode.GUARDIAN_VOICE_TOO_LONG);
    assertRejected(() -> service.upload(GUARDIAN, "routine-1", "step-1",
      voice(new byte[0])), ErrorCode.GUARDIAN_VOICE_INVALID_TYPE);

    verifyNoInteractions(guardianVoiceStorage);
    assertThat(routine.getSteps().get(0).getGuardianVoicePath()).isEqualTo(OLD_KEY);
  }

  @Test
  @DisplayName("일과를 만든 보호자가 아니면(이룸이 포함) 권한 검사에서 막혀 Pro 도 묻지 않는다")
  void upload_forbiddenBeforePlanCheck() {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine(null)));
    org.mockito.Mockito.doThrow(new CustomException(ErrorCode.ROUTINE_NOT_CREATOR)).when(profileAccessGuard)
      .checkRoutine(any(), any(), any(), any());

    assertRejected(() -> service.upload(ELUMI, "routine-1", "step-1",
      voice(GuardianVoiceAudioFixture.m4aOfMillis(2_000))), ErrorCode.ROUTINE_NOT_CREATOR);

    verifyNoInteractions(entitlementService, guardianVoiceStorage);
  }

  // ── 지우기 ────────────────────────────────────────────

  @Test
  @DisplayName("지우기는 Pro 를 묻지 않고 열쇠를 비우고 파일을 지운다 (Pro 가 끝나도 지울 수 있음)")
  void delete_clearsKeyWithoutPlanCheck() {
    Routine routine = routine(OLD_KEY);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    when(routineStepRepository.existsByGuardianVoicePath(OLD_KEY)).thenReturn(false);

    RoutineStepResponse response = service.delete(GUARDIAN, "routine-1", "step-1");

    assertThat(response.guardianVoicePath()).isNull();
    assertThat(routine.getSteps().get(0).getGuardianVoicePath()).isNull();
    verify(guardianVoiceStorage).delete(OLD_KEY);
    verifyNoInteractions(entitlementService);
  }

  // ── 받기 ──────────────────────────────────────────────

  @Test
  @DisplayName("이룸이 기기: 녹음한 보호자가 Pro 면 녹음을 준다")
  void read_elumiGetsVoiceWhenOwnerIsPro() {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine(OLD_KEY)));
    when(entitlementService.isAllowed("member-1", Entitlement.GUARDIAN_VOICE)).thenReturn(true);
    when(guardianVoiceStorage.read(OLD_KEY)).thenReturn(Optional.of(new byte[] {1, 2}));

    Optional<RoutineStepVoiceService.StepVoice> voice = service.read(ELUMI, "routine-1", "step-1");

    assertThat(voice).isPresent();
    assertThat(voice.get().voiceKey()).isEqualTo(OLD_KEY);
  }

  @Test
  @DisplayName("이룸이 기기: 녹음한 보호자의 Pro 가 끝났으면 빈 값(앱은 기본 음성), 녹음은 지우지 않는다")
  void read_elumiFallsBackWhenOwnerNotPro() {
    Routine routine = routine(OLD_KEY);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));
    when(entitlementService.isAllowed("member-1", Entitlement.GUARDIAN_VOICE)).thenReturn(false);

    assertThat(service.read(ELUMI, "routine-1", "step-1")).isEmpty();
    assertThat(routine.getSteps().get(0).getGuardianVoicePath()).isEqualTo(OLD_KEY);
    verify(guardianVoiceStorage, never()).read(any());
    verify(guardianVoiceStorage, never()).delete(any());
  }

  @Test
  @DisplayName("보호자 기기는 Pro 가 끝나도 자기 녹음을 들을 수 있다 (지우기 전 확인)")
  void read_guardianAlwaysGetsVoice() {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine(OLD_KEY)));
    when(guardianVoiceStorage.read(OLD_KEY)).thenReturn(Optional.of(new byte[] {1}));

    assertThat(service.read(GUARDIAN, "routine-1", "step-1")).isPresent();
    verifyNoInteractions(entitlementService);
  }

  @Test
  @DisplayName("이룸이 기기는 승인 전 일과의 녹음을 받지 못한다 (없는 일과로 본다)")
  void read_elumiCannotSeePendingRoutine() {
    Routine routine = routine(OLD_KEY);
    routine.setStatus(RoutineStatus.PENDING_REVIEW);
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine));

    assertRejected(() -> service.read(ELUMI, "routine-1", "step-1"), ErrorCode.ROUTINE_NOT_FOUND);
    verifyNoInteractions(guardianVoiceStorage);
  }

  @Test
  @DisplayName("녹음이 없으면 빈 값")
  void read_emptyWithoutVoice() {
    when(routineRepository.findById("routine-1")).thenReturn(Optional.of(routine(null)));

    assertThat(service.read(ELUMI, "routine-1", "step-1")).isEmpty();
  }

  private static void assertRejected(Runnable call, ErrorCode expected) {
    assertThatThrownBy(call::run)
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(expected));
  }

  private static Routine routine(String voiceKey) {
    Profile profile = new Profile();
    profile.setId("profile-1");
    Routine routine = new Routine();
    routine.setId("routine-1");
    routine.setProfile(profile);
    routine.setStatus(RoutineStatus.CONFIRMED);
    routine.setCreatedBy("member-1");
    RoutineStep step = new RoutineStep();
    step.setId("step-1");
    step.setStepOrder(1);
    step.setDescription("설명");
    step.setGuardianVoicePath(voiceKey);
    List<RoutineStep> steps = new ArrayList<>();
    steps.add(step);
    routine.setSteps(steps);
    return routine;
  }
}
