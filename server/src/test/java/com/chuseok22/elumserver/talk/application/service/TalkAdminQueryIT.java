package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminChange;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminPostRow;
import com.chuseok22.elumserver.talk.application.dto.response.TalkAdminReportRow;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkReportReason;
import com.chuseok22.elumserver.talk.core.TalkReportTargetType;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkReportRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 실제 Postgres 로 하는 이야기 관리자 쿼리 검증. 평소 빌드에서는 건너뛴다.
 * 제목 검색(LIKE ESCAPE)·상태 필터·신고 수 정렬·미처리 신고 집계·조건부 상태 전환·되돌리기 유니크 충돌이 실제 JPQL·인덱스로 도는지 본다.
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:5432/elum_it ELUM_IT_DB_USERNAME=me ./gradlew test --tests '*TalkAdminQueryIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=${ELUM_IT_DB_USERNAME:elum}",
  "spring.datasource.password=${ELUM_IT_DB_PASSWORD:pw}",
  "spring.flyway.enabled=false",
  "spring.jpa.hibernate.ddl-auto=${ELUM_IT_DDL_AUTO:update}",
  "gemini.api-key=rehearsal-invalid"
})
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class TalkAdminQueryIT {

  @Autowired private TalkAdminService talkAdminService;
  @Autowired private TalkPostRepository talkPostRepository;
  @Autowired private TalkCommentRepository talkCommentRepository;
  @Autowired private TalkReportRepository talkReportRepository;
  @Autowired private JdbcTemplate jdbcTemplate;

  private final String prefix = "it913_" + UUID.randomUUID().toString().substring(0, 8) + "_";

  @BeforeEach
  void createVisibleSourceUniqueIndex() {
    // V52 에만 있는 부분 유니크 인덱스 (JPA 로는 못 만듦)
    jdbcTemplate.execute("CREATE UNIQUE INDEX IF NOT EXISTS uk_talk_post_visible_source "
      + "ON talk_post (source_routine_id) WHERE status = 'VISIBLE'");
  }

  @AfterEach
  void cleanUp() {
    List<TalkPost> posts = talkPostRepository.findAll().stream()
      .filter(post -> post.getTitle().startsWith(prefix)).toList();
    for (TalkPost post : posts) {
      talkReportRepository.deleteAll(talkReportRepository.findByPostIdOrderByCreatedAtDescIdAsc(post.getId()));
      talkCommentRepository.deleteAll(talkCommentRepository.findByPostIdOrderByCreatedAtAscIdAsc(post.getId()));
    }
    talkPostRepository.deleteAll(posts);
  }

  private TalkPost newPost(String suffix, TalkPostStatus status, String sourceRoutineId) {
    TalkPost post = new TalkPost();
    post.setAuthorMemberId(prefix + "author");
    post.setSourceRoutineId(sourceRoutineId);
    post.setTitle(prefix + suffix);
    post.setCategory(TalkCategory.SELF_CARE);
    post.setStepCount(1);
    post.setStatus(status);
    TalkPost saved = talkPostRepository.saveAndFlush(post);
    // 생성 시각이 겹치지 않게 (정렬 확인용)
    try {
      Thread.sleep(5);
    } catch (InterruptedException e) {
      Thread.currentThread().interrupt();
    }
    return saved;
  }

  private TalkReport newReport(TalkPost post, TalkReportTargetType type, String targetId, String reporter,
    LocalDateTime resolvedAt) {
    TalkReport report = new TalkReport();
    report.setTargetType(type);
    report.setTargetId(targetId);
    report.setPostId(post.getId());
    report.setReporterMemberId(prefix + reporter);
    report.setReason(TalkReportReason.OFFENSIVE);
    report.setResolvedAt(resolvedAt);
    return talkReportRepository.saveAndFlush(report);
  }

  private List<String> postTitles(String pattern, TalkPostStatus status, Sort sort) {
    return talkAdminService.searchPosts(pattern, status, PageRequest.of(0, 50, sort)).getContent().stream()
      .map(row -> row.post().getTitle()).filter(title -> title.startsWith(prefix)).toList();
  }

  private static final Sort NEWEST_FIRST = Sort.by(Sort.Order.desc("createdAt"), Sort.Order.asc("id"));

  @Test
  @DisplayName("제목 검색(LIKE 특수문자는 글자)과 상태 필터가 실제 쿼리로 돈다")
  void searchPosts_keywordAndStatusFilter() {
    newPost("양치_하나", TalkPostStatus.VISIBLE, null);
    newPost("100% 양치", TalkPostStatus.HIDDEN_BY_ADMIN, null);

    assertThat(postTitles(null, null, NEWEST_FIRST)).hasSize(2);
    assertThat(postTitles(null, TalkPostStatus.HIDDEN_BY_ADMIN, NEWEST_FIRST)).containsExactly(prefix + "100% 양치");
    assertThat(postTitles(null, TalkPostStatus.DELETED, NEWEST_FIRST)).isEmpty();
    assertThat(postTitles("%" + prefix + "100\\%%", null, NEWEST_FIRST)).containsExactly(prefix + "100% 양치");
    assertThat(postTitles("%" + prefix + "양치\\_%", null, NEWEST_FIRST)).containsExactly(prefix + "양치_하나");
    assertThat(postTitles("%" + prefix + "양치X%", null, NEWEST_FIRST)).isEmpty();
  }

  @Test
  @DisplayName("미처리 신고 수 정렬: 많은 순·적은 순이 돌고, 처리한 신고와 댓글 신고도 글 기준으로 센다")
  void searchPosts_sortByUnresolvedReports() {
    TalkPost quiet = newPost("조용", TalkPostStatus.VISIBLE, null);
    TalkPost noisy = newPost("시끌", TalkPostStatus.VISIBLE, null);
    TalkPost resolvedOnly = newPost("처리끝", TalkPostStatus.VISIBLE, null);
    newReport(noisy, TalkReportTargetType.POST, noisy.getId(), "a", null);
    newReport(noisy, TalkReportTargetType.COMMENT, "comment-x", "b", null);
    newReport(noisy, TalkReportTargetType.POST, noisy.getId(), "c", LocalDateTime.now());
    newReport(resolvedOnly, TalkReportTargetType.POST, resolvedOnly.getId(), "a", LocalDateTime.now());
    newReport(quiet, TalkReportTargetType.POST, quiet.getId(), "a", null);

    Sort descending = Sort.by(Sort.Order.desc(TalkAdminService.SORT_UNRESOLVED_REPORT_COUNT), Sort.Order.asc("id"));
    Sort ascending = Sort.by(Sort.Order.asc(TalkAdminService.SORT_UNRESOLVED_REPORT_COUNT), Sort.Order.asc("id"));

    assertThat(postTitles(null, null, descending))
      .containsExactly(prefix + "시끌", prefix + "조용", prefix + "처리끝");
    assertThat(postTitles(null, null, ascending)).containsExactly(prefix + "처리끝", prefix + "조용", prefix + "시끌");
    List<TalkAdminPostRow> rows = talkAdminService.searchPosts("%" + prefix + "%", null, PageRequest.of(0, 50, descending))
      .getContent().stream().filter(row -> row.post().getTitle().startsWith(prefix)).toList();
    assertThat(rows).extracting(TalkAdminPostRow::unresolvedReportCount).containsExactly(2L, 1L, 0L);
  }

  @Test
  @DisplayName("올린 때·상태 정렬과 페이지 개수(count 쿼리)가 돈다")
  void searchPosts_otherSortsAndTotals() {
    newPost("a", TalkPostStatus.VISIBLE, null);
    newPost("b", TalkPostStatus.HIDDEN_BY_ADMIN, null);

    assertThat(postTitles(null, null, Sort.by(Sort.Order.asc("createdAt"), Sort.Order.asc("id"))))
      .containsExactly(prefix + "a", prefix + "b");
    assertThat(postTitles(null, null, Sort.by(Sort.Order.desc("status"), Sort.Order.asc("id"))))
      .containsExactly(prefix + "a", prefix + "b");
    assertThat(talkAdminService.searchPosts("%" + prefix + "%", null,
      PageRequest.of(0, 1, Sort.by(Sort.Order.desc(TalkAdminService.SORT_UNRESOLVED_REPORT_COUNT)))).getTotalElements())
      .isEqualTo(2);
  }

  @Test
  @DisplayName("가리기·되돌리기는 조건부 갱신이라 지운 글은 그대로이고, 같은 일과의 보이는 글이 있으면 되돌리지 못한다")
  void hideAndRestore_conditionalAndUniqueConflict() {
    String sourceRoutineId = prefix + "routine";
    TalkPost hiddenOld = newPost("가린 옛 글", TalkPostStatus.HIDDEN_BY_ADMIN, sourceRoutineId);
    TalkPost deleted = newPost("지운 글", TalkPostStatus.DELETED, null);

    assertThat(talkAdminService.restorePost(deleted.getId()).result()).isEqualTo(TalkAdminChange.Result.UNCHANGED);
    assertThat(talkAdminService.hidePost(deleted.getId()).result()).isEqualTo(TalkAdminChange.Result.UNCHANGED);
    assertThat(talkPostRepository.findById(deleted.getId()).orElseThrow().getStatus()).isEqualTo(TalkPostStatus.DELETED);

    // 숨긴 사이 같은 일과로 새 글이 올라온 경우
    newPost("새 글", TalkPostStatus.VISIBLE, sourceRoutineId);
    assertThat(talkAdminService.restorePost(hiddenOld.getId()).result())
      .isEqualTo(TalkAdminChange.Result.SOURCE_ALREADY_VISIBLE);
    assertThat(talkPostRepository.findById(hiddenOld.getId()).orElseThrow().getStatus())
      .isEqualTo(TalkPostStatus.HIDDEN_BY_ADMIN);

    // 새 글을 가리면 되돌릴 수 있고, 되돌린 글을 다시 가릴 수 있다
    TalkPost visibleNew = talkPostRepository.findAll().stream()
      .filter(post -> (prefix + "새 글").equals(post.getTitle())).findFirst().orElseThrow();
    assertThat(talkAdminService.hidePost(visibleNew.getId()).isChanged()).isTrue();
    assertThat(talkAdminService.restorePost(hiddenOld.getId()).isChanged()).isTrue();
    assertThat(talkPostRepository.findById(hiddenOld.getId()).orElseThrow().getStatus()).isEqualTo(TalkPostStatus.VISIBLE);
    assertThat(talkAdminService.hidePost(hiddenOld.getId()).isChanged()).isTrue();
  }

  @Test
  @DisplayName("댓글 가리기·되돌리기는 글의 댓글 수를 한 번씩만 줄이고 늘린다")
  void hideAndRestoreComment_adjustsCommentCountOnce() {
    TalkPost post = newPost("댓글 글", TalkPostStatus.VISIBLE, null);
    post.setCommentCount(1);
    talkPostRepository.saveAndFlush(post);
    TalkComment comment = new TalkComment();
    comment.setPostId(post.getId());
    comment.setAuthorMemberId(prefix + "commenter");
    comment.setBody("댓글");
    comment = talkCommentRepository.saveAndFlush(comment);

    assertThat(talkAdminService.hideComment(comment.getId()).isChanged()).isTrue();
    assertThat(talkAdminService.hideComment(comment.getId()).isChanged()).isFalse();
    assertThat(talkPostRepository.findById(post.getId()).orElseThrow().getCommentCount()).isZero();

    assertThat(talkAdminService.restoreComment(comment.getId()).isChanged()).isTrue();
    assertThat(talkAdminService.restoreComment(comment.getId()).isChanged()).isFalse();
    assertThat(talkPostRepository.findById(post.getId()).orElseThrow().getCommentCount()).isEqualTo(1);
    assertThat(talkCommentRepository.findById(comment.getId()).orElseThrow().getStatus())
      .isEqualTo(TalkCommentStatus.VISIBLE);
  }

  @Test
  @DisplayName("신고 목록: 처리 여부 필터·정렬이 돌고, 처리 시각은 한 번만 기록된다")
  void reports_filterSortAndResolveOnce() {
    TalkPost post = newPost("신고 글", TalkPostStatus.VISIBLE, null);
    TalkReport open = newReport(post, TalkReportTargetType.POST, post.getId(), "a", null);
    TalkReport done = newReport(post, TalkReportTargetType.POST, post.getId(), "b", LocalDateTime.of(2026, 10, 1, 9, 0));
    Sort byResolvedAt = Sort.by(Sort.Order.desc("resolvedAt").with(Sort.NullHandling.NULLS_LAST), Sort.Order.asc("id"));

    List<String> unresolved = reportIds(Boolean.FALSE, byResolvedAt);
    List<String> resolved = reportIds(Boolean.TRUE, byResolvedAt);
    List<String> all = reportIds(null, byResolvedAt);

    assertThat(unresolved).contains(open.getId()).doesNotContain(done.getId());
    assertThat(resolved).contains(done.getId()).doesNotContain(open.getId());
    assertThat(all).contains(open.getId(), done.getId());
    // 처리한 신고가 먼저, 안 한(null) 신고는 뒤로
    assertThat(all.indexOf(done.getId())).isLessThan(all.indexOf(open.getId()));

    assertThat(talkAdminService.resolveReport(open.getId()).isChanged()).isTrue();
    LocalDateTime firstResolvedAt = talkReportRepository.findById(open.getId()).orElseThrow().getResolvedAt();
    assertThat(firstResolvedAt).isNotNull();
    assertThat(talkAdminService.resolveReport(open.getId()).isChanged()).isFalse();
    assertThat(talkReportRepository.findById(open.getId()).orElseThrow().getResolvedAt()).isEqualTo(firstResolvedAt);
    assertThat(talkAdminService.countUnresolvedReports()).isGreaterThanOrEqualTo(0);
  }

  private List<String> reportIds(Boolean resolvedFilter, Sort sort) {
    return talkAdminService.searchReports(resolvedFilter, PageRequest.of(0, 200, sort)).getContent().stream()
      .map(TalkAdminReportRow::report).map(TalkReport::getId).toList();
  }
}
