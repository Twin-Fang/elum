package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.list.AdminFeedbackList;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminTalkPostList;
import com.chuseok22.elumserver.admin.application.list.AdminTalkReportList;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostDetail;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostDetail.CommentRow;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostRow;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminReportRow;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkReportReason;
import com.chuseok22.elumserver.talk.core.TalkReportTargetType;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.regex.Matcher;
import java.util.regex.Pattern;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.test.util.ReflectionTestUtils;

/**
 * 이야기 관리 목록·상세·신고 화면이 실제로 그려지는지, 사용자 입력이 이스케이프되는지, 태그 여닫기가 맞는지 본다.
 * 서버를 띄우지 않고 템플릿 엔진만으로 그린다.
 */
class AdminTalkTemplateTest {

  private static final List<String> TAGS = List.of(
    "div", "form", "table", "thead", "tbody", "tr", "section", "main", "button", "a", "span", "p", "select");
  private static final LocalDateTime CREATED_AT = LocalDateTime.of(2026, 10, 20, 9, 30, 15);

  private final AdminTemplateRenderSupport renderer = new AdminTemplateRenderSupport();

  private static TalkPost post(String id, String title, TalkPostStatus status) {
    TalkPost post = new TalkPost();
    post.setId(id);
    post.setAuthorMemberId("author-member-" + id);
    post.setTitle(title);
    post.setNote("글쓴이 한마디");
    post.setCategory(TalkCategory.SELF_CARE);
    post.setStepCount(2);
    post.setStatus(status);
    post.setHelpfulCount(4);
    post.setCommentCount(2);
    post.setImportCount(1);
    ReflectionTestUtils.setField(post, "createdAt", CREATED_AT);
    return post;
  }

  private static TalkComment comment(String id, String body, TalkCommentStatus status) {
    TalkComment comment = new TalkComment();
    comment.setId(id);
    comment.setPostId("p1");
    comment.setAuthorMemberId("commenter-member-" + id);
    comment.setBody(body);
    comment.setStatus(status);
    ReflectionTestUtils.setField(comment, "createdAt", CREATED_AT);
    return comment;
  }

  private static TalkReport report(String id, TalkReportTargetType type, LocalDateTime resolvedAt) {
    TalkReport report = new TalkReport();
    report.setId(id);
    report.setTargetType(type);
    report.setTargetId(type == TalkReportTargetType.POST ? "p1" : "c1");
    report.setPostId("p1");
    report.setReporterMemberId("reporter-member-" + id);
    report.setReason(TalkReportReason.PERSONAL_INFO);
    report.setResolvedAt(resolvedAt);
    ReflectionTestUtils.setField(report, "createdAt", CREATED_AT);
    return report;
  }

  private static TalkPostStep step(int order, String imageKey) {
    TalkPostStep step = new TalkPostStep();
    step.setPostId("p1");
    step.setStepOrder(order);
    step.setTitle("양치하기 " + order);
    step.setDescription("칫솔에 치약을 짜요");
    step.setImageKey(imageKey);
    step.setPictogramId(imageKey == null ? "pict-7" : null);
    return step;
  }

  private String renderPosts(List<TalkAdminPostRow> rows, AdminListQuery query, long unresolvedReportCount) {
    Map<String, Object> model = new HashMap<>();
    model.put("posts", new PageImpl<>(rows, PageRequest.of(0, 20), rows.size()));
    model.put("definition", AdminTalkPostList.DEFINITION);
    model.put("query", query);
    model.put("unresolvedReportCount", unresolvedReportCount);
    model.put("pagerBaseUrl", "/admin/talk/posts" + query.toQueryString(query.sort(), 1));
    return renderer.render("admin/talk", model);
  }

  private String renderPosts(List<TalkAdminPostRow> rows) {
    return renderPosts(rows, AdminListQuery.of(null, Map.of(), null, null, AdminTalkPostList.DEFINITION), 0);
  }

  private String renderReports(List<TalkAdminReportRow> rows, AdminListQuery query) {
    Map<String, Object> model = new HashMap<>();
    model.put("reports", new PageImpl<>(rows, PageRequest.of(0, 20), rows.size()));
    model.put("definition", AdminTalkReportList.DEFINITION);
    model.put("query", query);
    model.put("pagerBaseUrl", "/admin/talk/reports" + query.toQueryString(query.sort(), 1));
    return renderer.render("admin/talk-reports", model);
  }

  private String renderReports(List<TalkAdminReportRow> rows) {
    return renderReports(rows, AdminListQuery.of(null, Map.of(), null, null, AdminTalkReportList.DEFINITION));
  }

  private String renderDetail(TalkAdminPostDetail detail) {
    return renderer.render("admin/talk-detail", Map.of("detail", detail));
  }

