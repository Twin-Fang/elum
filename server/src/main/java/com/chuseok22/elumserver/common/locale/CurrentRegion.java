package com.chuseok22.elumserver.common.locale;

import java.util.Locale;
import java.util.regex.Pattern;

/**
 * 지금 처리 중인 요청의 국가 (다국어 #526, 스펙 4.3.1).
 *
 * <p>앱이 휴대폰 지역 설정을 {@code X-Elum-Region} 으로 보낸다. 헤더가 없으면 KR 이다(이미 배포된 앱의 사용자는 모두 한국).
 * 값이 비었거나 두 글자 영문이 아니면 <b>국가 미상(null)</b> 이다 — 오류가 아니라 "대상 국가를 지정하지 않은 공지만 보인다"로
 * 처리되므로 예외를 던지지 않는다.
 *
 * <p>접속 IP 로는 판정하지 않는다. IP 판정이 지역별 공지에 더 흔한 방식이지만 GeoIP DB 도입·갱신 운영이 필요하고,
 * 공지를 잘못 보여주는 피해는 가벼워서 그 비용을 들이지 않는다.
 *
 * <p>{@link CurrentLocale} 과 같은 이유로 InheritableThreadLocal 을 쓴다. 풀의 스레드는 {@link RegionFilter} 가 매번 비운다.
 */
public final class CurrentRegion {

  public static final String HEADER = "X-Elum-Region";
  public static final String DEFAULT = "KR";

  private static final Pattern ISO_ALPHA2 = Pattern.compile("^[A-Za-z]{2}$");

  /** 요청이 "국가 미상"을 저장했다는 표식. 스레드 로컬이 비어 있는 것(요청 밖 → KR)과 구분한다. */
  private static final String UNKNOWN = "";

  private static final InheritableThreadLocal<String> CURRENT = new InheritableThreadLocal<>();

  private CurrentRegion() {
  }

  /** 대문자 ISO 3166-1 alpha-2 코드. 국가 미상이면 null, 요청 밖이면 KR. */
  public static String get() {
    String stored = CURRENT.get();
    if (stored == null) {
      return DEFAULT;
    }
    return stored.isEmpty() ? null : stored;
  }

  /** 헤더 값을 국가로 푼다. null(헤더 없음) → KR, 형식이 틀리면 null(국가 미상). */
  static String parse(String header) {
    if (header == null) {
      return DEFAULT;
    }
    String trimmed = header.trim();
    if (!ISO_ALPHA2.matcher(trimmed).matches()) {
      return null;
    }
    return trimmed.toUpperCase(Locale.ROOT);
  }

  static void set(String region) {
    CURRENT.set(region == null ? UNKNOWN : region);
  }

  static void clear() {
    CURRENT.remove();
  }
}
