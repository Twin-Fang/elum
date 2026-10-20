package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkHelpful;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkImport;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkHelpfulRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.data.domain.PageRequest;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 실제 Postgres 로 하는 이야기 쿼리 검증. 평소 빌드에서는 건너뛴다.
 * 피드·인기·댓글 쪽, 집계 증감(@Modifying), 조건부 지우기, 다시 세기, 바뀐 칼럼만 UPDATE 가 실제 JPQL 로 도는지 본다.
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:5432/elum_it ELUM_IT_DB_USERNAME=me ./gradlew test --tests '*TalkQueryIT'
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
class TalkQueryIT {

  private static final LocalDateTime FAR_FUTURE = LocalDateTime.of(9999, 12, 31, 0, 0);

  @Autowired private TalkPostRepository talkPostRepository;
  @Autowired private TalkCommentRepository talkCommentRepository;
  @Autowired private TalkHelpfulRepository talkHelpfulRepository;
  @Autowired private TalkImportRepository talkImportRepository;
  @Autowired private JdbcTemplate jdbcTemplate;
  @Autowired private PlatformTransactionManager transactionManager;

  private final String prefix = "it913q_" + UUID.randomUUID().toString().substring(0, 8) + "_";

  @AfterEach
  void cleanUp() {
    // 이 테스트가 만든 행만 (접두사 기준)
    String like = prefix + "%";
    jdbcTemplate.update("delete from talk_import where member_id like ?", like);
    jdbcTemplate.update("delete from talk_helpful where member_id like ?", like);
    jdbcTemplate.update("delete from talk_comment where author_member_id like ?", like);
    jdbcTemplate.update("delete from talk_post where author_member_id like ?", like);
  }

  private TalkPost newPost(String suffix, TalkCategory category, AppLocale language, LocalDateTime createdAt) {
    TalkPost post = new TalkPost();
    post.setAuthorMemberId(prefix + "author");
    post.setTitle(prefix + suffix);
    post.setNote("note " + suffix);
    post.setCategory(category);
    post.setLanguage(language);
    post.setStepCount(1);
    TalkPost saved = talkPostRepository.saveAndFlush(post);
    // 정렬을 고정하려고 올린 시각을 직접 지정
    jdbcTemplate.update("update talk_post set created_at = ? where id = ?", createdAt, saved.getId());
    return saved;
  }

  private void addImport(String postId, String memberId, LocalDateTime createdAt) {
    TalkImport talkImport = new TalkImport();
    talkImport.setPostId(postId);
    talkImport.setMemberId(prefix + memberId);
    talkImport.setProfileId("profile");
    talkImport.setRoutineId("routine-" + UUID.randomUUID());
    TalkImport saved = talkImportRepository.saveAndFlush(talkImport);
    jdbcTemplate.update("update talk_import set created_at = ? where id = ?", createdAt, saved.getId());
  }

  private TalkComment addComment(String postId, String suffix, LocalDateTime createdAt) {
    TalkComment comment = new TalkComment();
    comment.setPostId(postId);
    comment.setAuthorMemberId(prefix + "commenter");
    comment.setBody("body " + suffix);
    TalkComment saved = talkCommentRepository.saveAndFlush(comment);
    jdbcTemplate.update("update talk_comment set created_at = ? where id = ?", createdAt, saved.getId());
    return saved;
  }

  private TalkPost reload(String postId) {
    return talkPostRepository.findById(postId).orElseThrow();
  }

