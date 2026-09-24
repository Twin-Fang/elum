package com.chuseok22.elumserver.admin.application.dto.request;

/**
 * 관리자 크레딧 조정 폼 (#407). 미리보기와 확정이 같은 값을 주고받는다.
 *
 * <p>모두 문자열로 받는다 — 숫자 칸에 글자가 오면 스프링 바인딩이 400 을 내 폼 오류로 보여 줄 수 없다.
 * 해석은 {@link #parsedType()} · {@link #parsedAmount()} 가 하고, 틀리면 IllegalArgumentException(폼 오류 문구)이다.
 *
 * @param expiryMode WEEK_END(기본) · DATE · NONE
 * @param expiryDate expiryMode 가 DATE 일 때 yyyy-MM-dd — 그 날 끝(다음 날 0시)에 만료
 */
public record CreditAdjustForm(String type, String amount, String expiryMode, String expiryDate, String reason) {

  public static final String EXPIRY_WEEK_END = "WEEK_END";
  public static final String EXPIRY_DATE = "DATE";
  public static final String EXPIRY_NONE = "NONE";

  public CreditAdjustType parsedType() {
    if (type == null || type.isBlank()) {
      throw new IllegalArgumentException("조정 종류를 골라주세요.");
    }
    try {
      return CreditAdjustType.valueOf(type.trim());
    } catch (IllegalArgumentException e) {
      throw new IllegalArgumentException("알 수 없는 조정 종류예요: " + type);
    }
  }

  /// 동결·해제는 수량이 없어 0 이다.
  public int parsedAmount() {
    if (!parsedType().hasAmount()) {
      return 0;
    }
    if (amount == null || amount.isBlank()) {
      throw new IllegalArgumentException("수량을 적어주세요.");
    }
    try {
      return Integer.parseInt(amount.trim());
    } catch (NumberFormatException e) {
      throw new IllegalArgumentException("수량은 숫자로 적어주세요.");
    }
  }

  public String expiryModeOrDefault() {
    return (expiryMode == null || expiryMode.isBlank()) ? EXPIRY_WEEK_END : expiryMode.trim();
  }
}
