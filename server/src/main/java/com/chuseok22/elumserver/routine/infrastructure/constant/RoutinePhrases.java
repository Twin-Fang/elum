package com.chuseok22.elumserver.routine.infrastructure.constant;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.infrastructure.entity.SupportGoal;
import com.chuseok22.elumserver.routine.application.dto.response.RoutineSuggestionResponse;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashMap;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Properties;
import java.util.TreeSet;
import java.util.concurrent.ConcurrentHashMap;
import java.util.function.Function;
import lombok.extern.slf4j.Slf4j;

/**
 * 서버가 만들어 내려보내는 일과 문구 — AI 추가 질문 폴백, 홈 추천 일과.
 *
 * <p>원본은 {@code i18n/routine-phrases_{언어}.properties} 다. <b>한 파일이 "한 벌"</b>이다: ko 파일의 키가 기준이고
 * 한 언어의 파일이 그 키를 모두 채워야 완성이다. 미완성인 언어는 요청이 와도 건너뛰고 요청 언어 → en → ko 중 완성된
 * 첫 언어의 한 벌을 쓴다(두 언어가 한 목록에 섞이지 않게). KO 요청은 영어로 새지 않는다.
 *
 * <p>서버가 뜰 때 {@code RoutinePhrasesStartupGuard} 가 켜진 언어의 한 벌을 검사해, 비어 있으면 서버를 세우지 않는다 —
 * AI 가 실패하는 순간에 문구도 없는 일을 막는다.
 */
@Slf4j
public final class RoutinePhrases {

  private static final String RESOURCE = "i18n/routine-phrases_%s.properties";
  private static final List<SupportGoal> FALLBACK_GOALS = List.of(SupportGoal.PREPARE_ITEMS, SupportGoal.PREPARE_NEW);
  /** RoutineAiPipeline 이 질문을 인정하는 최소 선택지 수와 같은 기준. ko 파일이 이보다 적으면 미완성이다. */
  private static final int MIN_FALLBACK_OPTIONS = 3;
  private static final RoutinePhrases DEFAULT = new RoutinePhrases(RoutinePhrases::loadFromClasspath);
  private static volatile RoutinePhrases standard = DEFAULT;

  private final Function<AppLocale, Map<String, String>> loader;
  private final Map<AppLocale, Map<String, String>> files = new ConcurrentHashMap<>();
  private final Map<AppLocale, List<String>> missing = new ConcurrentHashMap<>();

  public RoutinePhrases(Function<AppLocale, Map<String, String>> loader) {
    this.loader = loader;
  }

  public static RoutinePhrases standard() {
    return standard;
  }

  /** 훅과 무관한 실제 클래스패스 문구. RoutineSuggestionCatalog.ALL 처럼 클래스 로드 때 굳는 값이 훅에 오염되지 않게 쓴다. */
  static RoutinePhrases classpath() {
    return DEFAULT;
  }

  /** 테스트 전용: standard() 를 가짜로 바꾼다. 반드시 {@link #resetStandardForTesting()} 으로 되돌린다. */
  public static void overrideStandardForTesting(RoutinePhrases replacement) {
    standard = replacement;
  }

  public static void resetStandardForTesting() {
    standard = DEFAULT;
  }

  /** 이 언어의 파일에서 비어 있는 키. ko 파일의 키(+필수 구조)가 기준이고, 비어 있으면 완성이다. */
  public List<String> missingKeys(AppLocale locale) {
    return missing.computeIfAbsent(locale, this::computeMissing);
  }

  /**
   * ko 파일의 번호 구멍. 목록 길이를 "01부터 끊기지 않는 번호"로 정하므로 구멍 뒤의 문구는 조용히 잘린다 —
   * missingKeys 는 이를 못 잡아 따로 본다. 구멍이 없으면 빈 목록.
   */
  public List<String> koNumberingProblems() {
    Map<String, String> ko = file(AppLocale.KO);
    List<String> problems = new ArrayList<>();
    int suggestions = 0;
    while (ko.containsKey(suggestionKey(suggestions + 1, "text"))) {
      suggestions++;
    }
    collectOrphans(ko, "suggestion.", suggestions, problems);
    for (SupportGoal goal : FALLBACK_GOALS) {
      int options = 0;
      while (ko.containsKey(optionKey(goal.name(), options + 1, "label"))) {
        options++;
      }
      collectOrphans(ko, "fallback." + goal.name() + ".option.", options, problems);
    }
    return problems;
  }

  /** prefix 뒤 번호가 끊기지 않고 이어지는 길이(run)를 넘는 키는 구멍 뒤라 읽히지 않는다. */
  private static void collectOrphans(Map<String, String> ko, String prefix, int run, List<String> problems) {
    ko.keySet().stream().sorted().forEach(key -> {
      if (!key.startsWith(prefix)) {
        return;
      }
      String rest = key.substring(prefix.length());
      int dot = rest.indexOf('.');
      String number = dot < 0 ? rest : rest.substring(0, dot);
      if (number.matches("\\d+") && Integer.parseInt(number) > run) {
        problems.add("%s (번호 %d 까지만 이어져 읽히지 않음)".formatted(key, run));
      }
    });
  }

