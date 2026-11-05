package com.chuseok22.elumserver.routine.application.controller;

import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepImageCandidateApplyRequest;
import com.chuseok22.elumserver.routine.application.dto.request.RoutineStepImageRedrawRequest;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepImageCandidateResponse;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineStepResponse;
import com.chuseok22.elumserver.routine.application.service.RoutineStepImageCandidateService;
import com.chuseok22.elumserver.routine.application.service.RoutineStepImageRegenerateService;
import com.chuseok22.elumserver.routine.application.service.RoutineStepPhotoService;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;
import com.chuseok22.logging.annotation.LogMonitoring;
import lombok.RequiredArgsConstructor;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * 카드 그림 API: 사진으로 바꾸기, AI 그림 새로 그리기(후보), 후보 받기·바꾸기·버리기
 * 그림 조회(GET .../image)는 일과 조회와 함께 RoutineController
 */
@RequestMapping("/api/routines")
@RestController
@RequiredArgsConstructor
public class RoutineStepImageController implements RoutineStepImageDocs {

  private final RoutineStepPhotoService routineStepPhotoService;
  private final RoutineStepImageRegenerateService routineStepImageRegenerateService;
  private final RoutineStepImageCandidateService routineStepImageCandidateService;

  // 카드 그림을 보호자가 찍은 사진으로 바꾼다. AI·크레딧을 쓰지 않는다.
  // 파일 바이트를 로그에 남기지 않도록 파라미터·결과 모두 뺀다.
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PutMapping(value = "/{routineId}/steps/{stepId}/image", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
  public ResponseEntity<RoutineStepResponse> replaceStepImage(
    Authentication authentication,
    @PathVariable String routineId,
    @PathVariable String stepId,
    @RequestPart("image") MultipartFile image
  ) {
    RoutineStepResponse response =
      routineStepPhotoService.replaceStepImage(Caller.from(authentication), routineId, stepId, image);
    return ResponseEntity.ok(response);
  }

  // 카드 그림 새로 그리기 (다시 그리기·처음 그리기). 후보만 만들고 카드 그림은 그대로. 요청 글은 보호자 입력이라 파라미터를 로그에서 뺀다
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{routineId}/steps/{stepId}/image/regenerate")
  public ResponseEntity<RoutineStepImageCandidateResponse> regenerateStepImage(
    Authentication authentication,
    @PathVariable String routineId,
    @PathVariable String stepId,
    @RequestBody(required = false) RoutineStepImageRedrawRequest request
  ) {
    return ResponseEntity.ok(
      routineStepImageRegenerateService.drawCandidate(Caller.from(authentication), routineId, stepId, request));
  }

  // 고르기 전 새 그림 후보 받기 (보호자만)
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/{routineId}/steps/{stepId}/image/candidate")
  public ResponseEntity<byte[]> getStepImageCandidate(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    RoutineImageStorage.ImageContent content =
      routineStepImageCandidateService.readCandidate(Caller.from(authentication), routineId, stepId);
    return ResponseEntity.ok()
      .contentType(MediaType.parseMediaType(content.contentType()))
      .body(content.bytes());
  }

  // 새 그림으로 바꾸기. 응답에 카드 문장이 있어 결과를 로그에서 뺀다
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/{routineId}/steps/{stepId}/image/candidate/apply")
  public ResponseEntity<RoutineStepResponse> applyStepImageCandidate(
    Authentication authentication,
    @PathVariable String routineId,
    @PathVariable String stepId,
    @RequestBody RoutineStepImageCandidateApplyRequest request
  ) {
    return ResponseEntity.ok(routineStepImageCandidateService.applyCandidate(
      Caller.from(authentication), routineId, stepId, request.candidateImagePath()));
  }

  // 원래 그림 그대로 (후보 버리기). 후보가 없어도 204
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/{routineId}/steps/{stepId}/image/candidate")
  public ResponseEntity<Void> discardStepImageCandidate(
    Authentication authentication, @PathVariable String routineId, @PathVariable String stepId
  ) {
    routineStepImageCandidateService.discardCandidate(Caller.from(authentication), routineId, stepId);
    return ResponseEntity.noContent().build();
  }
}
