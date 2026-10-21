package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.list.AdminFeedbackList;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminNoticeList;
import com.chuseok22.elumserver.feedback.application.service.FeedbackService;
import com.chuseok22.elumserver.feedback.core.FeedbackStatus;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import com.chuseok22.elumserver.feedback.infrastructure.repository.FeedbackRepository;
import com.chuseok22.elumserver.notice.application.service.NoticeService;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import java.time.LocalDateTime;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;

/**
 * 실제 Postgres 로 하는 공지·의견 목록 쿼리 검증 (#756). 평소 빌드에서는 건너뛴다.
 * 검색(LIKE ESCAPE), 상태 필터, 모든 허용 정렬 열, 상태 변경 저장이 실제 JPQL 로 도는지 본다.
 * ELUM_IT_DDL_AUTO=validate 로 돌리면 엔티티와 DB 스키마(V40 적용 후)가 맞는지도 함께 본다.
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54756/elum ./gradlew test --tests '*AdminFeedbackNoticeListQueryIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=elum",
  "spring.datasource.password=pw",
  "spring.flyway.enabled=false",
  "spring.jpa.hibernate.ddl-auto=${ELUM_IT_DDL_AUTO:update}",
  "gemini.api-key=rehearsal-invalid"
})
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class AdminFeedbackNoticeListQueryIT {

  @Autowired private FeedbackService feedbackService;
  @Autowired private FeedbackRepository feedbackRepository;
  @Autowired private NoticeService noticeService;
  @Autowired private AppNoticeRepository appNoticeRepository;

  private final String prefix = "it756_" + UUID.randomUUID().toString().substring(0, 8) + "_";

  @AfterEach
  void cleanUp() {
    feedbackRepository.findAll().stream().filter(feedback -> feedback.getMessage().startsWith(prefix))
      .forEach(feedbackRepository::delete);
    appNoticeRepository.findAll().stream().filter(notice -> notice.getTitle().startsWith(prefix))
      .forEach(appNoticeRepository::delete);
  }

  private Feedback newFeedback(String suffix) {
    Feedback feedback = new Feedback();
    feedback.setMemberId(prefix + "member");
    feedback.setMessage(prefix + suffix);
    return feedbackRepository.save(feedback);
  }

  private List<String> feedbackMessages(String q, String status, String sort) {
    Map<String, String> filters = new HashMap<>();
    filters.put("status", status);
    AdminListQuery query = AdminListQuery.of(q, filters, sort, null, AdminFeedbackList.DEFINITION);
    return feedbackService.search(AdminFeedbackList.searchOf(query),
        AdminFeedbackList.sortOf(query), query.pageIndex()).getContent().stream()
      .map(Feedback::getMessage).filter(message -> message.startsWith(prefix)).toList();
  }

  private AppNotice newNotice(String suffix, int priority) {
    AppNotice notice = new AppNotice();
    notice.setTitle(prefix + suffix);
    notice.setBody("본문 " + suffix);
    notice.setPriority(priority);
    notice.setStartsAt(LocalDateTime.of(2026, 10, 1, 9, 0).plusDays(priority));
    notice.setEnabled(true);
    notice.setCreatedBy("it");
    notice.setUpdatedBy("it");
    return appNoticeRepository.save(notice);
  }

  private List<String> noticeTitles(String q, String sort) {
    AdminListQuery query = AdminListQuery.of(q, Map.of(), sort, null, AdminNoticeList.DEFINITION);
    return noticeService.search(AdminNoticeList.searchOf(query), AdminNoticeList.pageableOf(query)).getContent().stream()
      .map(AppNotice::getTitle).filter(title -> title.startsWith(prefix)).toList();
  }

  @Test
  @DisplayName("새 의견은 NEW 로 저장되고 상태 변경(변경자·시각)이 DB 에 남는다")
  void feedbackStatus_persisted() {
    Feedback saved = newFeedback("a");
    assertThat(feedbackRepository.findById(saved.getId()).orElseThrow().getStatus()).isEqualTo(FeedbackStatus.NEW);

    feedbackService.changeStatus(saved.getId(), FeedbackStatus.DONE, "kimchi");

    Feedback reloaded = feedbackRepository.findById(saved.getId()).orElseThrow();
    assertThat(reloaded.getStatus()).isEqualTo(FeedbackStatus.DONE);
    assertThat(reloaded.getStatusChangedBy()).isEqualTo("kimchi");
    assertThat(reloaded.getStatusChangedAt()).isNotNull();
  }

  @Test
  @DisplayName("의견: 상태 필터와 검색(본문·회원 id, LIKE 특수문자)이 실제 쿼리로 돈다")
  void feedbackFilterAndKeyword_run() {
    Feedback first = newFeedback("느려요_하나");
    newFeedback("100% 느려요");
    feedbackService.changeStatus(first.getId(), FeedbackStatus.IN_PROGRESS, "kimchi");

    assertThat(feedbackMessages(prefix, "IN_PROGRESS", null)).containsExactly(prefix + "느려요_하나");
    assertThat(feedbackMessages(prefix, "NEW", null)).containsExactly(prefix + "100% 느려요");
    assertThat(feedbackMessages(prefix, "DONE", null)).isEmpty();
    assertThat(feedbackMessages(prefix, null, null)).hasSize(2);
    // % _ 는 와일드카드가 아니라 글자로 찾는다
    assertThat(feedbackMessages(prefix + "100%", null, null)).containsExactly(prefix + "100% 느려요");
    assertThat(feedbackMessages(prefix + "느려요_", null, null)).containsExactly(prefix + "느려요_하나");
    assertThat(feedbackMessages(prefix + "느려요X", null, null)).isEmpty();
    // 회원 id 로도 찾는다
    assertThat(feedbackMessages(prefix + "member", null, null)).hasSize(2);
  }

  @Test
  @DisplayName("의견: 허용된 모든 정렬 열이 실제 쿼리로 돈다")
  void feedbackAllSorts_run() {
    Feedback first = newFeedback("a");
    newFeedback("b");
    feedbackService.changeStatus(first.getId(), FeedbackStatus.DONE, "kimchi");

    for (String key : List.of("createdAt", "status", "statusChangedAt")) {
      assertThat(feedbackMessages(prefix, null, key + ",asc")).as(key + " asc").hasSize(2);
      assertThat(feedbackMessages(prefix, null, key + ",desc")).as(key + " desc").hasSize(2);
    }
    // 바꾼 적 없는 의견(null)은 방향과 상관없이 뒤로
    assertThat(feedbackMessages(prefix, null, "statusChangedAt,desc")).containsExactly(prefix + "a", prefix + "b");
    assertThat(feedbackMessages(prefix, null, "statusChangedAt,asc")).containsExactly(prefix + "a", prefix + "b");
  }

  @Test
  @DisplayName("공지: 제목·본문 검색(LIKE 특수문자)과 모든 허용 정렬 열이 실제 쿼리로 돈다")
  void noticeKeywordAndSorts_run() {
    newNotice("a%", 1);
    newNotice("b_", 2);

    assertThat(noticeTitles(prefix, null)).hasSize(2);
    assertThat(noticeTitles(prefix + "a%", null)).containsExactly(prefix + "a%");
    assertThat(noticeTitles(prefix + "a_", null)).isEmpty();
    assertThat(noticeTitles(prefix + "b_", null)).containsExactly(prefix + "b_");
    // 본문으로도 찾는다
    assertThat(noticeTitles("본문 a", null)).contains(prefix + "a%");
    for (String key : List.of("title", "startsAt", "priority", "updatedAt")) {
      assertThat(noticeTitles(prefix, key + ",asc")).as(key + " asc").hasSize(2);
      assertThat(noticeTitles(prefix, key + ",desc")).as(key + " desc").hasSize(2);
    }
    assertThat(noticeTitles(prefix, "priority,desc")).containsExactly(prefix + "b_", prefix + "a%");
    assertThat(noticeTitles(prefix, "title,asc")).containsExactly(prefix + "a%", prefix + "b_");
  }
}