  @Test
  @DisplayName("피드 한 쪽: 같은 언어·분류의 보이는 글만 최신순, cursor 이후만")
  void findFeedPage_filtersAndOrdersAndHonorsCursor() {
    LocalDateTime base = LocalDateTime.of(2026, 10, 20, 12, 0);
    TalkPost oldest = newPost("oldest", TalkCategory.SELF_CARE, AppLocale.KO, base.minusHours(3));
    TalkPost middle = newPost("middle", TalkCategory.SELF_CARE, AppLocale.KO, base.minusHours(2));
    TalkPost newest = newPost("newest", TalkCategory.SELF_CARE, AppLocale.KO, base.minusHours(1));
    newPost("other-category", TalkCategory.FEELINGS, AppLocale.KO, base);
    newPost("other-language", TalkCategory.SELF_CARE, AppLocale.EN, base);
    TalkPost hidden = newPost("hidden", TalkCategory.SELF_CARE, AppLocale.KO, base);
    talkPostRepository.updateStatusIfCurrent(hidden.getId(), TalkPostStatus.HIDDEN_BY_ADMIN, TalkPostStatus.VISIBLE);

    List<TalkPost> firstPage = talkPostRepository.findFeedPage(TalkPostStatus.VISIBLE, AppLocale.KO,
      List.of(TalkCategory.SELF_CARE), FAR_FUTURE, "", PageRequest.of(0, 10));
    List<TalkPost> afterNewest = talkPostRepository.findFeedPage(TalkPostStatus.VISIBLE, AppLocale.KO,
      List.of(TalkCategory.SELF_CARE), base.minusHours(1), newest.getId(), PageRequest.of(0, 10));

    assertThat(firstPage).extracting(TalkPost::getId).containsExactly(newest.getId(), middle.getId(), oldest.getId());
    assertThat(afterNewest).extracting(TalkPost::getId).containsExactly(middle.getId(), oldest.getId());
  }

  @Test
  @DisplayName("인기 글: 기간 안 가져간 고유 보호자 수 내림차순, 같은 보호자의 반복은 한 번, 기간 밖은 제외")
  void findPopularPostIds_ranksByDistinctMembersInWindow() {
    LocalDateTime now = LocalDateTime.of(2026, 10, 20, 12, 0);
    TalkPost popular = newPost("popular", TalkCategory.DAILY_FLOW, AppLocale.KO, now.minusDays(1));
    TalkPost modest = newPost("modest", TalkCategory.DAILY_FLOW, AppLocale.KO, now.minusDays(1));
    TalkPost outsideWindow = newPost("outside", TalkCategory.DAILY_FLOW, AppLocale.KO, now.minusDays(1));
    newPost("no-import", TalkCategory.DAILY_FLOW, AppLocale.KO, now.minusDays(1));
    addImport(popular.getId(), "a", now.minusDays(1));
    addImport(popular.getId(), "b", now.minusDays(2));
    addImport(modest.getId(), "a", now.minusDays(1));
    // 같은 보호자 세 번은 한 명
    addImport(modest.getId(), "a", now.minusHours(5));
    addImport(modest.getId(), "a", now.minusHours(4));
    addImport(outsideWindow.getId(), "a", now.minusDays(30));

    List<String> ranked = talkPostRepository.findPopularPostIds(TalkPostStatus.VISIBLE, AppLocale.KO,
      List.of(TalkCategory.DAILY_FLOW), now.minusDays(7), PageRequest.of(0, 10));

    assertThat(ranked).containsExactly(popular.getId(), modest.getId());
  }

  @Test
  @DisplayName("댓글 한 쪽: 보이는 댓글만 오래된 순, cursor 이후만")
  void findCommentPage_ordersAndHonorsCursor() {
    TalkPost post = newPost("commented", TalkCategory.SELF_CARE, AppLocale.KO, LocalDateTime.of(2026, 10, 20, 8, 0));
    LocalDateTime base = LocalDateTime.of(2026, 10, 20, 9, 0);
    TalkComment first = addComment(post.getId(), "first", base);
    TalkComment second = addComment(post.getId(), "second", base.plusMinutes(1));
    TalkComment third = addComment(post.getId(), "third", base.plusMinutes(2));
    TalkComment deleted = addComment(post.getId(), "deleted", base.plusMinutes(3));
    talkCommentRepository.updateStatusIfVisible(deleted.getId(), TalkCommentStatus.DELETED, TalkCommentStatus.VISIBLE);

    List<TalkComment> firstPage = talkCommentRepository.findCommentPage(post.getId(), TalkCommentStatus.VISIBLE,
      LocalDateTime.of(1970, 1, 1, 0, 0), "", PageRequest.of(0, 10));
    List<TalkComment> afterFirst = talkCommentRepository.findCommentPage(post.getId(), TalkCommentStatus.VISIBLE,
      base, first.getId(), PageRequest.of(0, 10));

    assertThat(firstPage).extracting(TalkComment::getId).containsExactly(first.getId(), second.getId(), third.getId());
    assertThat(afterFirst).extracting(TalkComment::getId).containsExactly(second.getId(), third.getId());
  }

