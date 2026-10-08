package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.test.util.ReflectionTestUtils;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 의견 관리 목록·상세가 실제로 그려지는지, 사용자 입력이 이스케이프되는지, 태그 여닫기가 맞는지 본다.
 * 서버를 띄우지 않고 템플릿 엔진만으로 그린다.
 */
class AdminFeedbackTemplateTest {

  private static final List<String> TAGS = List.of(
    "div", "form", "table", "thead", "tbody", "tr", "section", "main", "button", "a", "span", "p", "pre");

  private SpringTemplateEngine engine;

  @BeforeEach
  void setUp() {
    ClassLoaderTemplateResolver resolver = new ClassLoaderTemplateResolver();
    resolver.setPrefix("templates/");
    resolver.setSuffix(".html");
    resolver.setTemplateMode(TemplateMode.HTML);
    resolver.setCharacterEncoding("UTF-8");
    engine = new SpringTemplateEngine();
    engine.setTemplateResolver(resolver);
    // 웹 요청 없이 그리므로 컨텍스트 경로가 없다.
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
  }

  private Feedback feedback(String id, String message, String appLog) {
    Feedback feedback = new Feedback();
    feedback.setId(id);
    feedback.setMemberId("ae9b68f4-66ed-44c5-9dd3-4972e737d1fc");
    feedback.setMessage(message);
    feedback.setAppLog(appLog);
    feedback.setAppVersion("2.20.0");
    feedback.setOs("ios Version 18.3.1 (Build 22D8075)");
    // 감사 컬럼은 setter 가 없어 JPA 가 채운다. 화면 확인용으로 직접 넣는다.
    ReflectionTestUtils.setField(feedback, "createdAt", LocalDateTime.of(2026, 10, 8, 17, 24, 44));
    return feedback;
  }

  private String renderDetail(Feedback feedback) {
    Context context = new Context();
    context.setVariable("feedback", feedback);
    return engine.process("admin/feedback-detail", context);
  }

  private String renderList(List<Feedback> rows) {
    Context context = new Context();
    context.setVariable("feedbacks", new PageImpl<>(rows));
    return engine.process("admin/feedback", context);
  }

  @Test
  @DisplayName("상세는 보낸 때·회원·앱 버전·OS·의견·기록을 보이고 회원 화면으로 잇는다")
  void detail_rendersEverything() {
    String html = renderDetail(feedback("f1", "카드 그림이 늦게 나와요.\n둘째 줄", "[17:20:04.110] [생명주기] 앱 시작"));

    assertThat(html).contains("의견 상세").contains("앱 상태 기록 있음")
      .contains("2026-10-08").contains("17:24:44").contains("2.20.0").contains("ios Version 18.3.1")
      .contains("카드 그림이 늦게 나와요.").contains("[17:20:04.110] [생명주기] 앱 시작")
      .contains("/admin/members/ae9b68f4-66ed-44c5-9dd3-4972e737d1fc")
      .contains("action=\"/admin/feedback/f1/delete\"");
  }

  @Test
  @DisplayName("기록의 최근 오류 구역에 적힌 건수만큼 오류 배지를 보인다. 구역이 없으면 보이지 않는다")
  void detail_showsErrorCount() {
    String log = "환경 요약\n== 최근 오류 ==\n[17:20:04.110] [에러] 첫째\n  stack\n[17:20:05.220] [에러] 둘째\n"
      + "== 기록 ==\n[17:20:06.330] [화면] 이동 push /home";

    assertThat(renderDetail(feedback("f4", "의견", log))).contains("오류 2건");
    assertThat(renderDetail(feedback("f5", "의견", "[17:20:06.330] [화면] 이동"))).doesNotContainPattern("오류 \\d+건");
    assertThat(renderList(List.of(feedback("f4", "의견", log)))).contains("오류 2건");
    assertThat(feedback("f6", "의견", null).appLogErrorCount()).isZero();
  }

