package com.chuseok22.elumserver.admin.application.service;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.admin.application.dto.response.AdminMemberResponse;
import com.chuseok22.elumserver.admin.application.list.AdminListQuery;
import com.chuseok22.elumserver.admin.application.list.AdminMemberList;
import com.chuseok22.elumserver.license.application.service.SubscriptionHistoryService;
import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionHistoryRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
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
 * 실제 Postgres 로 하는 회원 목록 쿼리·요금제 이력 검증 (#751). 평소 빌드에서는 건너뛴다.
 *
 * <p>목 테스트는 JPQL(요금제 필터 case, 구독 left join 정렬, LIKE ESCAPE)이 실제로 도는지 보여주지 못한다.
 * 표는 ddl-auto: update 가 만든다(Flyway 는 끈다). V39 SQL 이 엔티티와 맞는지는 ELUM_IT_DDL_AUTO=validate 로
 * subscription_history 를 V39 로 만든 DB 에서 같은 시험을 돌려 본다.
 *
 * <pre>
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54751/elum ./gradlew test --tests '*AdminMemberListQueryIT'
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
class AdminMemberListQueryIT {

  @Autowired private AdminMemberService adminMemberService;
  @Autowired private SubscriptionService subscriptionService;
  @Autowired private SubscriptionHistoryService subscriptionHistoryService;
  @Autowired private SubscriptionHistoryRepository subscriptionHistoryRepository;
  @Autowired private SubscriptionRepository subscriptionRepository;
  @Autowired private MemberRepository memberRepository;
  @Autowired private TransactionTemplate transactionTemplate;

  private final String prefix = "it751_" + UUID.randomUUID().toString().substring(0, 8) + "_";

  @AfterEach
  void cleanUp() {
    transactionTemplate.executeWithoutResult(status ->
      memberRepository.findAll().stream().filter(member -> member.getUsername().startsWith(prefix)).forEach(member -> {
        subscriptionHistoryRepository.deleteByMemberId(member.getId());
        subscriptionRepository.deleteByMemberId(member.getId());
        memberRepository.delete(member);
      }));
  }

  private Member newMember(String suffix) {
    Member member = new Member();
    member.setUsername(prefix + suffix);
    member.setPassword("pw");
    member.setStatus(MemberStatus.ACTIVE);
    return memberRepository.save(member);
  }

  private AdminListQuery query(String q, Map<String, String> filters, String sort) {
    return AdminListQuery.of(q, filters, sort, null, AdminMemberList.DEFINITION);
  }

  private List<String> usernames(AdminListQuery query) {
    return adminMemberService.search(query).getContent().stream()
      .map(AdminMemberResponse::username).filter(name -> name.startsWith(prefix)).toList();
  }

  @Test
  @DisplayName("요금제 필터는 지금 유효한 요금제 기준이다 — 만료된 Pro 와 구독 없는 회원은 Free")
  void planFilter_usesEffectivePlan() {
    Member pro = newMember("pro");
    Member expired = newMember("expired");
    newMember("nosub");
    subscriptionService.grantPro(pro.getId(), 30, "시연", "admin1");
    subscriptionService.grantPro(expired.getId(), 30, "시연", "admin1");
    Subscription expiredSubscription = subscriptionRepository.findByMemberId(expired.getId()).orElseThrow();
    expiredSubscription.setExpiresAt(LocalDateTime.now().minusDays(1));
    subscriptionRepository.save(expiredSubscription);

    assertThat(usernames(query(prefix, Map.of("plan", "PRO"), null))).containsExactly(prefix + "pro");
    assertThat(usernames(query(prefix, Map.of("plan", "FREE"), null)))
      .containsExactlyInAnyOrder(prefix + "expired", prefix + "nosub");
    assertThat(usernames(query(prefix, Map.of(), null))).hasSize(3);
  }

  @Test
  @DisplayName("요금제 정렬과 다른 허용 열 정렬이 실제 쿼리로 돈다")
  void sorts_run() {
    Member pro = newMember("pro");
    newMember("free");
    subscriptionService.grantPro(pro.getId(), null, "시연", "admin1");

    for (String sort : List.of("plan,asc", "plan,desc", "username,asc", "lastActivityAt,desc", "createdAt,asc")) {
      assertThat(usernames(query(prefix, Map.of(), sort))).as(sort).hasSize(2);
    }
    // 내림차순은 Pro 먼저, 오름차순은 Free(구독 없는 회원 포함) 먼저
    assertThat(usernames(query(prefix, Map.of(), "plan,desc")).get(0)).isEqualTo(prefix + "pro");
    assertThat(usernames(query(prefix, Map.of(), "plan,asc")).get(0)).isEqualTo(prefix + "free");
  }

  @Test
  @DisplayName("검색어의 % 와 _ 는 글자 그대로 찾는다")
  void keyword_escapesLikeWildcards() {
    newMember("a%b");
    newMember("axb");

    assertThat(usernames(query(prefix + "a%b", Map.of(), null))).containsExactly(prefix + "a%b");
    assertThat(usernames(query(prefix + "a_b", Map.of(), null))).isEmpty();
  }

  @Test
  @DisplayName("모니터링·의견 화면에 보이는 회원 id 8자 조각으로 그 회원을 찾는다 (#651)")
  void keyword_matchesMemberIdFragment() {
    Member target = newMember("idfrag");
    newMember("other");
    // 화면이 보여 주는 앞 8자 대신 가운데 조각: 앞부분 일치(접두)만 되는 구현도 걸러냄
    String idFragment = target.getId().substring(9, 17).toUpperCase();

    assertThat(adminMemberService.search(query(idFragment, Map.of(), null)).getContent())
      .extracting(AdminMemberResponse::id).containsExactly(target.getId());
  }

  @Test
  @DisplayName("연속 부여 후 이력 2건과 마지막 변경이 DB 에서 읽힌다")
  void history_persistedAndLatestRead() {
    Member member = newMember("hist");
    subscriptionService.grantPro(member.getId(), 30, "첫 부여", "admin1");
    subscriptionService.grantPro(member.getId(), null, "두 번째", "admin2");
    subscriptionService.revokePro(member.getId(), "회수", "admin3");

    assertThat(subscriptionHistoryService.recent(member.getId(), 10)).hasSize(3);
    assertThat(subscriptionHistoryService.recent(member.getId(), 10).get(0).getChangedBy()).isEqualTo("admin3");
    assertThat(subscriptionHistoryService.latestByMemberIds(List.of(member.getId())).get(member.getId()).getReason())
      .isEqualTo("회수");
    AdminMemberResponse row = adminMemberService.search(query(prefix + "hist", Map.of(), null)).getContent().get(0);
    assertThat(row.plan()).isEqualTo(PlanType.FREE);
    assertThat(row.planLastChangedBy()).isEqualTo("admin3");
  }

  @Test
  @DisplayName("대시보드 Pro 수는 유효 Pro 만 센다 — 만료된 Pro 와 탈퇴 회원의 Pro 는 뺀다 (#760)")
  void countEffectivePro_countsOnlyEffectiveNonWithdrawn() {
    long before = adminMemberService.countEffectivePro();
    Member pro = newMember("cpro");
    Member expired = newMember("cexpired");
    Member withdrawn = newMember("cwithdrawn");
    subscriptionService.grantPro(pro.getId(), 30, "시연", "admin1");
    subscriptionService.grantPro(expired.getId(), 30, "시연", "admin1");
    subscriptionService.grantPro(withdrawn.getId(), null, "시연", "admin1");
    Subscription expiredSubscription = subscriptionRepository.findByMemberId(expired.getId()).orElseThrow();
    expiredSubscription.setExpiresAt(LocalDateTime.now().minusDays(1));
    subscriptionRepository.save(expiredSubscription);
    withdrawn.setStatus(MemberStatus.WITHDRAWN);
    memberRepository.save(withdrawn);

    assertThat(adminMemberService.countEffectivePro() - before).isEqualTo(1);
  }
}
