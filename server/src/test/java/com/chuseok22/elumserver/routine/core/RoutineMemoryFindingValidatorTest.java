package com.chuseok22.elumserver.routine.core;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * AI 가 찾아 온 수정 검증: 깨지면 카드에 없던 낱말·진단·이름·기관이 규칙이 되어 다음 일과 AI 입력으로 나간다
 */
class RoutineMemoryFindingValidatorTest {

  private static final List<String> NAME_TOKENS = List.of("이룸이", "Elumi");
  private static final List<RoutineCardText> FIRST = List.of(
    new RoutineCardText("옷 착용해요", "겉옷을 착용해요"), new RoutineCardText("양치", "이를 닦아요"));
  private static final List<RoutineCardText> CONFIRMED = List.of(
    new RoutineCardText("옷 입어요", "겉옷을 입어요"), new RoutineCardText("양치", "이를 닦아요"));

  private static String reasonOf(RoutineMemoryFinding finding, List<RoutineCardText> first, List<RoutineCardText> confirmed) {
    return RoutineMemoryFindingValidator.rejectionReason(
      RoutineMemoryFindingValidator.normalize(finding), first, confirmed, NAME_TOKENS);
  }

  private static RoutineMemoryFinding word(String before, String after) {
    return new RoutineMemoryFinding(RoutineMemoryRuleType.WORD, before, after, null);
  }

  @Test
  @DisplayName("처음 카드에 있던 낱말이 확정 카드에서 다른 낱말로 바뀌었으면 통과한다")
  void word_realReplacement_passes() {
    assertThat(reasonOf(word("착용해요", "입어요"), FIRST, CONFIRMED)).isNull();
  }

  @Test
  @DisplayName("before 가 처음 카드에 없으면 버린다 — AI 가 지어낸 낱말이 규칙이 된다")
  void word_beforeNotInFirstCards_rejected() {
    assertThat(reasonOf(word("입으세요", "입어요"), FIRST, CONFIRMED)).isEqualTo("not in cards");
  }

  @Test
  @DisplayName("after 가 확정 카드에 없거나 before 가 확정 카드에도 남아 있으면 버린다")
  void word_afterMissingOrBeforeStillThere_rejected() {
    assertThat(reasonOf(word("착용해요", "걸쳐요"), FIRST, CONFIRMED)).isEqualTo("not in cards");
    assertThat(reasonOf(word("양치", "이 닦기"), FIRST, CONFIRMED)).isEqualTo("not in cards");
  }

  @Test
  @DisplayName("비슷하지만 다른 낱말도 카드에 실제로 있어야 통과한다 — 대소문자만 다른 영어 낱말은 같은 낱말로 본다")
  void word_matchingIsCaseInsensitive() {
    List<RoutineCardText> first = List.of(new RoutineCardText("Shirt", "Wear the shirt"));
    List<RoutineCardText> confirmed = List.of(new RoutineCardText("Shirt", "Put on the shirt"));

    assertThat(reasonOf(word("wear", "put on"), first, confirmed)).isNull();
  }

  @Test
  @DisplayName("진단·약·기관 이름·연락처가 든 before/after 는 버린다")
  void forbiddenTexts_rejected() {
    List<RoutineCardText> first = List.of(new RoutineCardText("자폐 약 먹기", "햇살초등학교 가요"));
    List<RoutineCardText> confirmed = List.of(new RoutineCardText("약 먹기", "학교 가요"));

    assertThat(reasonOf(word("자폐", "약"), first, confirmed)).isEqualTo("forbidden");
    assertThat(reasonOf(word("햇살초등학교", "학교"), first, confirmed)).isEqualTo("forbidden");
  }

  @Test
  @DisplayName("이룸이 이름 자리표시가 든 낱말은 버린다 — 아이 이름이 규칙에 남는다")
  void nameToken_rejected() {
    List<RoutineCardText> first = List.of(new RoutineCardText("이룸이 일어나요", "이룸이가 일어나요"));
    List<RoutineCardText> confirmed = List.of(new RoutineCardText("일어나요", "일어나요"));

    assertThat(reasonOf(word("이룸이 일어나요", "일어나요"), first, confirmed)).isEqualTo("name");
  }

  @Test
  @DisplayName("한 글자 낱말·60자 넘는 낱말·빈 낱말은 버린다")
  void tooShortOrLongOrMissing_rejected() {
    assertThat(reasonOf(word("착", "입"), FIRST, CONFIRMED)).isEqualTo("text length");
    assertThat(reasonOf(word("착".repeat(61), "입어요"), FIRST, CONFIRMED)).isEqualTo("text length");
    assertThat(reasonOf(word("착용해요", null), FIRST, CONFIRMED)).isEqualTo("missing text");
    assertThat(reasonOf(new RoutineMemoryFinding(RoutineMemoryRuleType.MANUAL, "a", "b", null), FIRST, CONFIRMED))
      .isEqualTo("type");
  }

