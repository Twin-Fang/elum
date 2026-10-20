package com.chuseok22.elumserver.ai.core;

import com.chuseok22.elumserver.common.locale.AppLocale;

/**
 * 일과 콘텐츠 언어마다 코드에 박혀 있어야 하는 AI 지시 조각.
 *
 * <p>스키마 설명(responseSchema 의 description)은 운영 DB 가 아니라 코드라 배포로 바로 바뀐다. 프롬프트 행이
 * 어떤 언어로 대체돼도 스키마 설명은 일과 언어를 말하므로, 행이 빠진 사고에서도 출력 언어를 한 번 더 붙잡는다.
 *
 * <p>{@code ko} 는 지금 코드의 문장 그대로다(ko 요청 본문 불변). 나머지 필드(어조·예시)는 {@code ko} 가
 * 쓰지 않는다 — ko 프롬프트 행은 DB 에 있는 한국어 지시문 그대로이기 때문이다.
 *
 * @param englishName 프롬프트·스키마에서 출력 언어를 가리키는 영어 이름
 * @param toneGuide   프롬프트 [Sentence style] 절에 들어가는 어조 줄(영어로 쓴 지시). 줄마다 "- " 로 시작한다
 */
public record ContentLanguageSpec(
  AppLocale locale,
  String englishName,
  String routineTitleHint,
  String stepTitleHint,
  String stepDescriptionHint,
  String toneGuide,
  String stepTitleLength,
  String descriptionLength,
  String stepTitleExamples,
  String descriptionExamples,
  String routineTitleExamples,
  String questionExamples
) {

  public static final String KO_ROUTINE_TITLE_HINT =
    "일과 전체를 아우르는 제목. '~해요' 체로 작성 (예: '비오는 날 학교에 가요')";
  public static final String KO_STEP_TITLE_HINT =
    "카드에 크게 표시할 2~4어절짜리 짧은 라벨. '~해요' 체 (예: '옷을 입어요')";
  public static final String KO_STEP_DESCRIPTION_HINT =
    "소리 내어 읽어줄 아주 짧은 한 문장. 공백 포함 12자 안팎, 행동 하나만. "
      + "'~고', '~해서', '~한 뒤', 쉼표로 행동을 잇지 않는다 (나쁜 예: '이불을 덮고 누워요', 좋은 예: '침대에 누워요'). "
      + "title을 되풀이하지 않고 쉬운 말로 (예: '학교 갈 옷을 입어요')";

  private static final ContentLanguageSpec KO = new ContentLanguageSpec(
    AppLocale.KO, "Korean",
    KO_ROUTINE_TITLE_HINT, KO_STEP_TITLE_HINT, KO_STEP_DESCRIPTION_HINT,
    "", "", "", "", "", "", "");

  private static final ContentLanguageSpec EN = new ContentLanguageSpec(
    AppLocale.EN, "English",
    "One friendly sentence that covers the whole routine, in English (e.g. 'Going to school on a rainy day')",
    "Very short label shown large on the card, 2 to 5 words, in English (e.g. 'Put on your clothes')",
    "One very short sentence to be read aloud, about 6 words and never more than 9, one action only, in English. "
      + "Do not repeat the title; use plain words (e.g. 'Put on clothes for school')",
    "- Speak to the user directly in a warm, plain, polite voice, with short imperative sentences such as \"Put on your clothes\".\n"
      + "- Use plain present-tense actions. No \"please\", \"should\", or \"must\"; no baby talk; nothing that hints at age.\n"
      + "- Avoid idioms, metaphors, and abbreviations.",
    "2 to 5 words",
    "about 6 words, never more than 9 words",
    "\"Put on your clothes\", \"Pack your socks\", \"Pack your toothbrush\"",
    "title \"Put on your clothes\" -> description \"Put on clothes for school\"; "
      + "title \"Pack your toothbrush\" -> description \"Put the toothbrush in your bag\"",
    "\"Going to school on a rainy day\", \"Brush your teeth and go to bed\"",
    "If routineText is \"Going to school tomorrow when it rains\" and both goals are present, the PREPARE_ITEMS question is "
      + "\"What do you need to bring to school?\" with options like bag / water bottle / umbrella, and the PREPARE_NEW "
      + "question is \"Is anything different from usual today?\" with options like the time / the place / who goes with you changes.");

  private static final ContentLanguageSpec JA = new ContentLanguageSpec(
    AppLocale.JA, "Japanese",
    "One kind sentence that covers the whole routine, in Japanese, polite です・ます form (e.g. '雨の日に学校へ行きます')",
    "Very short label shown large on the card, a short phrase of about 10 characters at most, in Japanese です・ます form (e.g. '服を着ます')",
    "One very short sentence to be read aloud, about 12 characters and never more than 18, one action only, in Japanese です・ます form. "
      + "Do not repeat the title; use plain words (e.g. '学校に行く服を着ます')",
    "- Use the polite です・ます form in plain, kind wording, such as \"服を着ます\".\n"
      + "- Use ordinary Japanese spelling with common kanji only; no rare kanji, no furigana, and no all-hiragana spelling meant for young readers.\n"
      + "- Do not use the plain form (だ・である), keigo (honorific or humble speech), baby talk, or childish sentence-ending particles.\n"
      + "- One action per sentence.",
    "a short phrase of about 10 characters at most",
    "about 12 characters, never more than 18 characters",
    "\"服を着ます\", \"靴下を準備します\", \"歯ブラシを準備します\"",
    "title \"服を着ます\" -> description \"学校に行く服を着ます\"; "
      + "title \"歯ブラシを準備します\" -> description \"かばんに歯ブラシを入れます\"",
    "\"雨の日に学校へ行きます\", \"歯をみがいて寝ます\"",
    "If routineText is \"明日、雨の日に学校へ行く\" and both goals are present, the PREPARE_ITEMS question is "
      + "\"学校に行くとき、何を持っていきますか？\" with options like かばん / 水とう / 傘, and the PREPARE_NEW "
      + "question is \"今日はいつもと違うことがありますか？\" with options like 時間が違う / 場所が違う / いっしょに行く人が違う.");

  private static final ContentLanguageSpec ZH = new ContentLanguageSpec(
    AppLocale.ZH, "Simplified Chinese",
    "One friendly sentence that covers the whole routine, in Simplified Chinese (e.g. '雨天去学校')",
    "Very short label shown large on the card, 2 to 8 characters, in Simplified Chinese (e.g. '穿上衣服')",
    "One very short sentence to be read aloud, about 10 characters and never more than 16, one action only, in Simplified Chinese. "
      + "Do not repeat the title; use plain words (e.g. '穿上上学要穿的衣服')",
    "- Use Simplified Chinese in short, friendly, direct sentences, such as \"穿上衣服\".\n"
      + "- Use common everyday words only. No classical expressions, no idioms (成语), no baby talk, and no wording that hints at age such as \"宝宝\".\n"
      + "- One action per sentence. Use full-width Chinese punctuation.",
    "2 to 8 characters",
    "about 10 characters, never more than 16 characters",
    "\"穿上衣服\", \"带上袜子\", \"带上牙刷\"",
    "title \"穿上衣服\" -> description \"穿上上学要穿的衣服\"; "
      + "title \"带上牙刷\" -> description \"把牙刷放进书包\"",
    "\"雨天去学校\", \"刷牙后去睡觉\"",
    "If routineText is \"明天雨天去学校\" and both goals are present, the PREPARE_ITEMS question is "
      + "\"去学校要带什么？\" with options like 书包 / 水壶 / 雨伞, and the PREPARE_NEW "
      + "question is \"今天有和平时不一样的地方吗？\" with options like 时间不同 / 地点不同 / 同行的人不同.");

  private static final ContentLanguageSpec ES = new ContentLanguageSpec(
    AppLocale.ES, "Spanish",
    "One friendly sentence that covers the whole routine, in Spanish (e.g. 'Ir a la escuela un día de lluvia')",
    "Very short label shown large on the card, 2 to 4 words, in Spanish (e.g. 'Ponte la ropa')",
    "One very short sentence to be read aloud, about 6 words and never more than 9, one action only, in Spanish. "
      + "Do not repeat the title; use plain words (e.g. 'Ponte la ropa para ir a la escuela')",
    "- Use the informal \"tú\" imperative in a warm, plain voice, such as \"Ponte la ropa\".\n"
      + "- Use neutral Spanish understood in both Spain and Latin America; no regional slang, no childish diminutives, and no \"vosotros\" or \"vos\" forms.\n"
      + "- One action per sentence.",
    "2 to 4 words",
    "about 6 words, never more than 9 words",
    "\"Ponte la ropa\", \"Guarda los calcetines\", \"Guarda el cepillo de dientes\"",
    "title \"Ponte la ropa\" -> description \"Ponte la ropa para ir a la escuela\"; "
      + "title \"Guarda el cepillo de dientes\" -> description \"Mete el cepillo en la mochila\"",
    "\"Ir a la escuela un día de lluvia\", \"Lavarse los dientes e ir a dormir\"",
    "If routineText is \"Mañana voy a la escuela y va a llover\" and both goals are present, the PREPARE_ITEMS question is "
      + "\"¿Qué tienes que llevar a la escuela?\" with options like mochila / botella de agua / paraguas, and the PREPARE_NEW "
      + "question is \"¿Hay algo distinto de lo normal hoy?\" with options like la hora es distinta / el lugar es distinto / te acompaña otra persona.");

  public static ContentLanguageSpec of(AppLocale locale) {
    return switch (locale) {
      case KO -> KO;
      case EN -> EN;
      case JA -> JA;
      case ZH -> ZH;
      case ES -> ES;
    };
  }
}
