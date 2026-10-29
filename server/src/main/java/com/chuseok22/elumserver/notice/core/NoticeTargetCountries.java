package com.chuseok22.elumserver.notice.core;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import java.util.Arrays;
import java.util.LinkedHashSet;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;

/**
 * 공지 대상 국가 규칙: 입력 다듬기, 노출 판정 (#531)
 * 저장 모양: 쉼표 구분 ISO 3166-1 alpha-2 대문자 ("KR,JP"), null = 전체
 */
public final class NoticeTargetCountries {

  /** 저장 열 길이 (app_notice.target_countries VARCHAR(255)) */
  public static final int MAX_LENGTH = 255;

  /** 저장 구분자 */
  public static final String DELIMITER = ",";

  // 입력 구분: 쉼표·공백 아무거나
  private static final Pattern INPUT_SEPARATOR = Pattern.compile("[,\\s]+");

  // 두 글자 대문자만 (소문자는 몰래 고치지 않고 거절: 화면 값과 저장 값이 달라짐)
  private static final Pattern COUNTRY_CODE = Pattern.compile("[A-Z]{2}");

  private NoticeTargetCountries() {
  }

  /**
   * 관리자 입력 > 저장 값: 빈 조각 무시, 중복 제거(처음 순서 유지). 전체 대상이면 empty
   * 형식이 틀린 코드가 하나라도 있거나 길이 초과면 NOTICE_TARGET_COUNTRIES_INVALID (아무것도 저장 안 함)
   */
  public static Optional<String> normalize(String raw) {
    if (raw == null || raw.isBlank()) {
      return Optional.empty();
    }
    Set<String> codes = new LinkedHashSet<>();
    for (String piece : INPUT_SEPARATOR.split(raw.strip())) {
      if (piece.isEmpty()) {
        continue;
      }
      if (!COUNTRY_CODE.matcher(piece).matches()) {
        throw new CustomException(ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID);
      }
      codes.add(piece);
    }
    if (codes.isEmpty()) {
      return Optional.empty();
    }
    String joined = String.join(DELIMITER, codes);
    if (joined.length() > MAX_LENGTH) {
      throw new CustomException(ErrorCode.NOTICE_TARGET_COUNTRIES_INVALID);
    }
    return Optional.of(joined);
  }

  /**
   * 노출 판정: 대상 없음 > 모두에게, 대상 있음 > 요청 국가가 목록에 있을 때만
   * 국가 미상(null)에게는 대상 지정 공지를 보이지 않음
   */
  public static boolean isVisibleTo(String storedTargetCountries, String region) {
    if (storedTargetCountries == null || storedTargetCountries.isBlank()) {
      return true;
    }
    if (region == null) {
      return false;
    }
    return Arrays.asList(storedTargetCountries.split(DELIMITER)).contains(region);
  }
}
