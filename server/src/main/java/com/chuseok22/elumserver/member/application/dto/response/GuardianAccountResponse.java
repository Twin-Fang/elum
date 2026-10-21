package com.chuseok22.elumserver.member.application.dto.response;

import com.chuseok22.elumserver.auth.infrastructure.entity.AuthIdentity;
import com.chuseok22.elumserver.auth.infrastructure.oauth.OAuthProvider;
import com.chuseok22.elumserver.member.core.EmailMasker;
import io.swagger.v3.oas.annotations.media.Schema;
import java.time.LocalDateTime;

@Schema(description = "보호자 계정 표시 정보 (내 정보 상단 카드). 원본 이메일은 내려주지 않는다")
public record GuardianAccountResponse(

  @Schema(description = "보호자 닉네임 (가입 시 자동 생성), 아직 없으면 null", example = "가파른블록-1269")
  String nickname,

  @Schema(description = "가입한 소셜 로그인 제공자. 아이디·비밀번호 가입이면 null", example = "KAKAO")
  OAuthProvider signInProvider,

  @Schema(description = "가린 이메일. 이메일 없음·애플 숨김 주소면 null (앱이 '이메일 비공개'로 표시)",
    example = "ab***@kakao.com")
  String maskedEmail,

  @Schema(description = "닉네임을 다시 바꿀 수 있는 시각. 바꾼 적 없으면 null (지금 바꿀 수 있음)",
    example = "2026-10-27T15:30:00")
  LocalDateTime nicknameChangeableAt
) {

  /**
   * 닉네임 + 처음 가입한 소셜 신원 + 다음 변경 가능 시각 > 표시 정보 (신원 없으면 제공자·이메일 null)
   */
  public static GuardianAccountResponse of(
    String nickname, AuthIdentity firstIdentity, LocalDateTime nicknameChangeableAt
  ) {
    if (firstIdentity == null) {
      return new GuardianAccountResponse(nickname, null, null, nicknameChangeableAt);
    }
    return new GuardianAccountResponse(
      nickname, firstIdentity.getProvider(), EmailMasker.mask(firstIdentity.getEmail()), nicknameChangeableAt);
  }
}
