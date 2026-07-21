package com.chuseok22.elumserver.member.application.controller;

import com.chuseok22.elumserver.member.application.dto.request.MemberCharacterUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberNicknameUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.request.MemberSupportGoalsUpdateRequest;
import com.chuseok22.elumserver.member.application.dto.response.MemberResponse;
import com.chuseok22.elumserver.member.application.service.MemberService;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RequestMapping("/api/member")
@RestController
@RequiredArgsConstructor
public class MemberController implements MemberControllerDocs {

  private final MemberService memberService;

  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @GetMapping("/me")
  public ResponseEntity<MemberResponse> getMyInfo(Authentication authentication) {
    String memberId = authentication.getName();
    return ResponseEntity.ok(memberService.getMyInfo(memberId));
  }

  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @PatchMapping("/nickname")
  public ResponseEntity<MemberResponse> updateNickname(
    Authentication authentication, @RequestBody @Valid MemberNicknameUpdateRequest request
  ) {
    MemberResponse response = memberService.updateNickname(authentication.getName(), request);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @PatchMapping("/support-goals")
  public ResponseEntity<MemberResponse> updateSupportGoals(
    Authentication authentication, @RequestBody @Valid MemberSupportGoalsUpdateRequest request
  ) {
    MemberResponse response = memberService.updateSupportGoals(authentication.getName(), request);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @PatchMapping("/character")
  public ResponseEntity<MemberResponse> updateCharacter(
    Authentication authentication, @RequestBody @Valid MemberCharacterUpdateRequest request
  ) {
    MemberResponse response = memberService.updateCharacter(authentication.getName(), request);
    return ResponseEntity.ok(response);
  }

  @LogMonitoring(logParameters = true, logResult = true, logExecutionTime = true)
  @DeleteMapping("/me")
  public ResponseEntity<Void> withdraw(Authentication authentication) {
    memberService.withdraw(authentication.getName());
    return ResponseEntity.noContent().build();
  }
}
