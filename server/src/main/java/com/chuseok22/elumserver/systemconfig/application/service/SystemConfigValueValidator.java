package com.chuseok22.elumserver.systemconfig.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.systemconfig.core.ConfigFormat;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import com.chuseok22.elumserver.systemconfig.core.ConfigValueType;
import com.chuseok22.elumserver.systemconfig.core.StoreUrlPolicy;
import java.time.format.DateTimeParseException;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.regex.Pattern;
import java.util.stream.Collectors;

/**
 * 설정 값 검사 단일 지점: 빈 값·길이 > 값 종류(정수 범위·소수·선택지·켜고 끄기·날짜) > 문자열 형식(ConfigFormat)
 * 저장 시 거부 사유로, 화면 표시 시 기존 저장값 경고로 같은 규칙을 씀 (예외를 던지지 않음)
 */
public final class SystemConfigValueValidator {

  // 저장값 최대 길이 (DB 컬럼 여유 포함)
  static final int MAX_VALUE_LENGTH = 500;
  // 비밀값 평문 최대 길이: 암호문이 Base64로 부풀어도 MAX_VALUE_LENGTH 안에 들어오게
  static final int SECRET_MAX_LENGTH = 300;
  // 쉼표 목록 구분자
  static final String LIST_DELIMITER = ",";
  // 거부 사유에 넣는 입력값 일부 최대 길이 (긴 값이 메시지를 덮지 않게)
  private static final int REASON_VALUE_MAX_LENGTH = 40;

  // 앱 버전: 숫자.숫자 또는 숫자.숫자.숫자 (앱은 v·+빌드번호를 떼고 읽지만 저장은 숫자만)
  private static final Pattern APP_VERSION_PATTERN = Pattern.compile("^\\d{1,5}\\.\\d{1,5}(\\.\\d{1,5})?$");
  // 광고 단위: ca-app-pub-게시자번호/단위번호 또는 단위번호만
  private static final Pattern AD_UNIT_PATTERN = Pattern.compile("^(ca-app-pub-\\d{10,20}/)?\\d{6,20}$");
  // 회원 ID: UUID (Member.id 생성 방식)
  private static final Pattern MEMBER_ID_PATTERN =
    Pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$");

  private SystemConfigValueValidator() {
  }

  /**
   * 값 1개 검사: 통과면 저장할 정리된 값 (앞뒤 공백 제거, 목록은 중복·빈 항목 제거)
   */
  public static ConfigValueCheck check(ConfigKey key, String rawValue) {
    // 비밀값: 빈 값은 "그대로 두기"라 통과, 길이만 봄
    if (key.getValueType() == ConfigValueType.SECRET) {
      String secret = rawValue == null ? "" : rawValue.trim();
      return secret.length() > SECRET_MAX_LENGTH
        ? ConfigValueCheck.rejected(SECRET_MAX_LENGTH + "자 이하로 입력해요")
        : ConfigValueCheck.accepted(secret);
    }
    // 빈 값: 날짜시간·비울 수 있는 형식만 통과 (비면 그 기능 꺼짐·앱 기본값)
    if (rawValue == null || rawValue.isBlank()) {
      boolean isBlankAllowed = key.getValueType() == ConfigValueType.DATETIME || key.getFormat().isBlankAllowed();
      return isBlankAllowed ? ConfigValueCheck.accepted("") : ConfigValueCheck.rejected("값을 입력해요");
    }
    if (rawValue.length() > MAX_VALUE_LENGTH) {
      return ConfigValueCheck.rejected(MAX_VALUE_LENGTH + "자 이하로 입력해요");
    }
    String value = rawValue.trim();
    return switch (key.getValueType()) {
      case INTEGER -> checkInteger(key, value);
      case DECIMAL -> checkDecimal(value);
      case SELECT -> key.getAllowedValues().contains(value)
        ? ConfigValueCheck.accepted(value)
        : ConfigValueCheck.rejected("다음 중 하나만 고를 수 있어요: " + String.join(", ", key.getAllowedValues()));
      case BOOLEAN -> "true".equalsIgnoreCase(value) || "false".equalsIgnoreCase(value)
        ? ConfigValueCheck.accepted(value)
        : ConfigValueCheck.rejected("true 또는 false 만 받아요");
      case DATETIME -> checkDatetime(value);
      case STRING -> checkFormat(key, value);
      // 위에서 처리
      case SECRET -> ConfigValueCheck.accepted(value);
    };
  }

  /// 쉼표 목록 > 항목 (앞뒤 공백 제거, 빈 항목·중복 제거, 순서 유지)
  public static List<String> splitListItems(String listText) {
    if (listText == null || listText.isBlank()) {
      return List.of();
    }
    return List.copyOf(Arrays.stream(listText.split(LIST_DELIMITER))
      .map(String::trim)
      .filter(item -> !item.isEmpty())
      .collect(Collectors.toCollection(LinkedHashSet::new)));
  }

  /// 회원 ID 형식(UUID)인가 (존재 여부는 보지 않음)
  public static boolean isMemberIdFormat(String memberId) {
    return memberId != null && MEMBER_ID_PATTERN.matcher(memberId).matches();
  }

