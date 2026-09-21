package com.chuseok22.elumserver.consent.core;

import lombok.Getter;
import lombok.RequiredArgsConstructor;

/**
 * 동의 항목의 종류 (이슈 #278).
 *
 * <p><b>{@code field} 는 앱·서버가 주고받는 필드명과 같다.</b> 앱은 이 이름으로 동의
 * 여부를 보내고({@code MemberConsentRequest}), 약관 목록도 이 이름으로 받는다.
 * enum 이름을 그대로 쓰지 않는 이유는 그렇게 하면 필드명을 바꿀 때 앱이 조용히
 * 깨지기 때문이다 — 양쪽을 잇는 이름은 한 곳에 적어 둔다.
 *
 * <p>{@code required} 는 <b>기본값일 뿐</b>이다. 실제 필수 여부는 DB 문서가 들고 있고
 * 관리자가 바꿀 수 있다. 여기 값은 문서를 처음 만들 때만 쓴다.
 */
@Getter
@RequiredArgsConstructor
public enum ConsentKey {

  TERMS("termsAgreed", "서비스 이용약관", true,
    "이룸을 어떻게 쓰고, 무엇을 보장하는지", "consent/terms.txt"),

  PRIVACY("privacyAgreed", "개인정보 수집·이용", true,
    "무엇을 모으고 언제까지 보관하는지", "consent/privacy.txt"),

  OVERSEAS_TRANSFER("overseasTransferAgreed", "개인정보 국외 이전", true,
    "카드를 만들 때 해외 AI 서비스로 전달돼요", "consent/overseas.txt"),

  // 나이 확인은 **계정을 만드는 보호자** 기준이다. 이룸이에게는 나이 제한이 없다 (#226).
  AGE_CONFIRM("guardianConfirmed", "만 14세 이상입니다", true,
    "계정을 만드는 보호자님의 나이를 확인해요", "consent/age.txt"),

  MARKETING("marketingAgreed", "서비스 소식 받기", false,
    "새 기능과 안내를 받아볼 수 있어요", "consent/marketing.txt");

  /** 앱과 주고받는 필드명. 앱의 {@code ConsentItem.key} 와 같다. */
  private final String field;
  private final String label;
  private final boolean requiredByDefault;
  private final String summary;
  /** 문서를 처음 만들 때 읽어 올 기본 본문의 classpath 경로. */
  private final String defaultBodyResource;
}
