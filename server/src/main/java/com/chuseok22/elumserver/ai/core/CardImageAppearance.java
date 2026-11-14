package com.chuseok22.elumserver.ai.core;

import java.util.ArrayList;
import java.util.List;
import java.util.regex.Pattern;

/**
 * 카드 그림 인물 생김새: 조각 3종(옷, 머리, 나머지)으로 나눠 다시 조립 (#1384)
 * 보호자 요청 다시 그리기에서 장면이 옷을 말하면 기본 옷만, 머리를 말하면 기본 머리만 뺌. 안경은 더하기라 빼지 않음
 */
public record CardImageAppearance(List<String> clothingClauses, List<String> hairClauses, List<String> otherClauses) {

  // 장면이 옷을 바꾸는가 (#1378 하네스 look_change.pattern 의 옷 낱말)
  private static final Pattern CLOTHING_CHANGE_SCENE = Pattern.compile(
    "\\b(wearing|wears|uniform|dress|shirt|sweater|jacket|coat)\\b", Pattern.CASE_INSENSITIVE);
  // 장면이 머리를 바꾸는가 (#1378 하네스 look_change.pattern 의 머리 낱말)
  private static final Pattern HAIR_CHANGE_SCENE = Pattern.compile(
    "\\b(hair|haircut)\\b", Pattern.CASE_INSENSITIVE);
  // 생김새 조각이 옷인가 (DB CARD_IMAGE_SUBJECT_CHILD 의 "a plain orange hoodie and gray long pants" 등)
  private static final Pattern CLOTHING_CLAUSE = Pattern.compile(
    "\\b(hoodie|shirt|t-shirt|sweater|jacket|coat|dress|pants|trousers|jeans|shorts|skirt|uniform|overalls|vest"
      + "|shoes|socks|sneakers)\\b", Pattern.CASE_INSENSITIVE);
  // 생김새 조각이 머리인가 ("short black bowl-cut hair" 등)
  private static final Pattern HAIR_CLAUSE = Pattern.compile(
    "\\b(hair|haircut|bowl-cut|bangs|ponytail|braids?)\\b", Pattern.CASE_INSENSITIVE);
  // 생김새 조각 구분자: DB 값의 쉼표 나열 "a, b, c"
  private static final String CLAUSE_DELIMITER = ",";
  private static final String CLAUSE_JOINER = ", ";

  public CardImageAppearance {
    clothingClauses = List.copyOf(clothingClauses);
    hairClauses = List.copyOf(hairClauses);
    otherClauses = List.copyOf(otherClauses);
  }

  /**
   * 장면에 맞는 생김새 문자열: 요청 없는 그림 > 기본 그대로, 요청 있는 다시 그리기 > 장면이 바꾼 조각만 뺌
   * 얼굴·체형·화풍 조각(나머지)은 항상 유지. null·빈 값도 예외 없이 그대로 돌려줌
   */
  public static String forScene(String defaultAppearance, String sceneEn, boolean hasGuardianRequest) {
    if (!hasGuardianRequest || defaultAppearance == null || defaultAppearance.isBlank() || sceneEn == null) {
      return defaultAppearance;
    }
    boolean isClothingChanged = isClothingChangeScene(sceneEn);
    boolean isHairChanged = isHairChangeScene(sceneEn);
    if (!isClothingChanged && !isHairChanged) {
      return defaultAppearance;
    }
    String assembled = parse(defaultAppearance).assemble(!isClothingChanged, !isHairChanged);
    // 나머지 조각이 없어 다 빠지면 기본 그대로 (빈 생김새로 그리지 않음)
    return assembled.isBlank() ? defaultAppearance : assembled;
  }

  /// 영어 장면이 옷을 말하는가
  public static boolean isClothingChangeScene(String sceneEn) {
    return sceneEn != null && CLOTHING_CHANGE_SCENE.matcher(sceneEn).find();
  }

  /// 영어 장면이 머리를 말하는가
  public static boolean isHairChangeScene(String sceneEn) {
    return sceneEn != null && HAIR_CHANGE_SCENE.matcher(sceneEn).find();
  }

  /**
   * 생김새 문자열 > 조각 3종 (쉼표로 나눔, 옷 > 머리 > 나머지 순으로 분류)
   */
  public static CardImageAppearance parse(String appearance) {
    List<String> clothing = new ArrayList<>();
    List<String> hair = new ArrayList<>();
    List<String> others = new ArrayList<>();
    if (appearance == null) {
      return new CardImageAppearance(clothing, hair, others);
    }
    for (String rawClause : appearance.split(CLAUSE_DELIMITER)) {
      String clause = rawClause.trim();
      if (clause.isEmpty()) {
        continue;
      }
      if (CLOTHING_CLAUSE.matcher(clause).find()) {
        clothing.add(clause);
      } else if (HAIR_CLAUSE.matcher(clause).find()) {
        hair.add(clause);
      } else {
        others.add(clause);
      }
    }
    return new CardImageAppearance(clothing, hair, others);
  }

  /**
   * 조각 > 생김새 문자열 (원래 순서: 나머지 첫 조각(인물 주어) > 머리 > 나머지 > 옷)
   */
  public String assemble(boolean shouldIncludeClothing, boolean shouldIncludeHair) {
    List<String> clauses = new ArrayList<>();
    if (!otherClauses.isEmpty()) {
      clauses.add(otherClauses.getFirst());
    }
    if (shouldIncludeHair) {
      clauses.addAll(hairClauses);
    }
    if (otherClauses.size() > 1) {
      clauses.addAll(otherClauses.subList(1, otherClauses.size()));
    }
    if (shouldIncludeClothing) {
      clauses.addAll(clothingClauses);
    }
    return String.join(CLAUSE_JOINER, clauses);
  }
}
