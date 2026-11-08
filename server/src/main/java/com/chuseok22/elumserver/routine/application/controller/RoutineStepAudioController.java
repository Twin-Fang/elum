package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineQueryService;
import com.chuseok22.elumserver.routine.application.service.RoutineStepSpeechDelivery;
import com.chuseok22.elumserver.routine.core.SpeechAudioFormat;
import com.chuseok22.elumserver.routine.application.service.RoutineStepSpeechProvider;
import com.chuseok22.elumserver.routine.application.service.RoutineStepVoiceService;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 카드 소리 API: 단계 음성(합성, #675) 받기, 보호자 목소리 녹음(#787) 올리기·지우기·받기
 * 둘 다 ETag = 소리 열쇠, 같으면 304
 */
@RequestMapping("/api/routines")
@RestController
@RequiredArgsConstructor
public class RoutineStepAudioController implements RoutineStepVoiceDocs {

  // 보호자 목소리 응답 형식 (m4a, #787)
  private static final MediaType VOICE_MEDIA_TYPE = MediaType.parseMediaType("audio/mp4");

  private final RoutineStepSpeechProvider routineStepSpeechProvider;
  private final RoutineStepSpeechDelivery routineStepSpeechDelivery;
  private final RoutineStepVoiceService routineStepVoiceService;

  // 단계 음성 (#675). 저장본이 없으면 요청 중 한 번 합성 (#765), 못 만들면 404 — 앱은 기기 음성으로 읽음
  // ETag = 음성 열쇠. 앱이 가진 열쇠와 같으면 304 (다시 받지 않음), 다르면 새 음성
  // 형식 (#1211): Accept 에 audio/mp4 가 있으면 m4a 그대로, 없으면(옛 앱) WAV 로 되돌려 응답. 못 되돌리면 404 > 기기 음성
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/{routineId}/steps/{stepId}/speech")
  public ResponseEntity<byte[]> getStepSpeech(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId,
    @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch,
    @RequestHeader(value = HttpHeaders.ACCEPT, required = false) String accept
  ) {
    return routineStepSpeechProvider.getStepSpeech(Caller.from(authentication), routineId, stepId)
      .map(speech -> toSpeechResponse(speech, ifNoneMatch, canPlayAac(accept)))
      .orElseGet(() -> ResponseEntity.notFound().build());
  }

  // 304 확인 먼저 (가진 음성이면 변환 없이 끝)
  private ResponseEntity<byte[]> toSpeechResponse(
    RoutineQueryService.StepSpeech speech, String ifNoneMatch, boolean canPlayAac
  ) {
    String etag = "\"" + speech.speechKey() + "\"";
    if (etag.equals(ifNoneMatch)) {
      return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).varyBy(HttpHeaders.ACCEPT).build();
    }
    return routineStepSpeechDelivery.deliver(speech, canPlayAac)
      .map(delivered -> ResponseEntity.ok()
        .contentType(MediaType.parseMediaType(delivered.format().mediaType()))
        .eTag(etag)
        .varyBy(HttpHeaders.ACCEPT)
        .body(delivered.audio()))
      .orElseGet(() -> ResponseEntity.notFound().build());
  }

  /// m4a 를 받는 앱인가 (새 앱은 Accept: audio/mp4 를 보냄, 옛 앱은 보내지 않음)
  private static boolean canPlayAac(String accept) {
    return accept != null && accept.contains(SpeechAudioFormat.AAC.mediaType());
  }

  // 보호자 목소리 녹음 올리기 (Pro, #787). 녹음은 개인정보라 파라미터·결과를 로그에 남기지 않는다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping(value = "/{routineId}/steps/{stepId}/voice", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public ResponseEntity<RoutineStepResponse> uploadStepVoice(
    Authentication authentication,
    @PathVariable String routineId,
    @PathVariable String stepId,
    @RequestPart("voice") MultipartFile voice
  ) {
    return ResponseEntity.ok(routineStepVoiceService.upload(Caller.from(authentication), routineId, stepId, voice));
  }

  // 보호자 목소리 녹음 지우기. 요금제와 상관없이 언제나 (#787)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{routineId}/steps/{stepId}/voice")
  public ResponseEntity<RoutineStepResponse> deleteStepVoice(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    return ResponseEntity.ok(routineStepVoiceService.delete(Caller.from(authentication), routineId, stepId));
  }

  // 보호자 목소리 받기 (#787). 없거나 이룸이 기기에서 재생 불가면 404 — 앱은 기본 음성으로 읽음
  // ETag = 녹음 열쇠. 앱이 가진 열쇠와 같으면 304
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/{routineId}/steps/{stepId}/voice")
  public ResponseEntity<byte[]> getStepVoice(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId,
    @RequestHeader(value = HttpHeaders.IF_NONE_MATCH, required = false) String ifNoneMatch
  ) {
    return routineStepVoiceService.read(Caller.from(authentication), routineId, stepId)
      .map(voice -> toVoiceResponse(voice, ifNoneMatch))
      .orElseGet(() -> ResponseEntity.notFound().build());
  }

  private static ResponseEntity<byte[]> toVoiceResponse(RoutineStepVoiceService.StepVoice voice, String ifNoneMatch) {
    String etag = "\"" + voice.voiceKey() + "\"";
    if (etag.equals(ifNoneMatch)) {
      return ResponseEntity.status(HttpStatus.NOT_MODIFIED).eTag(etag).build();
    }
    return ResponseEntity.ok()
      .contentType(VOICE_MEDIA_TYPE)
      .eTag(etag)
      .body(voice.audio());
  }
}