  @Test
  @DisplayName("집계 증감: 도움·댓글·가져감은 DB 에서 바로 +1 되고, 줄일 때는 0 아래로 내려가지 않는다")
  void counters_increaseAndDecreaseWithoutGoingNegative() {
    TalkPost post = newPost("counters", TalkCategory.SELF_CARE, AppLocale.KO, LocalDateTime.of(2026, 10, 20, 8, 0));

    assertThat(talkPostRepository.increaseHelpfulCount(post.getId())).isEqualTo(1);
    assertThat(talkPostRepository.increaseHelpfulCount(post.getId())).isEqualTo(1);
    assertThat(talkPostRepository.increaseCommentCount(post.getId())).isEqualTo(1);
    assertThat(talkPostRepository.increaseImportCount(post.getId())).isEqualTo(1);
    assertThat(talkPostRepository.increaseImportCount(post.getId())).isEqualTo(1);
    assertThat(talkPostRepository.increaseImportCount(post.getId())).isEqualTo(1);

    TalkPost increased = reload(post.getId());
    assertThat(increased.getHelpfulCount()).isEqualTo(2);
    assertThat(increased.getCommentCount()).isEqualTo(1);
    assertThat(increased.getImportCount()).isEqualTo(3);

    assertThat(talkPostRepository.decreaseHelpfulCount(post.getId())).isEqualTo(1);
    assertThat(talkPostRepository.decreaseCommentCount(post.getId())).isEqualTo(1);
    // 0 이면 바뀐 행 없음
    assertThat(talkPostRepository.decreaseCommentCount(post.getId())).isZero();
    TalkPost decreased = reload(post.getId());
    assertThat(decreased.getHelpfulCount()).isEqualTo(1);
    assertThat(decreased.getCommentCount()).isZero();
  }

  @Test
  @DisplayName("댓글 지우기: 보이는 댓글만 DELETED 로 바꾸고 본문을 비운다, 다시 지우면 0건")
  void updateStatusIfVisible_marksDeletedAndClearsBodyOnce() {
    TalkPost post = newPost("deleting", TalkCategory.SELF_CARE, AppLocale.KO, LocalDateTime.of(2026, 10, 20, 8, 0));
    TalkComment comment = addComment(post.getId(), "to-delete", LocalDateTime.of(2026, 10, 20, 9, 0));

    int firstChanged = talkCommentRepository.updateStatusIfVisible(
      comment.getId(), TalkCommentStatus.DELETED, TalkCommentStatus.VISIBLE);
    int secondChanged = talkCommentRepository.updateStatusIfVisible(
      comment.getId(), TalkCommentStatus.DELETED, TalkCommentStatus.VISIBLE);

    assertThat(firstChanged).isEqualTo(1);
    assertThat(secondChanged).isZero();
    TalkComment deleted = talkCommentRepository.findById(comment.getId()).orElseThrow();
    assertThat(deleted.getStatus()).isEqualTo(TalkCommentStatus.DELETED);
    assertThat(deleted.getBody()).isEmpty();
  }

  @Test
  @DisplayName("도움 취소: 지운 건수를 돌려준다 (누른 적 없으면 0)")
  void deleteByPostIdAndMemberId_returnsDeletedCount() {
    TalkPost post = newPost("helpful", TalkCategory.SELF_CARE, AppLocale.KO, LocalDateTime.of(2026, 10, 20, 8, 0));
    TalkHelpful helpful = new TalkHelpful();
    helpful.setPostId(post.getId());
    helpful.setMemberId(prefix + "helper");
    talkHelpfulRepository.saveAndFlush(helpful);

    assertThat(talkHelpfulRepository.deleteByPostIdAndMemberId(post.getId(), prefix + "helper")).isEqualTo(1);
    assertThat(talkHelpfulRepository.deleteByPostIdAndMemberId(post.getId(), prefix + "helper")).isZero();
  }

