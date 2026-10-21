package com.chuseok22.elumserver.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.ArrayDeque;
import java.util.ArrayList;
import java.util.Deque;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import java.util.stream.Stream;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * 관리자 화면 공통 규칙 봉인 (#760): 목록은 AdminListQuery/Definition, 표는 가로 스크롤, 페이지 크기는 한 곳
 * 소스와 템플릿을 글로 훑는다 (스프링을 띄우지 않음). 예외는 아래 목록에 이유와 함께만 둔다
 */
class AdminCommonRulesTest {

  private static final Path ADMIN_JAVA_ROOT = Path.of("src/main/java/com/chuseok22/elumserver/admin");
  private static final Path CONTROLLER_ROOT = ADMIN_JAVA_ROOT.resolve("application/controller");
  private static final Path TEMPLATE_ROOT = Path.of("src/main/resources/templates/admin");

  /// 목록 조회 파라미터로 보는 이름: 검색, 정렬, 페이지, 개수 제한
  private static final Pattern LIST_PARAMETER_NAME = Pattern.compile(
    "(?i)^q$|keyword|sort|page|limit|offset|size");
  private static final Pattern REQUEST_PARAMETER = Pattern.compile(
    "@RequestParam(?:\\(([^)]*)\\))?\\s*(?:final\\s+)?[\\w.<>?]+\\s+(\\w+)");
  private static final Pattern EXPLICIT_PARAMETER_NAME = Pattern.compile("(?:name|value)?\\s*=?\\s*\"(\\w+)\"");
  private static final String LIST_QUERY_TYPE = "AdminListQuery";

  /// 공통 목록(AdminListQuery) 없이 자체 목록 파라미터를 받아도 되는 컨트롤러와 이유
  private static final Map<String, String> OWN_LIST_PARAMETER_ALLOWED = Map.of(
    "AdminCreditController.java", "크레딧 4탭(회원별, 작업 탐색, 회원 상세의 작업·원장)은 탭마다 집계 조인이 달라 정의 하나로 못 담는다",
    "AdminLogApiController.java", "서버 로그는 DB 목록이 아니라 파일 tail·검색(offset, limit)이다",
    "AdminConfigMemberApiController.java", "설정 회원 고르기 자동완성(keyword)이라 쪽·정렬이 있는 목록이 아니다 (#912)"
  );

  private static final Set<String> VOID_TAGS = Set.of(
    "input", "br", "img", "meta", "link", "hr", "col", "source", "area", "base", "embed", "wbr");
  private static final Pattern TAG = Pattern.compile(
    "<(/?)([a-zA-Z][\\w:-]*)((?:\\s+[^\\s=/>]+(?:\\s*=\\s*(?:\"[^\"]*\"|'[^']*'|[^\\s\"'>]+))?)*)\\s*(/?)>");
  private static final Pattern NON_MARKUP = Pattern.compile(
    "<!--.*?-->|<script\\b.*?</script\\s*>|<style\\b.*?</style\\s*>", Pattern.DOTALL | Pattern.CASE_INSENSITIVE);
  private static final String SCROLL_CLASS = "overflow-x-auto";

  /// 가로 스크롤 감싸개 없이 표를 둬도 되는 템플릿과 이유 (현재 없음)
  private static final Map<String, String> TABLE_WITHOUT_SCROLL_ALLOWED = Map.of();

  @Test
  @DisplayName("admin 컨트롤러가 검색·정렬·페이지 파라미터를 받으면 AdminListQuery 를 쓴다 (예외는 이유와 함께 명시)")
  void listParametersGoThroughAdminListQuery() throws IOException {
    List<String> violations = new ArrayList<>();
    for (Path file : filesUnder(CONTROLLER_ROOT, ".java")) {
      String fileName = file.getFileName().toString();
      String source = Files.readString(file);
      if (OWN_LIST_PARAMETER_ALLOWED.containsKey(fileName) || source.contains(LIST_QUERY_TYPE)) {
        continue;
      }
      List<String> ownParameters = listParameterNames(source);
      if (!ownParameters.isEmpty()) {
        violations.add(fileName + " " + ownParameters);
      }
    }
    assertThat(violations)
      .as("새 관리자 목록은 AdminListDefinition 을 선언하고 AdminListQuery 로 받는다 (admin.application.list 참고)")
      .isEmpty();
  }

  @Test
  @DisplayName("목록 예외 목록은 실제로 자체 목록 파라미터를 가진 컨트롤러만 담는다 (낡은 예외 제거)")
  void listParameterExceptionsAreStillNeeded() throws IOException {
    for (String fileName : OWN_LIST_PARAMETER_ALLOWED.keySet()) {
      String source = Files.readString(CONTROLLER_ROOT.resolve(fileName));
      assertThat(listParameterNames(source)).as(fileName + " 예외가 더는 필요 없으면 목록에서 뺀다").isNotEmpty();
    }
  }

  @Test
  @DisplayName("admin 템플릿의 table 은 overflow-x-auto 안에 있다 (좁은 화면에서 가로 스크롤)")
  void tablesAreInsideHorizontalScroll() throws IOException {
    List<String> violations = new ArrayList<>();
    for (Path file : filesUnder(TEMPLATE_ROOT, ".html")) {
      String name = TEMPLATE_ROOT.relativize(file).toString();
      if (TABLE_WITHOUT_SCROLL_ALLOWED.containsKey(name)) {
        continue;
      }
      String markup = markupOnly(Files.readString(file, StandardCharsets.UTF_8));
      for (int line : tableLinesOutsideScroll(markup)) {
        violations.add(name + ":" + line);
      }
    }
    assertThat(violations).as("표는 <div class=\"overflow-x-auto\"> 로 감싼다").isEmpty();
  }

  @Test
  @DisplayName("표 검사기 자체: 감싸개가 없는 표는 잡고, 있는 표는 통과시킨다")
  void tableCheckerDetectsMissingWrapper() {
    assertThat(tableLinesOutsideScroll("<div><table><tr></tr></table></div>")).containsExactly(1);
    assertThat(tableLinesOutsideScroll("<div class=\"card overflow-x-auto\"><div><table></table></div></div>")).isEmpty();
    assertThat(tableLinesOutsideScroll("<div class=\"overflow-x-auto\"></div>\n<table></table>")).containsExactly(2);
  }

  @Test
  @DisplayName("admin 은 PageRequest.of 에 페이지 크기 숫자를 직접 쓰지 않는다 (AdminListDefaults 사용)")
  void adminDoesNotHardcodePageSize() throws IOException {
    List<String> violations = new ArrayList<>();
    for (Path file : filesUnder(ADMIN_JAVA_ROOT, ".java")) {
      String source = Files.readString(file);
      Matcher matcher = Pattern.compile("PageRequest\\.of\\(").matcher(source);
      while (matcher.find()) {
        List<String> arguments = topLevelArguments(source, matcher.end() - 1);
        if (arguments.size() >= 2 && arguments.get(1).strip().matches("\\d+")) {
          violations.add(file.getFileName() + " PageRequest.of(" + String.join(",", arguments) + ")");
        }
      }
    }
    assertThat(violations).as("페이지 크기는 AdminListDefaults.PAGE_SIZE / LOG_PAGE_SIZE 를 쓴다").isEmpty();
  }

  private static List<String> listParameterNames(String source) {
    List<String> names = new ArrayList<>();
    Matcher matcher = REQUEST_PARAMETER.matcher(source);
    while (matcher.find()) {
      Matcher explicit = EXPLICIT_PARAMETER_NAME.matcher(matcher.group(1) == null ? "" : matcher.group(1));
      String name = explicit.find() ? explicit.group(1) : matcher.group(2);
      if (LIST_PARAMETER_NAME.matcher(name).find()) {
        names.add(name);
      }
    }
    return names;
  }

  /// 가로 스크롤 감싸개 밖에 있는 table 의 줄 번호
  private static List<Integer> tableLinesOutsideScroll(String markup) {
    List<Integer> lines = new ArrayList<>();
    // 열린 요소 스택: 각 요소가 overflow-x-auto 를 가졌는지
    Deque<Map.Entry<String, Boolean>> open = new ArrayDeque<>();
    Matcher matcher = TAG.matcher(markup);
    while (matcher.find()) {
      boolean isClosing = !matcher.group(1).isEmpty();
      String tag = matcher.group(2).toLowerCase();
      if (VOID_TAGS.contains(tag) || !matcher.group(4).isEmpty()) {
        continue;
      }
      if (isClosing) {
        popThrough(open, tag);
        continue;
      }
      if (tag.equals("table") && open.stream().noneMatch(Map.Entry::getValue)) {
        lines.add(lineOf(markup, matcher.start()));
      }
      open.push(Map.entry(tag, matcher.group(3).contains(SCROLL_CLASS)));
    }
    return lines;
  }

  // 닫는 태그가 열린 요소와 짝이 맞지 않으면(생략된 닫는 태그) 가까운 같은 이름까지 닫는다
  private static void popThrough(Deque<Map.Entry<String, Boolean>> open, String tag) {
    if (open.stream().noneMatch(entry -> entry.getKey().equals(tag))) {
      return;
    }
    while (!open.isEmpty() && !open.pop().getKey().equals(tag)) {
      // 같은 이름을 만날 때까지 버림
    }
  }

  /// 호출 괄호 안 최상위 인자 (중첩 괄호·문자열 안 쉼표는 나누지 않음)
  private static List<String> topLevelArguments(String source, int openIndex) {
    List<String> arguments = new ArrayList<>();
    int depth = 0;
    int start = openIndex + 1;
    boolean isInString = false;
    for (int i = openIndex; i < source.length(); i++) {
      char c = source.charAt(i);
      if (c == '"' && source.charAt(i - 1) != '\\') {
        isInString = !isInString;
      } else if (!isInString && c == '(') {
        depth++;
      } else if (!isInString && c == ')' && --depth == 0) {
        arguments.add(source.substring(start, i));
        return arguments;
      } else if (!isInString && c == ',' && depth == 1) {
        arguments.add(source.substring(start, i));
        start = i + 1;
      }
    }
    return arguments;
  }

  private static String markupOnly(String source) {
    return NON_MARKUP.matcher(source)
      .replaceAll(match -> Matcher.quoteReplacement(match.group().replaceAll("[^\n]", "")));
  }

  private static int lineOf(String text, int index) {
    int line = 1;
    for (int i = 0; i < index; i++) {
      if (text.charAt(i) == '\n') {
        line++;
      }
    }
    return line;
  }

  private static List<Path> filesUnder(Path root, String extension) throws IOException {
    try (Stream<Path> walk = Files.walk(root)) {
      List<Path> files = walk.filter(path -> path.toString().endsWith(extension)).sorted().toList();
      assertThat(files).as("훑은 파일이 없으면 이 테스트가 아무것도 보지 않은 것이다: " + root).isNotEmpty();
      return files;
    }
  }
}
