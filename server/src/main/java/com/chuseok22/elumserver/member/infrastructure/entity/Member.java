package com.chuseok22.elumserver.member.infrastructure.entity;

import com.chuseok22.elumserver.common.infrastructure.entity.BaseEntity;
import jakarta.persistence.Column;
import jakarta.persistence.Entity;
import jakarta.persistence.EnumType;
import jakarta.persistence.Enumerated;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import java.time.LocalDateTime;
import lombok.Getter;
import lombok.Setter;

/**
 * 로그인하는 계정. 보호자 또는 기관 지도자다.
 *
 * <p>당사자 정보(이름·캐릭터·도움 목표·별)는 {@link Profile}로 떼어냈다.
 * 한 테이블에 섞여 있으면 당사자 기기가 접속하려고 보호자의 아이디·비밀번호를
 * 써야 하고, 그 기기를 잃어버리면 계정 전체가 열린다.
 *
 * <p>이름이 {@code Member}인 것은 기존 API 경로(`/api/member/*`)와 응답 형식을
 * 유지하기 위해서다. 이미 배포된 앱이 그 계약을 쓰고 있다.
 */
@Entity
@Getter
@Setter
public class Member extends BaseEntity {
  @Id
  @GeneratedValue(strategy = GenerationType.UUID)
  private String id;

  @Column(nullable = false, unique = true)
  private String username;

  @Column(nullable = false)
  private String password;

  // 계정 상태. SUSPENDED면 로그인·API 사용이 모두 차단된다(MemberAccessGuard).
  @Enumerated(EnumType.STRING)
  @Column(nullable = false, columnDefinition = "varchar(255) not null default 'ACTIVE'")
  private MemberStatus status = MemberStatus.ACTIVE;

  private LocalDateTime lastLoginAt;

  // 인증 요청마다 60초 스로틀로 갱신된다(MemberAccessGuard) — 활성 회원 판단 기준.
  private LocalDateTime lastActivityAt;

  @Column(nullable = false, columnDefinition = "integer not null default 0")
  private Integer loginCount = 0;

  // 이 시각 이전에 발급된 JWT는 거부한다 — 관리자 강제 로그아웃의 구현 수단.
  private LocalDateTime tokenInvalidBefore;

  // 탈퇴한 시각 (이슈 #372). 보관 만료일의 기준이다. 탈퇴하지 않았으면 비어 있다.
  private LocalDateTime withdrawnAt;

  // --- 약관 동의 ---
  //
  // 개인정보보호법은 동의를 **항목별로 나눠서** 받도록 한다. 하나로 뭉쳐 받으면
  // 동의가 무효가 될 수 있다. 그래서 필드를 따로 둔다.
  //
  // 선택 항목(마케팅)을 필수와 섞지 않는 것도 같은 이유다. 선택에 동의하지 않아도
  // 서비스를 쓸 수 있어야 한다.

  /// 서비스 이용약관 (필수)
  @Column(nullable = false, columnDefinition = "boolean not null default false")
  private Boolean termsAgreed = false;

  /// 개인정보 수집·이용 (필수)
  @Column(nullable = false, columnDefinition = "boolean not null default false")
  private Boolean privacyAgreed = false;

  /// 개인정보 국외 이전 (필수).
  /// 일과 카드를 만들 때 마스킹된 텍스트가 Google(미국)로 전달된다.
  @Column(nullable = false, columnDefinition = "boolean not null default false")
  private Boolean overseasTransferAgreed = false;

  /// 만 14세 이상이며 아이의 법정대리인임을 확인 (필수).
  /// 아동 정보를 보호자가 대신 입력하는 구조라 이 확인이 필요하다.
  @Column(nullable = false, columnDefinition = "boolean not null default false")
  private Boolean guardianConfirmed = false;

  /// 서비스 소식 수신 (선택). 동의하지 않아도 서비스를 쓸 수 있다.
  @Column(nullable = false, columnDefinition = "boolean not null default false")
  private Boolean marketingAgreed = false;

  /// 동의한 시각. **법적 증빙이므로 반드시 남긴다.**
  /// "언제 동의받았는가"를 답하지 못하면 동의 자체를 입증할 수 없다.
  private LocalDateTime consentedAt;

  /// 동의한 약관 버전. 약관을 개정하면 이 값이 옛 버전인 사용자에게 재동의를 받는다.
  private String consentVersion;

  /// 동의를 받기 전 상태로 돌린다. 탈퇴 계정을 되살릴 때 동의를 다시 받기 위해 쓴다 (이슈 #372).
  /// 옛 동의 시각을 남기면 새로 동의받지 않았는데도 동의한 것처럼 보인다.
  public void clearConsents() {
    termsAgreed = false;
    privacyAgreed = false;
    overseasTransferAgreed = false;
    guardianConfirmed = false;
    marketingAgreed = false;
    consentedAt = null;
    consentVersion = null;
  }

  /// 필수 항목을 모두 동의했는가. 하나라도 빠지면 서비스를 쓸 수 없다.
  public boolean hasRequiredConsents() {
    return Boolean.TRUE.equals(termsAgreed)
      && Boolean.TRUE.equals(privacyAgreed)
      && Boolean.TRUE.equals(overseasTransferAgreed)
      && Boolean.TRUE.equals(guardianConfirmed);
  }
}
