package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard;
import com.chuseok22.elumserver.member.application.service.ProfileAccessGuard.RoutineAction;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.core.GuardianVoiceAudio;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStep;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.chuseok22.elumserver.routine.infrastructure.storage.GuardianVoiceStorage;
import java.io.IOException;
import java.util.List;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.web.multipart.MultipartFile;

/**
 * 보호자 목소리로 카드 읽기 (#787): 녹음 올리기, 지우기, 받기
 * 올리기는 Pro(GUARDIAN_VOICE)만. 지우기는 요금제와 상관없이 언제나 (개인정보라 막지 않음)
 * 받기: 보호자 기기는 언제나(미리 듣기·지우기 전 확인), 이룸이 기기는 녹음한 보호자가 Pro 일 때만 > 아니면 빈 값(앱은 기본 음성)
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class RoutineStepVoiceService {

  private final RoutineRepository routineRepository;
  private final ProfileAccessGuard profileAccessGuard;
  private final GuardianVoiceStorage guardianVoiceStorage;
  private final GuardianVoiceFiles guardianVoiceFiles;
  private final EntitlementService entitlementService;

  /**
   * 녹음 올리기: 권한(만든 보호자) > Pro > 크기·형식·길이 > 새 파일 저장 > 열쇠 교체 > (롤백이면 새 파일, 커밋이면 옛 파일 삭제)
   */
  @Transactional
  public RoutineStepResponse upload(Caller caller, String routineId, String stepId, MultipartFile voice) {
    RoutineStep step = editableStepOf(caller, routineId, stepId);
    if (!entitlementService.isAllowed(caller.memberId(), Entitlement.GUARDIAN_VOICE)) {
      log.info("[guardian voice] rejected 403 : not allowed, memberId={}", caller.memberId());
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_NOT_ALLOWED);
    }
    byte[] audio = readBytes(voice);
    long durationMillis = GuardianVoiceAudio.inspect(audio);

    String newKey = guardianVoiceStorage.save(caller.memberId(), audio);
    guardianVoiceFiles.deleteOnRollback(newKey);
    String oldKey = step.getGuardianVoicePath();
    step.setGuardianVoicePath(newKey);
    guardianVoiceFiles.deleteUnreferencedAfterCommit(oldKey == null ? List.of() : List.of(oldKey));

    log.info("[guardian voice] saved : stepId={}, bytes={}, durationMillis={}", stepId, audio.length, durationMillis);
    return RoutineStepResponse.from(step);
  }

  /**
   * 녹음 지우기: 권한(만든 보호자) > 열쇠 비움 > 커밋 후 다른 카드가 안 가리키면 파일 삭제. 녹음이 없어도 성공
   */
  @Transactional
  public RoutineStepResponse delete(Caller caller, String routineId, String stepId) {
    RoutineStep step = editableStepOf(caller, routineId, stepId);
    String oldKey = step.getGuardianVoicePath();
    if (oldKey != null) {
      step.setGuardianVoicePath(null);
      guardianVoiceFiles.deleteUnreferencedAfterCommit(List.of(oldKey));
      log.info("[guardian voice] deleted : stepId={}", stepId);
    }
    return RoutineStepResponse.from(step);
  }

  /**
   * 녹음 받기: 권한(보기) > 열쇠 > (이룸이 기기면 녹음한 보호자 Pro 확인) > 파일. 없거나 막히면 빈 값
   */
  @Transactional(readOnly = true)
  public Optional<StepVoice> read(Caller caller, String routineId, String stepId) {
    Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, RoutineAction.VIEW);
    RoutineStep step = stepOf(routine, stepId);
    String key = step.getGuardianVoicePath();
    if (key == null) {
      return Optional.empty();
    }
    if (caller.isElumi() && !isPlayableOnChildDevice(key)) {
      return Optional.empty();
    }
    return guardianVoiceStorage.read(key).map(audio -> new StepVoice(key, audio));
  }

  /// 이룸이 기기 재생 조건: 녹음한 보호자가 지금 GUARDIAN_VOICE 권한을 가짐 (Pro 가 끝나면 기본 음성, 녹음은 남김)
  private boolean isPlayableOnChildDevice(String key) {
    return GuardianVoiceStorage.ownerOf(key)
      .map(ownerId -> entitlementService.isAllowed(ownerId, Entitlement.GUARDIAN_VOICE))
      .orElse(false);
  }

  /// 카드 수정과 같은 권한 — 이룸이는 EDIT 불가, 일과를 만든 보호자만
  private RoutineStep editableStepOf(Caller caller, String routineId, String stepId) {
    Routine routine = RoutineRules.routineFor(routineRepository, profileAccessGuard, caller, routineId, RoutineAction.EDIT);
    return stepOf(routine, stepId);
  }

  private static RoutineStep stepOf(Routine routine, String stepId) {
    return routine.getSteps().stream()
      .filter(candidate -> candidate.getId().equals(stepId))
      .findFirst()
      .orElseThrow(() -> new CustomException(ErrorCode.ROUTINE_STEP_NOT_FOUND));
  }

  /// 크기는 바이트를 읽기 전에 확인 (큰 파일을 메모리에 올린 뒤 거절하지 않게)
  private static byte[] readBytes(MultipartFile voice) {
    if (voice == null || voice.isEmpty()) {
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_INVALID_TYPE);
    }
    if (voice.getSize() > GuardianVoiceAudio.MAX_BYTES) {
      log.info("[guardian voice] rejected 400 : too large, bytes={}", voice.getSize());
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_TOO_LARGE);
    }
    try {
      return voice.getBytes();
    } catch (IOException e) {
      log.warn("[guardian voice] rejected 400 : unreadable upload", e);
      throw new CustomException(ErrorCode.GUARDIAN_VOICE_INVALID_TYPE);
    }
  }

  /// 받은 녹음: 열쇠(ETag·앱 캐시 이름), m4a 바이트
  public record StepVoice(String voiceKey, byte[] audio) {

  }
}
