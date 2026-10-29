package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.talk.core.TalkCategory;
import com.chuseok22.elumserver.talk.core.TalkCommentStatus;
import com.chuseok22.elumserver.talk.core.TalkReportReason;
import com.chuseok22.elumserver.talk.core.TalkReportTargetType;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkBlock;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkComment;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkHelpful;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkImport;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkReport;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkBlockRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkCommentRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkHelpfulRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkImportRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkReportRepository;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.jdbc.core.JdbcTemplate;

/**
 * 실제 Postgres 로 하는 이야기 탈퇴 정리 검증. 평소 빌드에서는 건너뛴다.
 * 벌크 삭제의 서브쿼리와 집계 재계산(cast 서브쿼리)이 실제 JPQL 로 도는지 본다.
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:5432/elum_it ELUM_IT_DB_USERNAME=me ./gradlew test --tests '*TalkCleanupIT'
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
class TalkCleanupIT {

  @Autowired private TalkCleanupService talkCleanupService;
  @Autowired private TalkPostRepository talkPostRepository;
  @Autowired private TalkPostStepRepository talkPostStepRepository;
  @Autowired private TalkCommentRepository talkCommentRepository;
  @Autowired private TalkHelpfulRepository talkHelpfulRepository;
  @Autowired private TalkImportRepository talkImportRepository;
  @Autowired private TalkReportRepository talkReportRepository;
  @Autowired private TalkBlockRepository talkBlockRepository;
  @Autowired private JdbcTemplate jdbcTemplate;

  private final String prefix = "it912_" + UUID.randomUUID().toString().substring(0, 8) + "_";
  private final String leaver = prefix + "leaver";
  private final String stayer = prefix + "stayer";
  private final String bystander = prefix + "bystander";

  @AfterEach
  void cleanUp() {
    // 이 테스트가 만든 행만 (접두사 회원 기준)
    String like = prefix + "%";
    jdbcTemplate.update("delete from talk_report where reporter_member_id like ?", like);
    jdbcTemplate.update("delete from talk_helpful where member_id like ?", like);
    jdbcTemplate.update("delete from talk_import where member_id like ?", like);
    jdbcTemplate.update("delete from talk_comment where author_member_id like ?", like);
    jdbcTemplate.update("delete from talk_block where blocker_member_id like ?", like);
    jdbcTemplate.update("delete from talk_post_step where post_id in (select id from talk_post where author_member_id like ?)", like);
    jdbcTemplate.update("delete from talk_post where author_member_id like ?", like);
  }

  private TalkPost newPost(String authorMemberId, String title, int helpfulCount, int commentCount, int importCount) {
    TalkPost post = new TalkPost();
    post.setAuthorMemberId(authorMemberId);
    post.setTitle(prefix + title);
    post.setCategory(TalkCategory.SELF_CARE);
    post.setStepCount(1);
    post.setHelpfulCount(helpfulCount);
    post.setCommentCount(commentCount);
    post.setImportCount(importCount);
    return talkPostRepository.saveAndFlush(post);
  }

  private void addHelpful(String postId, String memberId) {
    TalkHelpful helpful = new TalkHelpful();
    helpful.setPostId(postId);
    helpful.setMemberId(memberId);
    talkHelpfulRepository.saveAndFlush(helpful);
  }

  private TalkComment addComment(String postId, String memberId, TalkCommentStatus status) {
    TalkComment comment = new TalkComment();
    comment.setPostId(postId);
    comment.setAuthorMemberId(memberId);
    comment.setBody("body");
    comment.setStatus(status);
    return talkCommentRepository.saveAndFlush(comment);
  }

  private void addImport(String postId, String memberId) {
    TalkImport talkImport = new TalkImport();
    talkImport.setPostId(postId);
    talkImport.setMemberId(memberId);
    talkImport.setProfileId("profile");
    talkImport.setRoutineId("routine-" + UUID.randomUUID());
    talkImportRepository.saveAndFlush(talkImport);
  }

  private TalkReport addReport(String postId, TalkReportTargetType type, String targetId, String reporter) {
    TalkReport report = new TalkReport();
    report.setTargetType(type);
    report.setTargetId(targetId);
    report.setPostId(postId);
    report.setReporterMemberId(reporter);
    report.setReason(TalkReportReason.OFFENSIVE);
    return talkReportRepository.saveAndFlush(report);
  }

  private void addBlock(String blocker, String blocked) {
    TalkBlock block = new TalkBlock();
    block.setBlockerMemberId(blocker);
    block.setBlockedMemberId(blocked);
    talkBlockRepository.saveAndFlush(block);
  }

  @Test
  @DisplayName("탈퇴자의 글·카드·댓글·반응·신고·차단·가져가기를 지우고 남의 글 집계를 행 수로 다시 센다")
  void deleteAllOf_removesLeaversRows_andRecountsStayersPost() {
    TalkPost leaversPost = newPost(leaver, "leaver", 1, 1, 0);
    TalkPostStep step = new TalkPostStep();
    step.setPostId(leaversPost.getId());
    step.setStepOrder(0);
    step.setTitle("step");
    step.setDescription("description");
    talkPostStepRepository.saveAndFlush(step);
    // 집계를 일부러 틀리게 둔다 (실제 행: 도움 2·보이는 댓글 2·가져간 보호자 2, 이 중 탈퇴자 몫이 하나씩)
    TalkPost stayersPost = newPost(stayer, "stayer", 3, 5, 4);

    addHelpful(stayersPost.getId(), leaver);
    addHelpful(stayersPost.getId(), bystander);
    addHelpful(leaversPost.getId(), stayer);
    TalkComment leaversCommentOnStayers = addComment(stayersPost.getId(), leaver, TalkCommentStatus.VISIBLE);
    addComment(stayersPost.getId(), bystander, TalkCommentStatus.VISIBLE);
    // 가린 댓글은 집계에 들지 않는다
    addComment(stayersPost.getId(), bystander, TalkCommentStatus.HIDDEN_BY_ADMIN);
    TalkComment stayersCommentOnLeavers = addComment(leaversPost.getId(), stayer, TalkCommentStatus.VISIBLE);
    addImport(stayersPost.getId(), leaver);
    addImport(stayersPost.getId(), bystander);
    // 같은 보호자의 두 번째 가져가기 (기록은 두 행, 가져간 수는 한 명)
    addImport(stayersPost.getId(), bystander);
    addImport(leaversPost.getId(), stayer);
    TalkReport reportByLeaver = addReport(stayersPost.getId(), TalkReportTargetType.POST, stayersPost.getId(), leaver);
    TalkReport reportOnLeaversPost = addReport(leaversPost.getId(), TalkReportTargetType.POST, leaversPost.getId(), stayer);
    TalkReport reportOnLeaversComment = addReport(stayersPost.getId(), TalkReportTargetType.COMMENT,
      leaversCommentOnStayers.getId(), stayer);
    TalkReport reportOnCommentOfLeaversPost = addReport(leaversPost.getId(), TalkReportTargetType.COMMENT,
      stayersCommentOnLeavers.getId(), bystander);
    TalkReport unrelatedReport = addReport(stayersPost.getId(), TalkReportTargetType.POST, stayersPost.getId(), bystander);
    addBlock(leaver, stayer);
    addBlock(stayer, leaver);
    addBlock(bystander, stayer);

    talkCleanupService.deleteAllOf(leaver);

    // 탈퇴자 쪽은 전부 사라짐
    assertThat(talkPostRepository.findById(leaversPost.getId())).isEmpty();
    assertThat(talkPostStepRepository.findByPostIdOrderByStepOrderAsc(leaversPost.getId())).isEmpty();
    assertThat(talkCommentRepository.findById(leaversCommentOnStayers.getId())).isEmpty();
    assertThat(talkCommentRepository.findById(stayersCommentOnLeavers.getId())).isEmpty();
    assertThat(talkHelpfulRepository.existsByPostIdAndMemberId(stayersPost.getId(), leaver)).isFalse();
    assertThat(talkHelpfulRepository.existsByPostIdAndMemberId(leaversPost.getId(), stayer)).isFalse();
    assertThat(talkImportRepository.existsByPostIdAndMemberId(stayersPost.getId(), leaver)).isFalse();
    assertThat(talkImportRepository.existsByPostIdAndMemberId(leaversPost.getId(), stayer)).isFalse();
    assertThat(talkReportRepository.findAllById(java.util.List.of(reportByLeaver.getId(), reportOnLeaversPost.getId(),
      reportOnLeaversComment.getId(), reportOnCommentOfLeaversPost.getId()))).isEmpty();
    assertThat(talkBlockRepository.findByBlockerMemberId(leaver)).isEmpty();
    assertThat(talkBlockRepository.findByBlockerMemberId(stayer)).isEmpty();

    // 남의 것은 그대로
    assertThat(talkReportRepository.findById(unrelatedReport.getId())).isPresent();
    assertThat(talkBlockRepository.existsByBlockerMemberIdAndBlockedMemberId(bystander, stayer)).isTrue();
    assertThat(talkHelpfulRepository.existsByPostIdAndMemberId(stayersPost.getId(), bystander)).isTrue();

    // 남의 글 집계는 행 수로 (도움 1, 보이는 댓글 1, 가져간 보호자 1 - 같은 보호자의 두 번째 기록은 세지 않음)
    TalkPost recounted = talkPostRepository.findById(stayersPost.getId()).orElseThrow();
    assertThat(recounted.getHelpfulCount()).isEqualTo(1);
    assertThat(recounted.getCommentCount()).isEqualTo(1);
    assertThat(recounted.getImportCount()).isEqualTo(1);
  }
}