  /** 미완성인 언어와 빠진 키. 완성된 언어는 담기지 않는다. */
  public Map<AppLocale, List<String>> incompleteLocales(Collection<AppLocale> locales) {
    Map<AppLocale, List<String>> result = new LinkedHashMap<>();
    for (AppLocale locale : locales) {
      List<String> keys = missingKeys(locale);
      if (!keys.isEmpty()) {
        result.put(locale, keys);
      }
    }
    return result;
  }

  public List<RoutineSuggestionResponse> suggestions(AppLocale requested) {
    Map<String, String> ko = file(AppLocale.KO);
    Map<String, String> phrases = file(resolve(requested));
    List<RoutineSuggestionResponse> list = new ArrayList<>();
    // 개수는 ko 파일이 정한다 — 다른 언어가 더 적어도(미완성) 더 많아도 같은 개수다.
    for (int i = 1; ko.containsKey(suggestionKey(i, "text")); i++) {
      list.add(new RoutineSuggestionResponse(
        phrases.get(suggestionKey(i, "icon")),
        phrases.get(suggestionKey(i, "text")),
        phrases.get(suggestionKey(i, "example"))));
    }
    return List.copyOf(list);
  }

  public FallbackQuestion fallbackQuestion(SupportGoal goal, AppLocale requested) {
    String name = (goal == SupportGoal.PREPARE_ITEMS ? SupportGoal.PREPARE_ITEMS : SupportGoal.PREPARE_NEW).name();
    Map<String, String> ko = file(AppLocale.KO);
    Map<String, String> phrases = file(resolve(requested));
    List<FallbackQuestion.Option> options = new ArrayList<>();
    for (int i = 1; ko.containsKey(optionKey(name, i, "label")); i++) {
      options.add(new FallbackQuestion.Option(
        phrases.getOrDefault(optionKey(name, i, "emoji"), ""), phrases.get(optionKey(name, i, "label"))));
    }
    return new FallbackQuestion(phrases.get("fallback." + name + ".question"), List.copyOf(options));
  }

  /** 요청 → en → ko 중 한 벌이 완성된 첫 언어. KO 요청은 ko 만 본다. 아무것도 없으면 ko. */
  private AppLocale resolve(AppLocale requested) {
    // KO 는 fallbackChain() 이 [KO] 만 주므로 영어로 새지 않는다.
    for (AppLocale candidate : requested.fallbackChain()) {
      if (missingKeys(candidate).isEmpty()) {
        return candidate;
      }
    }
    return AppLocale.KO;
  }

  private List<String> computeMissing(AppLocale locale) {
    TreeSet<String> expected = new TreeSet<>(file(AppLocale.KO).keySet());
    expected.addAll(structuralKeys());
    Map<String, String> target = file(locale);
    return expected.stream().filter(key -> isBlank(target.get(key))).toList();
  }

  /** ko 파일에 반드시 있어야 하는 키 — 파일이 통째로 비었을 때 "키가 없으니 완성"으로 오해하지 않게. */
  private static List<String> structuralKeys() {
    List<String> keys = new ArrayList<>();
    keys.add(suggestionKey(1, "text"));
    for (SupportGoal goal : FALLBACK_GOALS) {
      keys.add("fallback." + goal.name() + ".question");
      for (int i = 1; i <= MIN_FALLBACK_OPTIONS; i++) {
        keys.add(optionKey(goal.name(), i, "label"));
      }
    }
    return keys;
  }

  private Map<String, String> file(AppLocale locale) {
    return files.computeIfAbsent(locale, key -> Map.copyOf(loader.apply(key)));
  }

  private static String suggestionKey(int index, String part) {
    return "suggestion.%02d.%s".formatted(index, part);
  }

  private static String optionKey(String goal, int index, String part) {
    return "fallback.%s.option.%d.%s".formatted(goal, index, part);
  }

  private static boolean isBlank(String value) {
    return value == null || value.isBlank();
  }

  private static Map<String, String> loadFromClasspath(AppLocale locale) {
    String path = RESOURCE.formatted(locale.code());
    try (InputStream in = RoutinePhrases.class.getClassLoader().getResourceAsStream(path)) {
      if (in == null) {
        return Map.of();
      }
      Properties properties = new Properties();
      properties.load(new InputStreamReader(in, StandardCharsets.UTF_8));
      Map<String, String> map = new HashMap<>();
      properties.stringPropertyNames().forEach(key -> map.put(key, properties.getProperty(key)));
      return map;
    } catch (IOException e) {
      // 못 읽은 파일은 빈 파일과 같다 — 대체 순서로 넘어가고, 켜진 언어면 기동 검사가 막는다.
      log.warn("[RoutinePhrases] 문구 파일을 읽지 못했습니다: {}", path, e);
      return Map.of();
    }
  }

  /** AI 가 질문을 못 만들었을 때 쓰는 고정 질문. */
  public record FallbackQuestion(String question, List<Option> options) {

    public record Option(String emoji, String label) {

    }
  }
}
