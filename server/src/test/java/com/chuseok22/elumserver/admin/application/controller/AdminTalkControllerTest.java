package com.chuseok22.elumserver.admin.application.controller;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminTalkPostList;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminChange;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostDetail;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostRow;
import com.chuseok22.elumserver.talk.application.service.TalkAdminService;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.data.domain.PageImpl;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.http.ResponseEntity;
import org.springframework.ui.ExtendedModelMap;
import org.springframework.web.servlet.mvc.support.RedirectAttributesModelMap;

class AdminTalkControllerTest {

  private final TalkAdminService talkAdminService = mock(TalkAdminService.class);
  private final AdminTalkController controller = new AdminTalkController(talkAdminService);
  private final RedirectAttributesModelMap redirect = new RedirectAttributesModelMap();

  private static TalkAdminChange changed(String postId) {
    return new TalkAdminChange(postId, TalkAdminChange.Result.CHANGED);
  }

  private static TalkAdminChange unchanged(String postId) {
    return new TalkAdminChange(postId, TalkAdminChange.Result.UNCHANGED);
  }

  @Test
  @DisplayName("posts_listsWithReportCount: 글 목록은 페이지·정의·조건·미처리 신고 수를 모델에 담아 목록 화면을 그린다")
  void posts_listsWithReportCount() {
    TalkPost post = new TalkPost();
    post.setId("p1");
    when(talkAdminService.searchPosts(any(), any(), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(new TalkAdminPostRow(post, "하늘", 2))));
    when(talkAdminService.countUnresolvedReports()).thenReturn(5L);
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.listPosts(null, null, null, "1", model);

    assertThat(view).isEqualTo("admin/talk");
    assertThat(model.get("posts")).isNotNull();
    assertThat(model.get("definition")).isSameAs(AdminTalkPostList.DEFINITION);
    assertThat(model.get("unresolvedReportCount")).isEqualTo(5L);
    assertThat(model.get("pagerBaseUrl")).isEqualTo("/admin/talk/posts?sort=createdAt,desc");
  }

  @Test
  @DisplayName("hidePosts_noSelection: 하나도 안 골랐으면 서비스를 부르지 않고 안내만 한다")
  void hidePosts_noSelection_onlyGuides() {
    String view = controller.hidePosts(null, redirect);

    assertThat(view).isEqualTo("redirect:/admin/talk/posts");
    assertThat(redirect.getFlashAttributes().get("errorMessage")).isEqualTo("가릴 글을 먼저 골라 주세요.");
    verify(talkAdminService, never()).hidePosts(any());
  }

  @Test
  @DisplayName("hidePosts_reportsHiddenCount: 고른 글을 가리고 가린 개수를 알린다")
  void hidePosts_reportsHiddenCount() {
    when(talkAdminService.hidePosts(List.of("p1", "p2"))).thenReturn(2);

    String view = controller.hidePosts(List.of("p1", "p2"), redirect);

    assertThat(view).isEqualTo("redirect:/admin/talk/posts");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("2개");
  }

  @Test
  @DisplayName("검색어·상태 필터·신고 수 정렬을 서비스 조건으로 옮기고, 검색어의 LIKE 특수문자는 이스케이프한다")
  void posts_translatesConditions() {
    when(talkAdminService.searchPosts(any(), any(), any(Pageable.class)))
      .thenReturn(new PageImpl<>(List.of(), PageRequest.of(1, 20), 25));

    controller.listPosts("50%", "HIDDEN_BY_ADMIN", "unresolvedReportCount,desc", "2", new ExtendedModelMap());

    ArgumentCaptor<Pageable> pageable = ArgumentCaptor.forClass(Pageable.class);
    verify(talkAdminService).searchPosts(eq("%50\\%%"), eq(TalkPostStatus.HIDDEN_BY_ADMIN), pageable.capture());
    assertThat(pageable.getValue().getPageNumber()).isEqualTo(1);
    assertThat(pageable.getValue().getSort().toString()).startsWith("unresolvedReportCount: DESC");
  }

  @Test
  @DisplayName("허용 밖 상태 필터·정렬은 무시하고 기본 조건(전체, 최신순)으로 조회한다")
  void posts_invalidConditionsFallBack() {
    when(talkAdminService.searchPosts(any(), any(), any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));

    controller.listPosts(null, "ARCHIVED", "title,asc;drop", "abc", new ExtendedModelMap());

    AdminListQuery defaultQuery = AdminListQuery.of(null, Map.of(), null, null, AdminTalkPostList.DEFINITION);
    verify(talkAdminService).searchPosts(null, null, PageRequest.of(0, 20, AdminTalkPostList.sortOf(defaultQuery)));
  }

  @Test
  @DisplayName("글 상세는 서비스가 모은 상세를 모델에 담는다")
  void postDetail_rendersDetail() {
    TalkAdminPostDetail detail = new TalkAdminPostDetail(new TalkPost(), null, List.of(), List.of(), List.of());
    when(talkAdminService.getPostDetail("p1")).thenReturn(detail);
    ExtendedModelMap model = new ExtendedModelMap();

    assertThat(controller.postDetail("p1", model)).isEqualTo("admin/talk-detail");
    assertThat(model.get("detail")).isSameAs(detail);
  }

  @Test
  @DisplayName("hide_setsHiddenByAdmin: 글 가리기는 서비스에 맡기고 그 글 상세로 돌아가 안내를 남긴다")
  void hide_setsHiddenByAdmin() {
    when(talkAdminService.hidePost("p1")).thenReturn(changed("p1"));

    String view = controller.hidePost("p1", redirect);

    verify(talkAdminService).hidePost("p1");
    assertThat(view).isEqualTo("redirect:/admin/talk/posts/p1");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("가렸어요");
  }

