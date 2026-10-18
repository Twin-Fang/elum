package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminRoutineResponse;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminRoutineList;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.time.LocalDateTime;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.transaction.support.TransactionTemplate;

/**
 * 실제 Postgres 로 하는 일과 목록 쿼리 검증 (#753). 평소 빌드에서는 건너뛴다.
 * 상태 필터, 모든 허용 정렬 열, LIKE ESCAPE 가 실제 JPQL 로 도는지 본다.
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54753/elum ./gradlew test --tests '*AdminRoutineListQueryIT'
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
class AdminRoutineListQueryIT {

  @Autowired private AdminRoutineService adminRoutineService;
  @Autowired private RoutineRepository routineRepository;
  @Autowired private ProfileRepository profileRepository;
  @Autowired private MemberRepository memberRepository;
  @Autowired private TransactionTemplate transactionTemplate;

  private final String prefix = "it753_" + UUID.randomUUID().toString().substring(0, 8) + "_";
  private Member member;
  private Profile profile;

  @AfterEach
  void cleanUp() {
    transactionTemplate.executeWithoutResult(status -> {
      routineRepository.findAll().stream().filter(routine -> routine.getTitle().startsWith(prefix))
        .forEach(routineRepository::delete);
      if (profile != null) {
        profileRepository.deleteById(profile.getId());
      }
      if (member != null) {
        memberRepository.deleteById(member.getId());
      }
    });
  }

  private void givenOwner(String nickname) {
    member = new Member();
    member.setUsername(prefix + "owner");
    member.setPassword("pw");
    member.setStatus(MemberStatus.ACTIVE);
    member = memberRepository.save(member);
    profile = new Profile();
    profile.setNickname(nickname);
    profile = profileRepository.save(profile);
  }

  private void newRoutine(String suffix, RoutineStatus status) {
    Routine routine = new Routine();
    routine.setProfile(profile);
    routine.setCreatedBy(member.getId());
    routine.setTitle(prefix + suffix);
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("원문");
    routine.setStatus(status);
    routine.setScheduledAt(LocalDateTime.of(2026, 10, 2, 9, 0));
    routine.setSteps(List.of());
    routineRepository.save(routine);
  }

  private List<String> titles(String q, Map<String, String> filters, String sort) {
    AdminListQuery query = AdminListQuery.of(q, filters, sort, null, AdminRoutineList.DEFINITION);
    return adminRoutineService.search(query).getContent().stream()
      .map(AdminRoutineResponse::title).filter(title -> title.startsWith(prefix)).toList();
  }

  @Test
  @DisplayName("상태 필터와 검색(제목·호칭, LIKE 특수문자)이 실제 쿼리로 돈다")
  void filterAndKeyword_run() {
    givenOwner("별빛_이");
    newRoutine("a", RoutineStatus.CONFIRMED);
    newRoutine("b%", RoutineStatus.COMPLETED);

    assertThat(titles(prefix, Map.of("status", "COMPLETED"), null)).containsExactly(prefix + "b%");
    assertThat(titles(prefix, Map.of(), null)).hasSize(2);
    // % 는 와일드카드가 아니라 글자로 찾는다
    assertThat(titles(prefix + "b%", Map.of(), null)).containsExactly(prefix + "b%");
    assertThat(titles(prefix + "a%", Map.of(), null)).isEmpty();
    // 이룸이 호칭 검색: _ 도 글자
    assertThat(titles("별빛_", Map.of(), null)).hasSize(2);
    assertThat(titles("별빛X", Map.of(), null)).isEmpty();
  }

  @Test
  @DisplayName("허용된 모든 정렬 열이 실제 쿼리로 돈다")
  void allSorts_run() {
    givenOwner("하늘이");
    newRoutine("a", RoutineStatus.CONFIRMED);
    newRoutine("b", RoutineStatus.COMPLETED);

    for (String key : List.of("title", "status", "scheduledAt", "completedAt", "updatedAt")) {
      assertThat(titles(prefix, Map.of(), key + ",asc")).as(key + " asc").hasSize(2);
      assertThat(titles(prefix, Map.of(), key + ",desc")).as(key + " desc").hasSize(2);
    }
    assertThat(titles(prefix, Map.of(), "title,desc")).containsExactly(prefix + "b", prefix + "a");
  }
}