  private TalkAdminPostDetail detailOf(TalkPost post) {
    return new TalkAdminPostDetail(post, "하늘", List.of(step(0, "p1/0.png"), step(1, null)),
      List.of(new CommentRow(comment("c1", "보이는 댓글이에요", TalkCommentStatus.VISIBLE), "구름"),
        new CommentRow(comment("c2", "가린 댓글이에요", TalkCommentStatus.HIDDEN_BY_ADMIN), null),
        new CommentRow(comment("c3", "지운 댓글이에요", TalkCommentStatus.DELETED), "바람")),
      List.of(new TalkAdminReportRow(report("r1", TalkReportTargetType.COMMENT, null), "달", post.getTitle(),
          "보이는 댓글이에요"),
        new TalkAdminReportRow(report("r2", TalkReportTargetType.POST, CREATED_AT.plusHours(1)), null, post.getTitle(),
          null)));
  }

  @Test
  @DisplayName("layout_hasTalkMenu: 사이드 메뉴에 이야기 항목과 미처리 신고 배지 자리가 있고, 이야기 화면에서는 켜져 있다")
  void layout_hasTalkMenu() {
    String html = renderPosts(List.of());

    assertThat(html).contains("href=\"/admin/talk/posts\"").contains(">이야기")
      .contains("data-sidebar-badge=\"unresolvedTalkReportCount\"");
    assertThat(html).containsPattern("<a href=\"/admin/talk/posts\" class=\"active\"");
    // 다른 화면에서는 켜지지 않는다
    assertThat(renderer.render("admin/feedback", feedbackModel()))
      .doesNotContainPattern("<a href=\"/admin/talk/posts\" class=\"active\"");
  }

  private Map<String, Object> feedbackModel() {
    AdminListQuery query = AdminListQuery.of(null, Map.of(), null, null, AdminFeedbackList.DEFINITION);
    Map<String, Object> model = new HashMap<>();
    model.put("feedbacks", new PageImpl<Feedback>(List.of()));
    model.put("definition", AdminFeedbackList.DEFINITION);
    model.put("query", query);
    model.put("statuses", FeedbackStatus.values());
    model.put("pagerBaseUrl", "/admin/feedback");
    return model;
  }

  @Test
  @DisplayName("posts_listsWithReportCount: 목록은 줄마다 제목·글쓴이(회원 링크)·상태·미처리 신고 수를 보이고 상세로 잇는다")
  void list_rendersRows() {
    String html = renderPosts(List.of(
      new TalkAdminPostRow(post("p1", "양치하기 루틴", TalkPostStatus.VISIBLE), "하늘", 3),
      new TalkAdminPostRow(post("p2", "가린 글 제목", TalkPostStatus.HIDDEN_BY_ADMIN), null, 0)));

    assertThat(html).contains("이야기 관리").contains("양치하기 루틴").contains("가린 글 제목")
      .contains("/admin/talk/posts/p1").contains("/admin/talk/posts/p2")
      .contains("하늘").contains("/admin/members/author-member-p1").contains("(닉네임 없음)")
      .contains("보이는 글").contains("가린 글")
      .contains("3건").contains("도움 4 · 댓글 2 · 가져감 1").contains("생활 습관").doesNotContain("SELF_CARE");
    assertThat(html).containsPattern("data-talk-report-count[^>]*>3건").containsPattern("data-talk-report-count[^>]*>0건");
  }

  @Test
  @DisplayName("목록에 처리하지 않은 신고 링크(건수 배지)가 있고, 0건이면 배지만 숨긴다")
  void list_showsUnresolvedReportLink() {
    AdminListQuery query = AdminListQuery.of(null, Map.of(), null, null, AdminTalkPostList.DEFINITION);

    String withReports = renderPosts(List.of(), query, 7);
    String withoutReports = renderPosts(List.of(), query, 0);

    assertThat(withReports).contains("/admin/talk/reports?resolved=false").containsPattern("badge-error badge-sm\"[^>]*>7<");
    assertThat(withoutReports).contains("/admin/talk/reports?resolved=false")
      .doesNotContainPattern("badge-error badge-sm\"[^>]*>0<");
  }

  @Test
  @DisplayName("목록에 상태 필터 칩·신고 수 정렬 헤더가 있고, 조건 유무에 따라 빈 목록 안내가 다르다")
  void list_filtersSortsAndEmptyMessages() {
    AdminListQuery withCondition = AdminListQuery.of("없는말", Map.of("status", "HIDDEN_BY_ADMIN"),
      "unresolvedReportCount,desc", null, AdminTalkPostList.DEFINITION);

    String html = renderPosts(List.of(), withCondition, 0);

    assertThat(html).contains("data-admin-filter-bar").contains("가린 글").contains("미처리 신고 ▼")
      .contains("조건에 맞는 글이 없어요");
    assertThat(renderPosts(List.of())).contains("아직 올라온 글이 없어요");
  }

