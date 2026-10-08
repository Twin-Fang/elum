package com.chuseok22.elumserver.member;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.link.core.CodeDigest;
import com.chuseok22.elumserver.link.core.ElumiDeviceId;
import com.chuseok22.elumserver.common.infrastructure.jwt.LinkRole;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.application.service.GuardianshipService;
import com.chuseok22.elumserver.member.infrastructure.entity.GuardianKind;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileGuardian;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.jayway.jsonpath.JsonPath;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.Callable;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.MvcResult;
import org.springframework.test.web.servlet.request.MockHttpServletRequestBuilder;

/**
 * **실제 Postgres 로 하는 새 이룸이 만들기 · 만든 사람 정보 리허설** (#361·#362). 평소 빌드에서는 건너뛴다.
 *
 * <p>목 테스트는 계정 행 잠금이 동시 호출을 줄 세우는지, 이름 투영 쿼리가 실제로 도는지 보여주지 못한다.
 * 요청은 실제 보안 체인(JWT·역할)을 지난다. 실행법은 {@link ProfileInviteRehearsalIT} 와 같다.
 *
 * <pre>
 * docker run -d --name elum-361-rehearsal -e POSTGRES_USER=elum -e POSTGRES_PASSWORD=pw -e POSTGRES_DB=elum -p 54631:5432 postgres:17-alpine
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54631/elum ./gradlew test --tests '*ProfileCreateRehearsalIT'
 * </pre>
 */
