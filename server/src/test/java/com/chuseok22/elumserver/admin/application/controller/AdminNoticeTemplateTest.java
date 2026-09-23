package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.request.NoticeEditForm;
import com.chuseok22.elumserver.admin.application.dto.response.AdminNoticeRow;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.ValueSource;
import org.thymeleaf.context.Context;
import org.thymeleaf.context.IExpressionContext;
import org.thymeleaf.linkbuilder.StandardLinkBuilder;
import org.thymeleaf.spring6.SpringTemplateEngine;
import org.thymeleaf.templatemode.TemplateMode;
import org.thymeleaf.templateresolver.ClassLoaderTemplateResolver;

/**
 * 공지 관리 화면이 실제로 그려지는지와 태그 여닫기가 맞는지 (이슈 #370).
 *
 * <p>짝 없는 {@code </div>} 하나가 휴대폰 메뉴(서랍)를 통째로 못 열게 만든 적이 있다(#369) —
 * 브라우저가 알아서 고쳐 그리므로 넓은 화면에서는 멀쩡해 보인다. 서버를 띄우지 않고
 * 템플릿 엔진만으로 그려 본다(스프링 컨텍스트 없음).
 */
class AdminNoticeTemplateTest {

  private static final Path TEMPLATES = Path.of("src/main/resources/templates/admin");
  private static final List<String> TAGS = List.of(
    "div", "form", "label", "table", "thead", "tbody", "tr", "ul", "li", "section", "aside", "main",
    "select", "button", "a", "span", "p", "template", "script", "style", "dialog", "details", "summary");

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
    // 웹 요청 없이 그리므로 @{/...} 링크에 붙일 컨텍스트 경로가 없다. 빈 값으로 둔다.
    engine.setLinkBuilder(new StandardLinkBuilder() {
      @Override
      protected String computeContextPath(IExpressionContext context, String base, Map<String, Object> parameters) {
        return "";
      }
    });
  }

  private AppNotice notice(String id, String title, NoticePlatform platform) {
    AppNotice notice = new AppNotice();
    notice.setId(id);
    notice.setTitle(title);
    notice.setBody("본문\n둘째 줄");
    notice.setPlatform(platform);
    notice.setPriority(3);
    notice.setRevision(2);
    notice.setStartsAt(LocalDateTime.of(2026, 9, 23, 9, 0));
    notice.setEndsAt(LocalDateTime.of(2026, 9, 30, 18, 0));
    notice.setEnabled(true);
    notice.setCreatedBy("kimchi");
    notice.setUpdatedBy("kimchi");
    notice.setImageKey(id + "/abc.png");
    return notice;
  }

  private String renderList(List<AdminNoticeRow> rows) {
    Context context = new Context();
    context.setVariable("rows", rows);
    context.setVariable("hideDays", 7);
    context.setVariable("previewJson", "{\"hideDays\":7,\"notices\":[]}");
    context.setVariable("message", "공지를 저장했어요.");
    return engine.process("admin/notices", context);
  }

  private String renderEdit(AppNotice notice, String errorMessage) {
    Context context = new Context();
    Map<String, Object> variables = new HashMap<>();
    variables.put("form", notice == null
      ? new NoticeEditForm("", "", "", "", "ALL", "0", "2026-09-23T12:00", "", false, false, false)
      : NoticeEditForm.of(notice));
    variables.put("notice", notice);
    variables.put("status", notice == null ? null : NoticeStatus.LIVE);
    variables.put("hideDays", 7);
    variables.put("previewJson", "{\"hideDays\":7,\"notices\":[]}");
    variables.put("errorMessage", errorMessage);
    context.setVariables(variables);
    return engine.process("admin/notice-edit", context);
  }

  @Test
  @DisplayName("목록은 상태 배지·기간·플랫폼·우선순위·수정한 사람을 보인다")
  void list_rendersRows() {
    AppNotice live = notice("n1", "**하루 3개**까지", NoticePlatform.IOS);
    AppNotice off = notice("n2", "추석 안내", NoticePlatform.ALL);
    off.setEnabled(false);

    String html = renderList(List.of(new AdminNoticeRow(live, NoticeStatus.LIVE),
      new AdminNoticeRow(off, NoticeStatus.DISABLED)));

    assertThat(html).contains("공지 관리").contains("게시 중").contains("꺼짐")
      .contains("2026-09-23 09:00").contains("2026-09-30 18:00").contains("iOS")
      .contains("kimchi").contains("공지를 저장했어요.")
      .contains("/admin/notices/n1").contains("/admin/notices/new");
    // 게시 중인 것을 지울 때 한 번 더 묻도록 표시해 둔다
    assertThat(html).containsPattern("data-live=\"true\"[^>]*action=\"/admin/notices/n1/delete\""
      + "|action=\"/admin/notices/n1/delete\"[^>]*data-live=\"true\"");
    assertThat(html).contains("/admin/js/notice-preview.js");
  }

  @Test
  @DisplayName("공지가 없으면 로딩과 구분되는 빈 줄을 보인다")
  void list_empty() {
    assertThat(renderList(List.of())).contains("아직 올린 공지가 없어요");
  }

  @Test
  @DisplayName("새로 만들기 화면 — 파일을 올릴 수 있는 폼과 미리보기 자리가 있다")
  void edit_new() {
    String html = renderEdit(null, null);

    assertThat(html).contains("새 공지").contains("enctype=\"multipart/form-data\"")
      .contains("action=\"/admin/notices\"").contains("name=\"title\"").contains("name=\"body\"")
      .contains("name=\"image\"").contains("accept=\"image/png,image/jpeg,image/webp\"")
      .contains("type=\"datetime-local\"").contains("id=\"notice-preview\"")
      .contains("/admin/js/notice-preview.js");
    // "다시 보이게"는 이미 나간 공지를 고칠 때만 뜻이 있다
    assertThat(html).doesNotContain("name=\"bumpRevision\"");
  }

  @Test
  @DisplayName("편집 화면 — 입력값·다시 보이게·이미지 지우기·기존 이미지 주소가 있다")
  void edit_existing() {
    String html = renderEdit(notice("n1", "**하루 3개**까지", NoticePlatform.IOS), "제목을 적어주세요. (E-NTC-001)");

    assertThat(html).contains("action=\"/admin/notices/n1\"")
      .contains("value=\"**하루 3개**까지\"").contains("name=\"bumpRevision\"")
      .contains("name=\"removeImage\"").contains("/admin/notices/n1/image")
      .contains("E-NTC-001").contains("게시 중").contains("판 2");
  }

  @ParameterizedTest
  @ValueSource(strings = {"list", "new", "edit"})
  @DisplayName("그려진 화면의 태그 여닫기 수가 맞다 — 짝 없는 닫는 태그가 휴대폰 메뉴를 망가뜨린다")
  void renderedTagsBalanced(String page) {
    String html = switch (page) {
      case "list" -> renderList(List.of(new AdminNoticeRow(notice("n1", "공지", NoticePlatform.ALL), NoticeStatus.LIVE)));
      case "new" -> renderEdit(null, "오류 (E-NTC-000)");
      default -> renderEdit(notice("n1", "공지", NoticePlatform.ALL), null);
    };

    assertThat(unbalanced(html)).as(page).isEmpty();
  }

  @ParameterizedTest
  @ValueSource(strings = {"notices.html", "notice-edit.html"})
  @DisplayName("템플릿 소스 자체도 여닫기 수가 맞다")
  void sourceTagsBalanced(String file) throws IOException {
    String source = Files.readString(TEMPLATES.resolve(file), StandardCharsets.UTF_8);

    assertThat(unbalanced(source)).as(file).isEmpty();
  }

  /** 여는 태그와 닫는 태그 수가 다른 태그 이름들. 주석과 스크립트 본문은 빼고 센다. */
  private List<String> unbalanced(String html) {
    String stripped = html
      .replaceAll("(?s)<!--.*?-->", "")
      .replaceAll("(?s)(<script\\b[^>]*>).*?(</script>)", "$1$2")
      .replaceAll("(?s)(<style\\b[^>]*>).*?(</style>)", "$1$2");
    List<String> problems = new ArrayList<>();
    for (String tag : TAGS) {
      int open = count(stripped, "<" + tag + "(?=[\\s>/])");
      int close = count(stripped, "</" + tag + "\\s*>");
      if (open != close) {
        problems.add(tag + " 열림 " + open + " / 닫힘 " + close);
      }
    }
    return problems;
  }

  private int count(String text, String regex) {
    Matcher matcher = Pattern.compile(regex).matcher(text);
    int count = 0;
    while (matcher.find()) {
      count++;
    }
    return count;
  }
}