  @Test
  @DisplayName("다시 세기: 도움은 행 수, 댓글은 보이는 것만, 가져감은 고유 보호자 수")
  void recountCounts_useRowsAndDistinctImporters() {
    TalkPost post = newPost("recount", TalkCategory.SELF_CARE, AppLocale.KO, LocalDateTime.of(2026, 10, 20, 8, 0));
    // 집계를 일부러 틀리게 둔다
    jdbcTemplate.update("update talk_post set helpful_count = 9, comment_count = 9, import_count = 9 where id = ?",
      post.getId());
    for (String helper : List.of("h1", "h2")) {
      TalkHelpful helpful = new TalkHelpful();
      helpful.setPostId(post.getId());
      helpful.setMemberId(prefix + helper);
      talkHelpfulRepository.saveAndFlush(helpful);
    }
    addComment(post.getId(), "visible", LocalDateTime.of(2026, 10, 20, 9, 0));
    TalkComment deleted = addComment(post.getId(), "deleted", LocalDateTime.of(2026, 10, 20, 9, 1));
    talkCommentRepository.updateStatusIfVisible(deleted.getId(), TalkCommentStatus.DELETED, TalkCommentStatus.VISIBLE);
    // 같은 보호자가 두 번, 다른 보호자가 한 번 = 고유 2명
    addImport(post.getId(), "a", LocalDateTime.of(2026, 10, 20, 9, 0));
    addImport(post.getId(), "a", LocalDateTime.of(2026, 10, 20, 10, 0));
    addImport(post.getId(), "b", LocalDateTime.of(2026, 10, 20, 11, 0));
    List<String> postIds = List.of(post.getId());

    talkPostRepository.recountHelpfulCounts(postIds);
    talkPostRepository.recountCommentCounts(postIds);
    talkPostRepository.recountImportCounts(postIds);

    TalkPost recounted = reload(post.getId());
    assertThat(recounted.getHelpfulCount()).isEqualTo(2);
    assertThat(recounted.getCommentCount()).isEqualTo(1);
    assertThat(recounted.getImportCount()).isEqualTo(2);
  }

  @Test
  @DisplayName("글 고치기·내리기는 바뀐 칼럼만 UPDATE 해서 그 사이 오른 집계를 덮어쓰지 않는다")
  void dynamicUpdate_doesNotOverwriteConcurrentCounters() {
    TalkPost post = newPost("dynamic", TalkCategory.SELF_CARE, AppLocale.KO, LocalDateTime.of(2026, 10, 20, 8, 0));
    TransactionTemplate transaction = new TransactionTemplate(transactionManager);

    transaction.executeWithoutResult(status -> {
      // 읽은 뒤 다른 요청이 집계를 올린 상황을 같은 트랜잭션에서 흉내냄
      TalkPost loaded = talkPostRepository.findById(post.getId()).orElseThrow();
      talkPostRepository.increaseImportCount(post.getId());
      talkPostRepository.increaseHelpfulCount(post.getId());
      loaded.setNote("changed note");
      talkPostRepository.saveAndFlush(loaded);
    });

    TalkPost afterEdit = reload(post.getId());
    assertThat(afterEdit.getNote()).isEqualTo("changed note");
    assertThat(afterEdit.getImportCount()).isEqualTo(1);
    assertThat(afterEdit.getHelpfulCount()).isEqualTo(1);

    transaction.executeWithoutResult(status -> {
      TalkPost loaded = talkPostRepository.findById(post.getId()).orElseThrow();
      talkPostRepository.increaseCommentCount(post.getId());
      loaded.setTitle("");
      loaded.setNote(null);
      loaded.setStatus(TalkPostStatus.DELETED);
      talkPostRepository.saveAndFlush(loaded);
    });

    TalkPost afterDelete = reload(post.getId());
    assertThat(afterDelete.getStatus()).isEqualTo(TalkPostStatus.DELETED);
    assertThat(afterDelete.getTitle()).isEmpty();
    assertThat(afterDelete.getNote()).isNull();
    assertThat(afterDelete.getCommentCount()).isEqualTo(1);
  }
}