  @Test
  @DisplayName("restore_setsVisible: 글 되돌리기는 서비스에 맡기고 그 글 상세로 돌아간다")
  void restore_setsVisible() {
    when(talkAdminService.restorePost("p1")).thenReturn(changed("p1"));

    String view = controller.restorePost("p1", redirect);

    verify(talkAdminService).restorePost("p1");
    assertThat(view).isEqualTo("redirect:/admin/talk/posts/p1");
    assertThat((String) redirect.getFlashAttributes().get("message")).contains("되돌렸어요");
  }

  @Test
  @DisplayName("바뀐 것이 없으면(이미 가림·지운 글) 성공 안내 대신 이유를 오류 안내로 남긴다")
  void hide_unchanged_flashesError() {
    when(talkAdminService.hidePost("p1")).thenReturn(unchanged("p1"));

    controller.hidePost("p1", redirect);

    assertThat(redirect.getFlashAttributes()).containsKey("errorMessage").doesNotContainKey("message");
  }

  @Test
  @DisplayName("같은 일과의 보이는 글이 있어 되돌리지 못하면 그 사실을 안내한다")
  void restore_sourceAlreadyVisible_flashesReason() {
    when(talkAdminService.restorePost("p1"))
      .thenReturn(new TalkAdminChange("p1", TalkAdminChange.Result.SOURCE_ALREADY_VISIBLE));

    controller.restorePost("p1", redirect);

    assertThat((String) redirect.getFlashAttributes().get("errorMessage")).contains("같은 일과");
  }

  @Test
  @DisplayName("없는 글을 가리면 TALK_POST_NOT_FOUND 가 그대로 올라간다(오류 화면이 받는다)")
  void hide_notFound_propagates() {
    doThrow(new CustomException(ErrorCode.TALK_POST_NOT_FOUND)).when(talkAdminService).hidePost("nope");

    assertThatThrownBy(() -> controller.hidePost("nope", redirect)).isInstanceOf(CustomException.class);
  }

  @Test
  @DisplayName("댓글 가리기·되돌리기는 댓글이 속한 글 상세로 돌아간다")
  void comment_hideAndRestore_returnToPostDetail() {
    when(talkAdminService.hideComment("c1")).thenReturn(changed("p9"));
    when(talkAdminService.restoreComment("c1")).thenReturn(changed("p9"));

    assertThat(controller.hideComment("c1", redirect)).isEqualTo("redirect:/admin/talk/posts/p9");
    assertThat(controller.restoreComment("c1", redirect)).isEqualTo("redirect:/admin/talk/posts/p9");
    verify(talkAdminService).hideComment("c1");
    verify(talkAdminService).restoreComment("c1");
  }

  @Test
  @DisplayName("신고 목록은 처리 여부 필터를 서비스 조건으로 옮긴다 (resolved=false 는 미처리)")
  void reports_resolvedFilter() {
    when(talkAdminService.searchReports(any(), any(Pageable.class))).thenReturn(new PageImpl<>(List.of()));
    ExtendedModelMap model = new ExtendedModelMap();

    String view = controller.listReports("false", null, null, model);

    assertThat(view).isEqualTo("admin/talk-reports");
    verify(talkAdminService).searchReports(eq(Boolean.FALSE), any(Pageable.class));
    assertThat(model.get("pagerBaseUrl")).isEqualTo("/admin/talk/reports?resolved=false&sort=createdAt,desc");

    controller.listReports("ARCHIVED", null, null, new ExtendedModelMap());
    verify(talkAdminService).searchReports(eq(null), any(Pageable.class));
  }

  @Test
  @DisplayName("신고 처리는 글 상세에서 눌렀으면 그 글, 아니면 필터·정렬·페이지가 유지된 신고 목록으로 돌아간다")
  void resolveReport_returnsToWhereItCameFrom() {
    when(talkAdminService.resolveReport("r1")).thenReturn(changed("p1"));

    assertThat(controller.resolveReport("r1", "detail", null, null, null, redirect))
      .isEqualTo("redirect:/admin/talk/posts/p1");
    assertThat(controller.resolveReport("r1", "list", "false", "createdAt,asc", "3", redirect))
      .isEqualTo("redirect:/admin/talk/reports?resolved=false&sort=createdAt,asc&page=3");
  }

  @Test
  @DisplayName("신고 처리 돌아갈 곳 값이 조작돼도 정의로 보정되어 다른 주소로 나가지 않는다")
  void resolveReport_tamperedReturnValues() {
    when(talkAdminService.resolveReport("r1")).thenReturn(changed("p1"));

    String view = controller.resolveReport("r1", "list", "//evil.example", "https://evil.example", "x", redirect);

    assertThat(view).isEqualTo("redirect:/admin/talk/reports?sort=createdAt,desc");
  }

  @Test
  @DisplayName("stepImage_hiddenPost_stillServed: 카드 그림은 캐시하지 않고 내용 추측을 막아 내려 준다")
  void stepImage_hiddenPost_stillServed() {
    when(talkAdminService.stepImage("p1", 0)).thenReturn(new ImageContent(new byte[] {1, 2, 3}, "image/png"));

    ResponseEntity<byte[]> response = controller.stepImage("p1", 0);

    assertThat(response.getStatusCode().value()).isEqualTo(200);
    assertThat(response.getBody()).containsExactly(1, 2, 3);
    assertThat(response.getHeaders().getContentType().toString()).isEqualTo("image/png");
    assertThat(response.getHeaders().getCacheControl()).contains("no-store");
    assertThat(response.getHeaders().getFirst("X-Content-Type-Options")).isEqualTo("nosniff");
  }
}