@SpringBootTest(properties = {
  "spring.flyway.enabled=false",
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=elum",
  "spring.datasource.password=pw",
  "gemini.api-key=rehearsal-invalid"
})
@ActiveProfiles("dev")
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class ProfileCreateRehearsalIT {

  @Autowired private MockMvc mockMvc;
  @Autowired private JwtProvider jwtProvider;
  @Autowired private MemberRepository memberRepository;
  @Autowired private ProfileRepository profileRepository;
  @Autowired private ProfileGuardianRepository profileGuardianRepository;
  @Autowired private RoutineRepository routineRepository;
  @Autowired private DeviceLinkRepository deviceLinkRepository;
  @Autowired private GuardianshipService guardianshipService;

  @Test
  @DisplayName("마지막 이룸이에서 나간 보호자: 이름 저장은 404 였고, 새 이룸이를 만들면 저장된다")
  void leaveLastThenCreateThenSave() throws Exception {
    Member a = newMember();
    Profile p = guardianshipService.createOwnProfile(a);
    call(delete("/api/profiles/" + p.getId() + "/guardians/me"), a, null, 204);

    // 고치기 전 증상 — 이룸이가 없어 막힌다
    String blocked = call(patch("/api/member/nickname"), a, "{\"nickname\":\"하늘이\"}", 404);
    assertThat(blocked).contains("PROFILE_NOT_FOUND");

    String created = call(post("/api/member/profile"), a, null, 200);
    assertThat(JsonPath.<List<String>>read(created, "$.profiles[*].id")).hasSize(1);
    String saved = call(patch("/api/member/nickname"), a, "{\"nickname\":\"하늘이\"}", 200);
    assertThat(JsonPath.<String>read(saved, "$.nickname")).isEqualTo("하늘이");
    assertThat(profileGuardianRepository.findProfileIdsByMemberId(a.getId())).hasSize(1);
  }

  @Test
  @DisplayName("같은 보호자가 동시에 여덟 번 불러도 이룸이는 하나만 생기고 응답은 모두 같은 이룸이다 (보호자를 바꿔 열 번 반복)")
  void concurrentCallsMakeOneProfile() throws Exception {
    // 경쟁은 한 번에 안 잡힐 수 있어 새 보호자로 반복한다. 잠금을 빼면 이 반복 안에서 이룸이가 둘 생긴다.
    for (int round = 0; round < 10; round++) {
      Member a = newMember();
      String token = tokenOf(a);

      List<Callable<String>> tasks = new ArrayList<>();
      for (int i = 0; i < 8; i++) {
        tasks.add(() -> {
          MvcResult r = perform(post("/api/member/profile"), token, null);
          return r.getResponse().getStatus() + ":" + r.getResponse().getContentAsString();
        });
      }
      List<String> results = race(tasks);

      assertThat(results).allSatisfy(r -> assertThat(r).startsWith("200:"));
      assertThat(profileGuardianRepository.findProfileIdsByMemberId(a.getId())).as("관계 행 (회차 " + round + ")").hasSize(1);
      assertThat(profileRepository.findAllGuardedBy(a.getId())).as("이룸이 (회차 " + round + ")").hasSize(1);
      String profileId = profileGuardianRepository.findProfileIdsByMemberId(a.getId()).get(0);
      assertThat(results).allSatisfy(r ->
        assertThat(JsonPath.<String>read(r.substring(4), "$.profiles[0].id")).isEqualTo(profileId));
    }
  }

  @Test
  @DisplayName("이미 이룸이가 있는 보호자가 불러도 새로 만들지 않는다")
  void existingProfileIsKept() throws Exception {
    Member a = newMember();
    Profile p = guardianshipService.createOwnProfile(a);

    String body = call(post("/api/member/profile"), a, null, 200);

    assertThat(JsonPath.<List<String>>read(body, "$.profiles[*].id")).containsExactly(p.getId());
    assertThat(profileGuardianRepository.findProfileIdsByMemberId(a.getId())).hasSize(1);
  }

  @Test
  @DisplayName("이룸이 휴대폰 토큰은 403 이고 이룸이가 생기지 않는다")
  void elumiTokenIsForbidden() throws Exception {
    Member a = newMember();
    Profile p = guardianshipService.createOwnProfile(a);
    DeviceLink link = new DeviceLink();
    link.setMemberId(a.getId());
    link.setProfileId(p.getId());
    link.setCodeHash(CodeDigest.sha256("ELUMI2"));
    link.setExpiresAt(LocalDateTime.now().plusMinutes(10));
    link.setRedeemedAt(LocalDateTime.now());
    deviceLinkRepository.save(link);
    link.setLinkedDeviceId(ElumiDeviceId.of(link.getId()));
    deviceLinkRepository.save(link);
    String elumiToken = jwtProvider.createAccessToken(a.getId(), a.getUsername(), LinkRole.ELUMI, link.getId());

    assertThat(perform(post("/api/member/profile"), elumiToken, null).getResponse().getStatus()).isEqualTo(403);
    assertThat(profileGuardianRepository.findProfileIdsByMemberId(a.getId())).hasSize(1);
  }

  @Test
  @DisplayName("일과 응답: 남이 만든 일과에는 createdByMe=false 와 표시 이름이, 내 일과에는 true 가 실린다 — 계정 ID 는 없다")
  void routineCarriesCreator() throws Exception {
    Member a = newMember();
    Profile p = guardianshipService.createOwnProfile(a);
    Member b = newMember();
    addGuardian(p, b, null);
    ProfileGuardian mineA = profileGuardianRepository.findByProfileIdAndMemberId(p.getId(), a.getId()).orElseThrow();
    mineA.setDisplayName("엄마");
    profileGuardianRepository.save(mineA);
    newRoutine(p, a, "엄마의 일과");
    newRoutine(p, b, "B의 일과");

    String body = call(get("/api/routines"), b, null, 200);

    assertThat(JsonPath.<List<String>>read(body, "$[?(@.title=='엄마의 일과')].creatorName")).containsExactly("엄마");
    assertThat(JsonPath.<List<Boolean>>read(body, "$[?(@.title=='엄마의 일과')].createdByMe")).containsExactly(false);
    assertThat(JsonPath.<List<Boolean>>read(body, "$[?(@.title=='B의 일과')].createdByMe")).containsExactly(true);
    // 이름을 정하지 않은 B 는 creatorName 이 null — 앱이 '보호자'로 부른다
    assertThat(JsonPath.<List<Object>>read(body, "$[?(@.title=='B의 일과')].creatorName")).containsExactly((Object) null);
    assertThat(body).doesNotContain(a.getId()).doesNotContain(a.getUsername()).doesNotContain(b.getUsername());
  }

  // ── 준비물 ──

  private Member newMember() {
    Member member = new Member();
    member.setUsername("it362_" + UUID.randomUUID());
    member.setPassword("x");
    member.setTermsAgreed(true);
    member.setPrivacyAgreed(true);
    member.setOverseasTransferAgreed(true);
    member.setGuardianConfirmed(true);
    return memberRepository.save(member);
  }

  private void addGuardian(Profile profile, Member member, String displayName) {
    ProfileGuardian g = new ProfileGuardian();
    g.setProfile(profile);
    g.setMember(member);
    g.setKind(GuardianKind.GUARDIAN);
    g.setDisplayName(displayName);
    g.setJoinedAt(LocalDateTime.now());
    profileGuardianRepository.save(g);
  }

  private Routine newRoutine(Profile profile, Member creator, String title) {
    Routine routine = new Routine();
    routine.setProfile(profile);
    routine.setCreatedBy(creator.getId());
    routine.setRawInputText("원문");
    routine.setSanitizedInputText("원문");
    routine.setTitle(title);
    routine.setScheduledAt(LocalDateTime.now().plusHours(1));
    routine.setStatus(RoutineStatus.CONFIRMED);
    return routineRepository.save(routine);
  }

  private String call(MockHttpServletRequestBuilder request, Member as, String body, int expectedStatus)
    throws Exception {
    MvcResult result = perform(request, tokenOf(as), body);
    assertThat(result.getResponse().getStatus())
      .as(request + " → " + result.getResponse().getContentAsString())
      .isEqualTo(expectedStatus);
    return result.getResponse().getContentAsString();
  }

  private MvcResult perform(MockHttpServletRequestBuilder request, String token, String body) throws Exception {
    request.header("Authorization", "Bearer " + token);
    if (body != null) {
      request.contentType(MediaType.APPLICATION_JSON).content(body);
    }
    return mockMvc.perform(request).andReturn();
  }

  private String tokenOf(Member member) {
    return jwtProvider.createAccessToken(member.getId(), member.getUsername());
  }

  /** 모든 스레드가 준비된 뒤 한꺼번에 출발시킨다. */
  private <T> List<T> race(List<Callable<T>> tasks) throws Exception {
    ExecutorService pool = Executors.newFixedThreadPool(tasks.size());
    CountDownLatch ready = new CountDownLatch(tasks.size());
    CountDownLatch go = new CountDownLatch(1);
    List<Future<T>> futures = new ArrayList<>();
    for (Callable<T> task : tasks) {
      futures.add(pool.submit(() -> {
        ready.countDown();
        go.await();
        return task.call();
      }));
    }
    ready.await();
    go.countDown();
    List<T> results = new ArrayList<>();
    for (Future<T> future : futures) {
      results.add(future.get());
    }
    pool.shutdown();
    return results;
  }
}