  @Test
  @DisplayName("기록을 보내지 않은 의견은 그 사실을 알리고 기록 칸을 그리지 않는다")
  void detail_withoutLog() {
    String html = renderDetail(feedback("f2", "글만 보냈어요", null));

    assertThat(html).contains("앱 상태 기록 없음").contains("앱 상태 기록 보내기를 끄고 보냈어요")
      .doesNotContain("id=\"app-log\"");
  }

  @Test
  @DisplayName("의견과 기록은 사용자 입력이라 태그가 그대로 실행되지 않게 이스케이프한다")
  void detail_escapesUserInput() {
    String html = renderDetail(feedback("f3", "<script>alert(1)</script>", "<img src=x onerror=alert(2)>"));

    assertThat(html).doesNotContain("<script>alert(1)</script>").doesNotContain("<img src=x onerror")
      .contains("&lt;script&gt;alert(1)&lt;/script&gt;").contains("&lt;img src=x onerror=alert(2)&gt;");
  }

  @Test
  @DisplayName("목록은 줄마다 글과 기록 여부를 보이고 비면 빈 줄 안내를 보인다")
  void list_rendersRowsAndEmpty() {
    String html = renderList(List.of(feedback("f1", "첫 의견", "기록"), feedback("f2", "둘째 의견", null)));

    assertThat(html).contains("의견 관리").contains("첫 의견").contains("둘째 의견")
      .contains("/admin/feedback/f1").contains("/admin/feedback/f2");
    assertThat(renderList(List.of())).contains("아직 받은 의견이 없어요");
  }

  @Test
  @DisplayName("상세·목록의 여닫는 태그 수가 맞는다 — 짝이 안 맞으면 브라우저가 알아서 고쳐 그려 숨은 깨짐이 된다")
  void tagsBalanced() {
    for (String html : List.of(
      renderDetail(feedback("f1", "의견", "기록")),
      renderDetail(feedback("f2", "의견", null)),
      renderList(List.of(feedback("f1", "의견", "기록"))),
      renderList(List.of()))) {
      for (String tag : TAGS) {
        assertThat(count(html, "<" + tag + "[\\s>]")).as("<%s> 여는 수", tag)
          .isEqualTo(count(html, "</" + tag + ">"));
      }
    }
  }

  /// 확인용으로 화면을 파일로 내려받고 싶을 때만 켠다. 환경변수 `FEEDBACK_PREVIEW_DIR=/경로` 를 주면 그린 HTML 을 쓴다.
  @Test
  @DisplayName("미리보기 파일 쓰기 — 경로를 줬을 때만")
  void writePreview() throws IOException {
    String dir = System.getenv("FEEDBACK_PREVIEW_DIR");
    if (dir == null || dir.isBlank()) {
      return;
    }
    String log = "환경\n  앱 2.21.0 | ios 26.3.1 | ko | 글자 1.0 | 보호자\n== 최근 오류 ==\n"
      + "[17:21:10.420] [에러] 저장소 실패\n  repository: RoutineRepository | error: DioException [connection timeout]\n"
      + "[17:21:33.100] [에러] 처리하지 못한 예외\n  StateError: Bad state\n== 기록 ==\n"
      + String.join("\n", java.util.stream.IntStream.rangeClosed(1, 30)
        .mapToObj(i -> "[17:20:%02d.110] [네트워크] ← GET /api/routines/today 200 (%dms)".formatted(i, 100 + i))
        .toList());
    Files.writeString(Path.of(dir, "detail.html"), renderDetail(feedback("f1",
      "카드 그림이 너무 늦게 나와요.\n일과를 만들 때 한참 기다렸어요. 기다리는 동안 어떤 상태인지 알 수 있으면 좋겠어요.", log)),
      StandardCharsets.UTF_8);
    Files.writeString(Path.of(dir, "detail_nolog.html"),
      renderDetail(feedback("f2", "글만 보낸 의견", null)), StandardCharsets.UTF_8);
  }

  private static int count(String html, String regex) {
    Matcher matcher = Pattern.compile(regex).matcher(html);
    int found = 0;
    while (matcher.find()) {
      found++;
    }
    return found;
  }
}