  @Test
  @DisplayName("글쓴이가 내린 글(제목 빈 값)과 지운 댓글(본문 빈 값)도 깨지지 않고 안내 문구로 보인다")
  void deletedPostAndComment_renderPlaceholders() {
    TalkPost deleted = post("p1", "", TalkPostStatus.DELETED);
    deleted.setNote(null);
    TalkAdminPostDetail detail = new TalkAdminPostDetail(deleted, "하늘", List.of(),
      List.of(new CommentRow(comment("c1", "", TalkCommentStatus.DELETED), "바람")),
      List.of(new TalkAdminReportRow(report("r1", TalkReportTargetType.COMMENT, null), "달", "", "")));

    String list = renderPosts(List.of(new TalkAdminPostRow(deleted, "하늘", 0)));
    String detailHtml = renderDetail(detail);
    String reports = renderReports(List.of(new TalkAdminReportRow(report("r1", TalkReportTargetType.COMMENT, null), "달", "", "")));

    assertThat(list).contains("(지운 글)");
    assertThat(detailHtml).contains("(지운 글)").contains("(지운 댓글)");
    assertThat(reports).contains("(지운 글)").contains("(지운 댓글)");
  }

  @Test
  @DisplayName("글 제목·한마디·댓글은 사용자 입력이라 태그가 그대로 실행되지 않게 이스케이프한다")
  void escapesUserInput() {
    TalkPost hostile = post("p1", "<script>alert(1)</script>", TalkPostStatus.VISIBLE);
    hostile.setNote("<img src=x onerror=alert(2)>");
    TalkAdminPostDetail detail = new TalkAdminPostDetail(hostile, "<b>닉</b>", List.of(),
      List.of(new CommentRow(comment("c1", "<svg onload=alert(3)>", TalkCommentStatus.VISIBLE), null)), List.of());

    String list = renderPosts(List.of(new TalkAdminPostRow(hostile, "<b>닉</b>", 0)));
    String detailHtml = renderDetail(detail);

    assertThat(list).doesNotContain("<script>alert(1)</script>").contains("&lt;script&gt;alert(1)&lt;/script&gt;")
      .doesNotContain("<b>닉</b>");
    assertThat(detailHtml).doesNotContain("<script>alert(1)</script>").doesNotContain("<img src=x onerror")
      .doesNotContain("<svg onload").doesNotContain("<b>닉</b>")
      .contains("&lt;img src=x onerror=alert(2)&gt;").contains("&lt;svg onload=alert(3)&gt;");
  }

  @Test
  @DisplayName("상세는 글·글쓴이(회원 링크)·카드(올린 그림은 관리자 그림 주소, 없으면 픽토그램)·한마디를 보인다")
  void detail_rendersPostAndSteps() {
    String html = renderDetail(detailOf(post("p1", "양치하기 루틴", TalkPostStatus.VISIBLE)));

    assertThat(html).contains("이야기 글 상세").contains("양치하기 루틴").contains("글쓴이 한마디")
      .contains("하늘").contains("/admin/members/author-member-p1").contains("2026-10-20").contains("09:30:15")
      .contains("도움 4 · 댓글 2").contains("가져감 1").contains("생활 습관 · ").doesNotContain("SELF_CARE");
    assertThat(html).contains("src=\"/admin/talk/posts/p1/steps/0/image\"").contains("양치하기 0").contains("칫솔에 치약을 짜요")
      .contains("픽토그램 pict-7");
    assertThat(html).doesNotContain("/admin/talk/posts/p1/steps/1/image");
  }

  @Test
  @DisplayName("보이는 글에는 가리기만, 가린 글에는 되돌리기만, 지운 글에는 둘 다 없이 되돌릴 수 없다는 안내가 있다")
  void detail_postActionsFollowStatus() {
    String visible = renderDetail(detailOf(post("p1", "글", TalkPostStatus.VISIBLE)));
    String hidden = renderDetail(detailOf(post("p1", "글", TalkPostStatus.HIDDEN_BY_ADMIN)));
    String deleted = renderDetail(detailOf(post("p1", "글", TalkPostStatus.DELETED)));

    assertThat(visible).contains("action=\"/admin/talk/posts/p1/hide\"").doesNotContain("/admin/talk/posts/p1/restore");
    assertThat(hidden).contains("action=\"/admin/talk/posts/p1/restore\"").doesNotContain("/admin/talk/posts/p1/hide");
    assertThat(deleted).doesNotContain("/admin/talk/posts/p1/hide").doesNotContain("/admin/talk/posts/p1/restore")
      .contains("되돌릴 수 없어요");
  }

