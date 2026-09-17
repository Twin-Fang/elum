package com.chuseok22.elumserver.link.application.controller;

import com.chuseok22.elumserver.auth.application.dto.response.TokenResponse;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.link.application.dto.request.RedeemLinkRequest;
import com.chuseok22.elumserver.link.application.dto.response.LinkCodeResponse;
import com.chuseok22.elumserver.link.application.dto.response.LinkStatusResponse;
import com.chuseok22.elumserver.link.application.service.DeviceLinkService;
import com.chuseok22.elumserver.link.application.service.RedeemRateLimiter;
import com.chuseok22.elumserver.link.core.LinkRole;
import com.chuseok22.logging.annotation.LogMonitoring;
import jakarta.servlet.http.HttpServletRequest;
import jakarta.validation.Valid;
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.Authentication;
import org.springframework.security.core.GrantedAuthority;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/device-links")
@RequiredArgsConstructor
public class DeviceLinkController implements DeviceLinkControllerDocs {

  private final DeviceLinkService deviceLinkService;
  private final RedeemRateLimiter rateLimiter;

  @Override
  @LogMonitoring(logResult = true, logExecutionTime = true)
  @PostMapping
  public ResponseEntity<LinkCodeResponse> issue(Authentication authentication) {
    requireGuardian(authentication);
    return ResponseEntity.ok(deviceLinkService.issue(authentication.getName()));
  }

  @Override
  @GetMapping("/current")
  public ResponseEntity<LinkStatusResponse> status(Authentication authentication) {
    return ResponseEntity.ok(deviceLinkService.status(authentication.getName()));
  }

  @Override
  @LogMonitoring(logExecutionTime = true)
  @DeleteMapping("/current")
  public ResponseEntity<Void> revoke(Authentication authentication) {
    requireGuardian(authentication);
    deviceLinkService.revoke(authentication.getName());
    return ResponseEntity.noContent().build();
  }

  /**
   * 이룸이 휴대폰이 암호를 넣는다. 인증 없이 열려 있어 속도 제한을 먼저 통과해야 한다.
   *
   * <p>암호는 로그에 남기지 않으므로 {@code logParameters}를 켜지 않는다.
   */
  @Override
  @PostMapping("/redeem")
  public ResponseEntity<TokenResponse> redeem(
    @RequestBody @Valid RedeemLinkRequest request, HttpServletRequest http
  ) {
    if (!rateLimiter.tryAcquire(callerKey(http))) {
      throw new CustomException(ErrorCode.DEVICE_LINK_TOO_MANY_ATTEMPTS);
    }
    return ResponseEntity.ok(deviceLinkService.redeem(request.code()));
  }

  /**
   * 이룸이 휴대폰에서는 연결을 만들거나 끊을 수 없다.
   *
   * <p>토큰만 보면 보호자와 memberId가 같아서, 막지 않으면 이룸이 휴대폰이 자기 연결을
   * 끊거나 새 암호를 뿌릴 수 있다.
   */
  private void requireGuardian(Authentication authentication) {
    boolean isElumi = authentication.getAuthorities().stream()
      .map(GrantedAuthority::getAuthority)
      .anyMatch(LinkRole.ELUMI.authority()::equals);
    if (isElumi) {
      throw new CustomException(ErrorCode.DEVICE_LINK_FORBIDDEN_FOR_ELUMI);
    }
  }

  /** 프록시 뒤라 원격 주소가 전부 같을 수 있다. X-Real-IP가 있으면 그것을 쓴다. */
  private String callerKey(HttpServletRequest http) {
    String real = http.getHeader("X-Real-IP");
    if (real != null && !real.isBlank()) {
      return real;
    }
    String forwarded = http.getHeader("X-Forwarded-For");
    if (forwarded != null && !forwarded.isBlank()) {
      return forwarded.split(",")[0].trim();
    }
    return http.getRemoteAddr();
  }
}