  @Test
  @DisplayName("카드 나누기는 카드 수가 늘고 나뉜 카드가 확정 카드에 있을 때만 통과한다")
  void split_requiresCardCountIncrease() {
    List<RoutineCardText> first = List.of(new RoutineCardText("양치", "이를 닦아요"));
    List<RoutineCardText> split = List.of(
      new RoutineCardText("칫솔 들기", "칫솔을 들어요"), new RoutineCardText("이 닦기", "이를 닦아요"));
    RoutineMemoryFinding finding = new RoutineMemoryFinding(
      RoutineMemoryRuleType.SPLIT, "양치", "칫솔 들기 · 이 닦기", null);

    assertThat(reasonOf(finding, first, split)).isNull();
    // 카드 수가 그대로면 나누기가 아니다
    assertThat(reasonOf(finding, first, List.of(new RoutineCardText("칫솔 들기", "이 닦기")))).isEqualTo("not in cards");
  }

  @Test
  @DisplayName("카드 합치기·더하기·빼기도 카드 수 변화와 방향이 맞아야 한다")
  void mergeAddRemove_requireMatchingDirection() {
    List<RoutineCardText> two = List.of(new RoutineCardText("손 씻기", "손을 씻어요"), new RoutineCardText("양치", "이를 닦아요"));
    List<RoutineCardText> three = List.of(new RoutineCardText("손 씻기", "손을 씻어요"),
      new RoutineCardText("양치", "이를 닦아요"), new RoutineCardText("물 마시기", "물을 마셔요"));

    assertThat(reasonOf(new RoutineMemoryFinding(RoutineMemoryRuleType.ADD, "무시", "물 마시기", null), two, three)).isNull();
    assertThat(reasonOf(new RoutineMemoryFinding(RoutineMemoryRuleType.ADD, null, "물 마시기", null), three, two))
      .isEqualTo("not in cards");
    assertThat(reasonOf(new RoutineMemoryFinding(RoutineMemoryRuleType.REMOVE, "물 마시기", null, null), three, two)).isNull();
    assertThat(reasonOf(new RoutineMemoryFinding(RoutineMemoryRuleType.REMOVE, "물 마시기", null, null), two, three))
      .isEqualTo("not in cards");
    assertThat(reasonOf(new RoutineMemoryFinding(RoutineMemoryRuleType.MERGE, "손 씻기 · 양치", "양치", null), two, three))
      .isEqualTo("not in cards");
  }

  @Test
  @DisplayName("낱말 바꾸기 요약은 서버가 'before 대신 after' 로 만든다 — AI 가 쓴 요약에 낱말이 새지 않는다")
  void summaryOf_word_isServerTemplate() {
    RoutineMemoryFinding finding = new RoutineMemoryFinding(RoutineMemoryRuleType.WORD, "착용해요", "입어요", "엉뚱한 요약");

    assertThat(RoutineMemoryFindingValidator.summaryOf(finding)).isEqualTo("착용해요 대신 입어요");
  }

  @Test
  @DisplayName("그 밖 종류의 요약은 낱말을 담고 필터를 통과하면 AI 요약, 아니면 서버 문형이다")
  void summaryOf_other_usesAiSummaryOnlyWhenSafe() {
    RoutineMemoryFinding good = new RoutineMemoryFinding(RoutineMemoryRuleType.ADD, null, "물 마시기", "끝에 물 마시기를 넣어요");
    RoutineMemoryFinding noWord = new RoutineMemoryFinding(RoutineMemoryRuleType.ADD, null, "물 마시기", "카드를 더해요");
    RoutineMemoryFinding forbidden = new RoutineMemoryFinding(RoutineMemoryRuleType.ADD, null, "물 마시기", "자폐라서 물 마시기를 넣어요");

    assertThat(RoutineMemoryFindingValidator.summaryOf(good)).isEqualTo("끝에 물 마시기를 넣어요");
    assertThat(RoutineMemoryFindingValidator.summaryOf(noWord)).isEqualTo("'물 마시기' 카드를 넣어요");
    assertThat(RoutineMemoryFindingValidator.summaryOf(forbidden)).isEqualTo("'물 마시기' 카드를 넣어요");
  }

  @Test
  @DisplayName("같은 수정 판별은 종류·before·after 만 보고 공백·대소문자는 무시한다")
  void identityKey_ignoresCaseAndSpaces() {
    assertThat(RoutineMemoryFinding.identityKeyOf(RoutineMemoryRuleType.WORD, " Wear ", "put on"))
      .isEqualTo(RoutineMemoryFinding.identityKeyOf(RoutineMemoryRuleType.WORD, "wear", "Put On "));
    assertThat(RoutineMemoryFinding.identityKeyOf(RoutineMemoryRuleType.WORD, "wear", "put on"))
      .isNotEqualTo(RoutineMemoryFinding.identityKeyOf(RoutineMemoryRuleType.SPLIT, "wear", "put on"));
  }
}
