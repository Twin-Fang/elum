package com.chuseok22.elumserver.member.application.controller;

import com.chuseok22.elumserver.member.application.dto.request.GuardianUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.RedeemProfileInviteRequest;
import com.chuseok22.elumserver.member.application.dto.response.GuardianListResponse;
import com.chuseok22.elumserver.member.application.dto.response.GuardianResponse;
import com.chuseok22.elumserver.member.application.dto.response.ProfileInviteResponse;
import com.chuseok22.elumserver.member.application.dto.response.ProfileJoinResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.ProfileGuardianService;
import com.chuseok22.elumserver.member.application.service.ProfileInviteService;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RestController;

/**
 * 이룸이를 함께 돌보는 보호자 (다중 보호자 2단계).
 *
 * <p>이룸이는 <b>경로의 {@code profileId}</b> 로 정한다 — {@code X-Profile-Id} 헤더는 보지 않는다. 헤더가 "이룸이를
 * 고르는" 값이라면 여기서는 이룸이 자체가 대상이라 경로에 두는 편이 맞다. 이룸이 휴대폰 토큰은 URL 규칙
 * ({@code SecurityConfig} 의 보호자 권한)과 서비스가 모두 막는다 (E7).
 */
@RestController
@RequiredArgsConstructor
public class ProfileGuardianController implements ProfileGuardianControllerDocs {

  private final ProfileInviteService profileInviteService;
  private final ProfileGuardianService profileGuardianService;

  /** 코드 원문은 응답에만 나가고 로그에 남기지 않는다 — {@code logResult} 를 켜지 않는다. */
  @Override
  @LogMonitoring(logExecutionTime = true)
  @PostMapping("/api/profiles/{profileId}/invites")
  public ResponseEntity<ProfileInviteResponse> issueInvite(
    Authentication authentication, @PathVariable String profileId
  ) {
    return ResponseEntity.ok(profileInviteService.issue(Caller.from(authentication), profileId));
  }

  /** 입력한 코드는 자격증명이다 — {@code logParameters} 를 켜지 않는다. */
  @Override
  @LogMonitoring(logExecutionTime = true)
  @PostMapping("/api/profile-invites/redeem")
  public ResponseEntity<ProfileJoinResponse> redeemInvite(
    Authentication authentication, @RequestBody @Valid RedeemProfileInviteRequest request
  ) {
    return ResponseEntity.ok(profileInviteService.redeem(
      Caller.from(authentication), request.code(), request.displayName()));
  }

  @Override
  @LogMonitoring(logResult = true, logExecutionTime = true)
  @GetMapping("/api/profiles/{profileId}/guardians")
  public ResponseEntity<GuardianListResponse> listGuardians(
    Authentication authentication, @PathVariable String profileId
  ) {
    return ResponseEntity.ok(profileGuardianService.list(Caller.from(authentication), profileId));
  }

  @Override
  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @PatchMapping("/api/profiles/{profileId}/guardians/me")
  public ResponseEntity<GuardianResponse> updateMyGuardian(
    Authentication authentication, @PathVariable String profileId, @RequestBody @Valid GuardianUpdateRequest request
  ) {
    return ResponseEntity.ok(profileGuardianService.updateMe(Caller.from(authentication), profileId, request));
  }

  @Override
  @LogMonitoring(logExecutionTime = true)
  @DeleteMapping("/api/profiles/{profileId}/guardians/me")
  public ResponseEntity<Void> leave(Authentication authentication, @PathVariable String profileId) {
    profileGuardianService.leave(Caller.from(authentication), profileId);
    return ResponseEntity.noContent().build();
  }
}
