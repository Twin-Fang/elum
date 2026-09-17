package com.chuseok22.elumserver.member.application.dto.request;

import io.swagger.v3.oas.annotations.media.Schema;
import jakarta.validation.constraints.AssertTrue;

@Schema(description = "약관 동의 요청. 항목별로 나누어 받는다.")
public record MemberConsentRequest(

  @Schema(description = "서비스 이용약관 동의 (필수)", example = "true")
  @AssertTrue(message = "서비스 이용약관에 동의해야 합니다.")
  boolean termsAgreed,

  @Schema(description = "개인정보 수집·이용 동의 (필수)", example = "true")
  @AssertTrue(message = "개인정보 수집·이용에 동의해야 합니다.")
  boolean privacyAgreed,

  @Schema(description = "개인정보 국외 이전 동의 (필수). 일과 카드 생성 시 "
    + "마스킹된 텍스트가 Google(미국)로 전달됩니다.", example = "true")
  @AssertTrue(message = "개인정보 국외 이전에 동의해야 합니다.")
  boolean overseasTransferAgreed,

  @Schema(description = "만 14세 이상이며 아이의 법정대리인임을 확인 (필수)", example = "true")
  @AssertTrue(message = "법정대리인 확인이 필요합니다.")
  boolean guardianConfirmed,

  @Schema(description = "서비스 소식 수신 동의 (선택). 동의하지 않아도 서비스를 이용할 수 있습니다.",
    example = "false")
  boolean marketingAgreed,

  @Schema(description = "동의한 약관 버전. 약관 개정 시 재동의 대상을 가리는 데 쓴다.",
    example = "2026-09-17")
  String consentVersion
) {

}
