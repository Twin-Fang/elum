package com.chuseok22.elumserver.member.application.controller;

import com.chuseok22.elumserver.member.application.dto.request.GuardianNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberCharacterUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberConsentRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberImageStyleUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberSupportGoalsUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.OnboardingCompleteRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberConsentResponse;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.elumserver.member.application.service.OnboardingService;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RequestMapping("/api/member")
@RestController
@RequiredArgsConstructor
public class MemberController implements MemberControllerDocs {

  private final MemberService memberService;
  private final OnboardingService onboardingService;

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/me")
  public ResponseEntity<MemberResponse> getMyInfo(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId
  ) {
    return ResponseEntity.ok(memberService.getMyInfo(Caller.from(authentication, profileId)));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @GetMapping("/consents")
  public ResponseEntity<MemberConsentResponse> getConsents(Authentication authentication) {
    return ResponseEntity.ok(memberService.getConsents(authentication.getName()));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/consents")
  public ResponseEntity<MemberConsentResponse> agreeConsents(
    Authentication authentication, @RequestBody @Valid MemberConsentRequest request
  ) {
    return ResponseEntity.ok(memberService.agreeConsents(authentication.getName(), request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/profile")
  public ResponseEntity<MemberResponse> createProfile(Authentication authentication) {
    return ResponseEntity.ok(memberService.createProfile(Caller.from(authentication)));
  }

  // X-Profile-Id 를 받지 않는다 — 앱에 남은 옛 선택값과 무관하게 내 이룸이에 저장
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PostMapping("/onboarding")
  public ResponseEntity<MemberResponse> completeOnboarding(
    Authentication authentication, @RequestBody OnboardingCompleteRequest request
  ) {
    return ResponseEntity.ok(onboardingService.complete(Caller.from(authentication), request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/nickname")
  public ResponseEntity<MemberResponse> updateNickname(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody @Valid MemberNicknameUpdateRequest request
  ) {
    MemberResponse response = memberService.updateNickname(Caller.from(authentication, profileId), request);
    return ResponseEntity.ok(response);
  }

  // 보호자 본인 닉네임 (위 /nickname 은 이룸이 호칭). 헤더는 응답의 이룸이 칸을 고르는 데만 씀
  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/account/nickname")
  public ResponseEntity<MemberResponse> updateGuardianNickname(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody GuardianNicknameUpdateRequest request
  ) {
    return ResponseEntity.ok(memberService.updateGuardianNickname(Caller.from(authentication, profileId), request));
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/support-goals")
  public ResponseEntity<MemberResponse> updateSupportGoals(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody @Valid MemberSupportGoalsUpdateRequest request
  ) {
    MemberResponse response = memberService.updateSupportGoals(Caller.from(authentication, profileId), request);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/character")
  public ResponseEntity<MemberResponse> updateCharacter(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody @Valid MemberCharacterUpdateRequest request
  ) {
    MemberResponse response = memberService.updateCharacter(Caller.from(authentication, profileId), request);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @PatchMapping("/image-style")
  public ResponseEntity<MemberResponse> updateImageStyle(
    Authentication authentication,
    @RequestHeader(value = Caller.PROFILE_HEADER, required = false) String profileId,
    @RequestBody @Valid MemberImageStyleUpdateRequest request
  ) {
    MemberResponse response = memberService.updateImageStyle(Caller.from(authentication, profileId), request);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = false, logResult = false, logExecutionTime = true)
  @DeleteMapping("/me")
  public ResponseEntity<Void> withdraw(Authentication authentication) {
    memberService.withdraw(authentication.getName());
    return ResponseEntity.noContent().build();
  }
}
