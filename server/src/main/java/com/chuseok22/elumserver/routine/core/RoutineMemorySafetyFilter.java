package com.chuseok22.elumserver.routine.core;

import java.util.List;
import java.util.Locale;
import java.util.regex.Pattern;

/**
 * AI 메모 한 줄 안전 검사 (#1082, 서비스 원칙 1): 진단·장애 유형·정도·능력 평가·연락처가 보이면 그 줄은 저장하지 않음
 * AI 가 만든 줄과 보호자가 적은 줄 모두 거침. 판정은 낱말 포함 여부뿐 (뜻 추정 없음, 빠뜨리기보다 과하게 버리는 쪽)
 */
public final class RoutineMemorySafetyFilter {

  /// 한 줄 최대 글자 수 (화면 한 줄 + 프롬프트 토큰 제한)
  public static final int MAX_LINE_LENGTH = 60;

  /**
   * 금지 낱말 (소문자 비교). 4묶음: 진단·장애명, 정도·수준, 치료·약, 능력·성격 평가
   * 새 낱말은 여기에만 더함. 일상어와 겹치는 짧은 낱말(예: '약')은 넣지 않음 — 카드 글 '약 먹기'가 막힘
   */
  private static final List<String> FORBIDDEN_TERMS = List.of(
    // 진단·장애명
    "장애", "자폐", "아스퍼거", "adhd", "add ", "다운증후군", "다운 증후군", "뇌병변", "뇌성마비", "지적",
    "발달지연", "발달 지연", "지연", "뇌전증", "간질", "틱장애", "뚜렛", "투렛", "언어장애", "학습장애",
    "증후군", "스펙트럼", "asd", "진단", "질환", "병명", "지능", "iq", "경계선",
    // 정도·수준·단계
    "중증", "경증", "중등도", "중도", "경도", "심한", "심해", "수준", "등급", "단계가 낮", "정도가",
    // 치료·약·증상
    "치료", "복용", "약물", "투약", "처방", "증상", "발작", "재활", "병원 진료",
    // 능력·성격 평가
    "못해요", "못 해요", "못한다", "못함", "느려요", "느린 아이", "이해를 못", "이해 못", "부족해", "떨어져요",
    "문제행동", "문제 행동", "산만", "고집", "공격적"
  );

  /// 전화번호·이메일처럼 보이는 것
  private static final Pattern CONTACT_PATTERN =
    Pattern.compile("(\\d{2,4}[- .]?\\d{3,4}[- .]?\\d{4})|([\\w.+-]+@[\\w-]+\\.[\\w.]+)");

  private RoutineMemorySafetyFilter() {
  }

  /// 저장해도 되는 줄인가 (빈 줄·너무 긴 줄·금지 낱말·연락처 > false)
  public static boolean isAllowed(String line) {
    return rejectionReason(line) == null;
  }

  /// 거절 사유 (로그용 짧은 영문, 원문 없음). 통과면 null
  public static String rejectionReason(String line) {
    if (line == null || line.isBlank()) {
      return "blank";
    }
    String trimmed = line.trim();
    if (trimmed.length() > MAX_LINE_LENGTH) {
      return "too long";
    }
    String lowered = trimmed.toLowerCase(Locale.ROOT) + " ";
    for (String term : FORBIDDEN_TERMS) {
      if (lowered.contains(term)) {
        return "forbidden term";
      }
    }
    if (CONTACT_PATTERN.matcher(trimmed).find()) {
      return "contact";
    }
    return null;
  }
}