  @Test
  @DisplayName("상세의 댓글은 모든 상태를 보이고, 보이는 댓글은 가리기·가린 댓글은 되돌리기·지운 댓글은 버튼 없음이다")
  void detail_commentActionsFollowStatus() {
    String html = renderDetail(detailOf(post("p1", "글", TalkPostStatus.VISIBLE)));

    assertThat(html).contains("보이는 댓글이에요").contains("가린 댓글이에요").contains("지운 댓글이에요")
      .contains("구름").contains("/admin/members/commenter-member-c1")
      .contains("action=\"/admin/talk/comments/c1/hide\"").contains("action=\"/admin/talk/comments/c2/restore\"")
      .doesNotContain("/admin/talk/comments/c1/restore").doesNotContain("/admin/talk/comments/c2/hide")
      .doesNotContain("/admin/talk/comments/c3/");
  }

  @Test
  @DisplayName("상세의 신고는 대상·사유·신고자를 보이고, 미처리 신고에만 처리 버튼(상세로 돌아옴)이 있다")
  void detail_reportsShowResolveOnlyWhenUnresolved() {
    String html = renderDetail(detailOf(post("p1", "글", TalkPostStatus.VISIBLE)));

    assertThat(html).contains("개인정보 노출").contains("달").contains("/admin/members/reporter-member-r1")
      .contains("미처리").contains("처리 2026-10-20 10:30");
    assertThat(html).contains("action=\"/admin/talk/reports/r1/resolve\"").doesNotContain("/admin/talk/reports/r2/resolve")
      .contains("name=\"returnTo\" value=\"detail\"").doesNotContain("name=\"returnResolved\"");
  }

  @Test
  @DisplayName("신고 목록은 줄마다 대상·사유·신고자·글(링크)·처리 상태를 보이고, 미처리 신고에만 처리 폼이 현재 조건을 싣는다")
  void reports_rendersRowsAndResolveForm() {
    AdminListQuery query = AdminListQuery.of(null, Map.of("resolved", "false"), "createdAt,asc", "2",
      AdminTalkReportList.DEFINITION);
    List<TalkAdminReportRow> rows = List.of(
      new TalkAdminReportRow(report("r1", TalkReportTargetType.COMMENT, null), "달", "양치하기 루틴", "문제의 댓글"),
      new TalkAdminReportRow(report("r2", TalkReportTargetType.POST, CREATED_AT.plusHours(1)), null, null, null));

    String html = renderReports(rows, query);

    assertThat(html).contains("이야기 신고").contains("댓글").contains("문제의 댓글").contains("개인정보 노출")
      .contains("달").contains("(닉네임 없음)").contains("양치하기 루틴").contains("(찾을 수 없는 글)")
      .contains("/admin/talk/posts/p1").contains("미처리").contains("처리 2026-10-20 10:30");
    assertThat(html).contains("action=\"/admin/talk/reports/r1/resolve\"").doesNotContain("/admin/talk/reports/r2/resolve")
      .contains("name=\"returnTo\" value=\"list\"").contains("name=\"returnResolved\" value=\"false\"")
      .contains("name=\"returnSort\" value=\"createdAt,asc\"").contains("name=\"returnPage\" value=\"2\"");
  }

  @Test
  @DisplayName("신고 목록에 처리 여부 칩·정렬 헤더가 있고 조건 유무에 따라 빈 목록 안내가 다르다")
  void reports_filtersAndEmptyMessages() {
    AdminListQuery withCondition = AdminListQuery.of(null, Map.of("resolved", "true"), null, null,
      AdminTalkReportList.DEFINITION);

    String html = renderReports(List.of(), withCondition);

    assertThat(html).contains("data-admin-filter-bar").contains("미처리").contains("처리 완료").contains("접수 때 ▼")
      .contains("조건에 맞는 신고가 없어요");
    assertThat(renderReports(List.of())).contains("아직 들어온 신고가 없어요");
  }

  @Test
  @DisplayName("목록·상세·신고 화면의 여닫는 태그 수가 맞는다 — 짝이 안 맞으면 브라우저가 알아서 고쳐 그려 숨은 깨짐이 된다")
  void tagsBalanced() {
    TalkPost visible = post("p1", "글", TalkPostStatus.VISIBLE);
    List<TalkAdminReportRow> reportRows = List.of(
      new TalkAdminReportRow(report("r1", TalkReportTargetType.COMMENT, null), "달", "글", "댓글"));
    for (String html : List.of(
      renderPosts(List.of(new TalkAdminPostRow(visible, "하늘", 1))),
      renderPosts(List.of()),
      renderDetail(detailOf(visible)),
      renderDetail(detailOf(post("p1", "글", TalkPostStatus.DELETED))),
      renderReports(reportRows),
      renderReports(List.of()))) {
      for (String tag : TAGS) {
        assertThat(count(html, "<" + tag + "[\\s>]")).as("<%s> 여는 수", tag)
          .isEqualTo(count(html, "</" + tag + ">"));
      }
    }
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