  private static ConfigValueCheck checkInteger(ConfigKey key, String value) {
    int number;
    try {
      number = Integer.parseInt(value);
    } catch (NumberFormatException e) {
      return ConfigValueCheck.rejected("정수로 입력해요");
    }
    // 범위 있는 키만 (시간값 0·음수 > 앱이 끝없이 기다림, 한도 0 > 기능 멈춤)
    if (key.isOutOfRange(number)) {
      return ConfigValueCheck.rejected(rangeText(key) + " 사이로 입력해요");
    }
    return ConfigValueCheck.accepted(value);
  }

  private static ConfigValueCheck checkDecimal(String value) {
    try {
      double number = Double.parseDouble(value);
      return Double.isFinite(number) ? ConfigValueCheck.accepted(value) : ConfigValueCheck.rejected("숫자로 입력해요");
    } catch (NumberFormatException e) {
      return ConfigValueCheck.rejected("숫자로 입력해요");
    }
  }

  // 읽을 수 없는 날짜는 저장하지 않음 (이벤트가 조용히 꺼지는 것을 막음)
  private static ConfigValueCheck checkDatetime(String value) {
    try {
      ConfigDateTime.parse(value);
      return ConfigValueCheck.accepted(value);
    } catch (DateTimeParseException e) {
      return ConfigValueCheck.rejected("날짜 형식이 아니에요 (예: 2026-10-19T00:00)");
    }
  }

  private static ConfigValueCheck checkFormat(ConfigKey key, String value) {
    ConfigFormat format = key.getFormat();
    return switch (format) {
      case FREE_TEXT -> ConfigValueCheck.accepted(value);
      case APP_VERSION -> APP_VERSION_PATTERN.matcher(value).matches()
        ? ConfigValueCheck.accepted(value)
        : ConfigValueCheck.rejected("버전은 " + format.getFormatHint() + " 로 적어요. v 나 +빌드번호는 빼요");
      // 막힌 사용자를 엉뚱한 곳으로 보내지 않도록 공식 스토어 주소만
      case STORE_URL -> StoreUrlPolicy.isAllowed(key, value)
        ? ConfigValueCheck.accepted(value)
        : ConfigValueCheck.rejected(storeUrlRejectReason(key));
      case AD_UNIT_LIST -> checkListItems(value, AD_UNIT_PATTERN, "광고 단위 형식이 아니에요", false);
      case MEMBER_ID_LIST -> checkListItems(value, MEMBER_ID_PATTERN, "회원 ID 형식이 아니에요", true);
      case CONTENT_LOCALE_LIST -> checkContentLocales(value);
    };
  }

  /// 쉼표 목록: 항목마다 형식 확인 > 정리된 목록 (빈 목록은 비울 수 있는 형식만)
  private static ConfigValueCheck checkListItems(
    String value, Pattern itemPattern, String itemRejectReason, boolean isEmptyListAllowed
  ) {
    List<String> items = splitListItems(value);
    if (items.isEmpty()) {
      return isEmptyListAllowed ? ConfigValueCheck.accepted("") : ConfigValueCheck.rejected("항목을 하나 이상 적어요");
    }
    for (String item : items) {
      if (!itemPattern.matcher(item).matches()) {
        return ConfigValueCheck.rejected(itemRejectReason + ": " + shorten(item));
      }
    }
    return ConfigValueCheck.accepted(String.join(LIST_DELIMITER, items));
  }

  // 모르는 코드는 저장하지 않음. ko 는 늘 켜 두므로 앞에 붙여 정규화
  private static ConfigValueCheck checkContentLocales(String value) {
    try {
      return ConfigValueCheck.accepted(EnabledLocales.normalize(value));
    } catch (CustomException e) {
      return ConfigValueCheck.rejected("모르는 언어 코드가 있어요. " + ConfigFormat.CONTENT_LOCALE_LIST.getFormatHint());
    }
  }

  private static String storeUrlRejectReason(ConfigKey key) {
    return key == ConfigKey.IOS_STORE_URL
      ? "https://apps.apple.com/… 또는 itms-apps://apps.apple.com/… 주소만 받아요"
      : "https://play.google.com/store/apps/details?id=… 또는 market://details?id=… 주소만 받아요";
  }

  /// 범위 문구 (예: "1 ~ 600"). 한쪽만 있으면 그쪽만
  static String rangeText(ConfigKey key) {
    String minText = key.getMinValue() == null ? "" : String.valueOf(key.getMinValue());
    String maxText = key.getMaxValue() == null ? "" : String.valueOf(key.getMaxValue());
    return minText + " ~ " + maxText;
  }

  /// 거부 사유용 입력값 일부 (제어문자 > ?, 40자 제한)
  private static String shorten(String item) {
    String cleaned = item.replaceAll("\\p{Cntrl}", "?");
    return cleaned.length() > REASON_VALUE_MAX_LENGTH ? cleaned.substring(0, REASON_VALUE_MAX_LENGTH) + "…" : cleaned;
  }
}
