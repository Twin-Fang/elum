package com.chuseok22.elumserver.admin;

import static org.assertj.core.api.Assertions.assertThat;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.io.Resource;
import org.springframework.core.io.support.PathMatchingResourcePatternResolver;

/**
 * 관리자 템플릿이 연 태그를 연 만큼 닫는지 확인한다.
 *
 * <p>페이지 본문은 공통 레이아웃의 서랍 틀 안에 끼워진다. 본문에 닫는 {@code </div>}가
 * 하나라도 남으면 브라우저가 그것으로 <b>레이아웃의 틀을 먼저 닫아 버린다.</b> 그러면 메뉴
 * 영역이 서랍 밖으로 밀려나 휴대폰 크기에서 햄버거를 눌러도 메뉴가 열리지 않는다.
 *
 * <p>실제로 겪었다 — 공통 골격으로 옮기면서 옛 감싸개의 닫는 태그가 서버 로그와 루틴 상세에
 * 남았다(이슈 #369). 콘솔 오류도 없고 넓은 화면은 멀쩡해서 휴대폰으로 열어 봐야만 드러났다.
 *
 * <p>템플릿을 글로 훑는다. 스프링도 브라우저도 띄우지 않는다.
 */
class AdminTemplateTagBalanceTest {

  private static final String ADMIN_TEMPLATES = "classpath*:templates/admin/**/*.html";
  private static final String ADMIN_DIR = "templates/admin/";

  /// 레이아웃 틀을 깨뜨릴 수 있는 블록 태그들
  private static final List<String> CHECKED_TAGS =
    List.of("div", "section", "table", "form", "ul", "main");

  /// 주석·스크립트·스타일 안의 글자는 태그가 아니다 (레이아웃 사용법 주석에도 main 태그가 적혀 있다)
  private static final Pattern NON_MARKUP = Pattern.compile(
    "<!--.*?-->|<script\\b.*?</script\\s*>|<style\\b.*?</style\\s*>",
    Pattern.DOTALL | Pattern.CASE_INSENSITIVE);

  @Test
  @DisplayName("관리자 템플릿은 블록 태그를 연 만큼 닫아야 한다")
  void everyAdminTemplateClosesWhatItOpens() throws IOException {
    Resource[] templates = new PathMatchingResourcePatternResolver().getResources(ADMIN_TEMPLATES);
    assertThat(templates)
      .as("검사가 헛돌지 않도록 — 관리자 템플릿이 하나도 안 잡히면 경로가 바뀐 것이다")
      .isNotEmpty();

    List<String> unbalanced = new ArrayList<>();
    for (Resource template : templates) {
      String name = templateName(template);
      String markup = markupOnly(template.getContentAsString(StandardCharsets.UTF_8));
      for (String tag : CHECKED_TAGS) {
        TagBalance balance = balanceOf(markup, tag);
        if (balance.opened() != balance.closed()) {
          unbalanced.add("%s <%s> 여는 태그 %d개, 닫는 태그 %d개%s".formatted(
            name, tag, balance.opened(), balance.closed(),
            balance.firstOverflowLine() > 0
              ? " (%d행에서 닫는 태그가 먼저 넘친다)".formatted(balance.firstOverflowLine())
              : ""));
        }
      }
    }

    assertThat(unbalanced)
      .as("닫는 태그가 남으면 공통 레이아웃의 서랍 틀이 먼저 닫혀 휴대폰에서 메뉴가 열리지 않는다")
      .isEmpty();
  }

  /// 여는 태그·닫는 태그 수와, 닫는 쪽이 처음 넘친 줄 (넘치지 않았으면 0)
  private record TagBalance(int opened, int closed, int firstOverflowLine) {
  }

  private TagBalance balanceOf(String markup, String tag) {
    // 속성값 안의 '>'(예: th:if="${a > b}")에 끊기지 않도록 따옴표 값을 통째로 건너뛴다
    Pattern tagPattern = Pattern.compile(
      "(<" + tag + "(?:\\s+[^\\s=/>]+(?:\\s*=\\s*(?:\"[^\"]*\"|'[^']*'|[^\\s\"'>]+))?)*\\s*(/?)>)"
        + "|(</" + tag + "\\s*>)",
      Pattern.CASE_INSENSITIVE);
    Matcher matcher = tagPattern.matcher(markup);

    int opened = 0;
    int closed = 0;
    int firstOverflowLine = 0;
    while (matcher.find()) {
      if (matcher.group(1) != null) {
        // <div/> 는 스스로 닫혀 균형에 영향이 없다
        if (matcher.group(2).isEmpty()) {
          opened++;
        }
        continue;
      }
      closed++;
      if (closed > opened && firstOverflowLine == 0) {
        firstOverflowLine = lineOf(markup, matcher.start());
      }
    }
    return new TagBalance(opened, closed, firstOverflowLine);
  }

  /// 주석·스크립트·스타일을 비운다. 실패 메시지의 줄 번호가 원본과 맞도록 줄바꿈은 남긴다
  private String markupOnly(String source) {
    return NON_MARKUP.matcher(source)
      .replaceAll(match -> Matcher.quoteReplacement(match.group().replaceAll("[^\n]", "")));
  }

  private int lineOf(String text, int index) {
    int line = 1;
    for (int i = 0; i < index; i++) {
      if (text.charAt(i) == '\n') {
        line++;
      }
    }
    return line;
  }

  /// 실패 메시지용 이름 — fragments/admin-layout.html 처럼 관리자 폴더 기준 경로
  private String templateName(Resource template) throws IOException {
    String url = template.getURL().toString();
    int start = url.lastIndexOf(ADMIN_DIR);
    return start >= 0 ? url.substring(start + ADMIN_DIR.length()) : String.valueOf(template.getFilename());
  }
}
