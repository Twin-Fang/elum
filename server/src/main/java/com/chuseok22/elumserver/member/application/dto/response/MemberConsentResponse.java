package com.chuseok22.elumserver.member.application.dto.response;

import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "약관 동의 상태")
public record MemberConsentResponse(

  @Schema(description = "필수 항목을 모두 동의했는지. false면 앱이 동의 화면을 띄운다.",
    example = "true")
  boolean requiredCompleted,

  @Schema(description = "서비스 이용약관 동의 여부") boolean termsAgreed,
  @Schema(description = "개인정보 수집·이용 동의 여부") boolean privacyAgreed,
  @Schema(description = "개인정보 국외 이전 동의 여부") boolean overseasTransferAgreed,
  @Schema(description = "법정대리인 확인 여부") boolean guardianConfirmed,
  @Schema(description = "서비스 소식 수신 동의 여부 (선택)") boolean marketingAgreed,

  @Schema(description = "동의한 시각", example = "2026-09-17T10:30:00")
  LocalDateTime consentedAt,

  @Schema(description = "동의한 약관 버전", example = "2026-09-17")
  String consentVersion
) {

  public static MemberConsentResponse from(Member member) {
    return new MemberConsentResponse(
      member.hasRequiredConsents(),
      Boolean.TRUE.equals(member.getTermsAgreed()),
      Boolean.TRUE.equals(member.getPrivacyAgreed()),
      Boolean.TRUE.equals(member.getOverseasTransferAgreed()),
      Boolean.TRUE.equals(member.getGuardianConfirmed()),
      Boolean.TRUE.equals(member.getMarketingAgreed()),
      member.getConsentedAt(),
      member.getConsentVersion()
    );
  }
}
