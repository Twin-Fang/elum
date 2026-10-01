package com.chuseok22.elumserver.member;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.delete;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;

import com.chuseok22.elumserver.common.infrastructure.jwt.JwtProvider;
import com.chuseok22.elumserver.link.core.CodeDigest;
import com.chuseok22.elumserver.link.core.ElumiDeviceId;
import com.chuseok22.elumserver.link.core.LinkRole;
import com.chuseok22.elumserver.link.infrastructure.entity.DeviceLink;
import com.chuseok22.elumserver.link.infrastructure.repository.DeviceLinkRepository;
import com.chuseok22.elumserver.member.application.service.GuardianshipService;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.entity.ProfileInvite;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileInviteRepository;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import com.chuseok22.elumserver.routine.infrastructure.entity.RoutineStatus;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import com.jayway.jsonpath.JsonPath;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
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
 * **실제 Postgres 로 하는 초대·나가기 리허설** (이슈 #361). 평소 빌드에서는 건너뛴다.
 *
 * <p>이 레포의 단위 테스트는 목이라 행 잠금·유니크 제약·롤백 규칙이 실제로 듣는지는 보여주지 못한다. 명세의
 * 경쟁 조건(E3 같은 코드 동시 입력 · E15 마지막 두 보호자 동시 나가기)과 "실패 응답과 함께 시도 횟수가 저장되는가"는
 * 실제 DB 에서만 확인된다. 요청은 실제 보안 체인(JWT·역할)을 지난다.
 *
 * <pre>
 * docker run -d --name elum-361-rehearsal -e POSTGRES_USER=elum -e POSTGRES_PASSWORD=pw -e POSTGRES_DB=elum -p 54631:5432 postgres:17-alpine
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54631/elum ./gradlew test --tests '*ProfileInviteRehearsalIT'
 * </pre>
 *
 * <p>DB 는 dev 프로필의 {@code ddl-auto: update} 가 만든다(Flyway 는 끈다). AI 는 부르지 않는다 — 키는 가짜다.
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
class ProfileInviteRehearsalIT {

  @Autowired private MockMvc mockMvc;
  @Autowired private JwtProvider jwtProvider;
  @Autowired private MemberRepository memberRepository;
  @Autowired private ProfileRepository profileRepository;
  @Autowired private ProfileGuardianRepository profileGuardianRepository;
  @Autowired private ProfileInviteRepository profileInviteRepository;
  @Autowired private RoutineRepository routineRepository;
  @Autowired private DeviceLinkRepository deviceLinkRepository;
  @Autowired private GuardianshipService guardianshipService;

  // ── 정상 흐름: 발급 → 합류 → 목록 → 나가기 → 마지막 보호자 나가기 ──

  @Test
  @DisplayName("A 가 코드를 내고 B 가 합류한다 — B 의 빈 이룸이는 지워지고, A 가 나가면 A 의 일과만 사라지고 별·이룸이·B 의 일과는 남는다, B 까지 나가면 이룸이도 사라진다")
  void fullJourney() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    pA.setNickname("하늘이");
    pA.setTotalStars(7);
    profileRepository.save(pA);
    Member b = newMember(true);
    Profile pBEmpty = guardianshipService.createOwnProfile(b); // 가입 때 생긴 빈 이룸이

    String code = issue(a, pA.getId());
    String joinBody = call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + code.toLowerCase()
      + "\",\"displayName\":\"아빠\"}", 200);
    assertThat(JsonPath.<String>read(joinBody, "$.profile.id")).isEqualTo(pA.getId());
    assertThat(JsonPath.<List<String>>read(joinBody, "$.removedProfileIds")).containsExactly(pBEmpty.getId());
    assertThat(profileRepository.findById(pBEmpty.getId())).as("빈 이룸이는 지워졌다").isEmpty();

    String listBody = call(get("/api/profiles/" + pA.getId() + "/guardians"), a, null, 200);
    assertThat(JsonPath.<List<Boolean>>read(listBody, "$.guardians[*].me")).containsExactly(true, false);
    assertThat(JsonPath.<List<String>>read(listBody, "$.guardians[*].kind")).containsExactly("GUARDIAN", "GUARDIAN");
    assertThat(listBody).as("다른 보호자의 계정 정보는 없다").doesNotContain(a.getUsername()).doesNotContain(b.getUsername());

    // 두 사람이 각자 일과를 만들어 둔다
    newRoutine(pA, a, "A의 일과");
    newRoutine(pA, b, "B의 일과");

    call(delete("/api/profiles/" + pA.getId() + "/guardians/me"), a, null, 204);

    List<Routine> left = routineRepository.findAllByProfileId(pA.getId());
    assertThat(left).extracting(Routine::getTitle).containsExactly("B의 일과");
    assertThat(profileRepository.findById(pA.getId()).orElseThrow().getTotalStars()).as("별은 남는다").isEqualTo(7);
    assertThat(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(pA.getId())).hasSize(1);
    // 남은 관계는 B 하나다 — 이룸이 행에 따로 넘길 대표 보호자는 없다 (V32)
    assertThat(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(pA.getId()).get(0).getMember().getId())
      .isEqualTo(b.getId());

    call(delete("/api/profiles/" + pA.getId() + "/guardians/me"), b, null, 204);

    assertThat(profileRepository.findById(pA.getId())).as("마지막 보호자가 나가면 이룸이도 지운다").isEmpty();
    assertThat(routineRepository.findAllByProfileId(pA.getId())).isEmpty();
  }

  @Test
  @DisplayName("E16 나간 사람이 다시 초대받아 들어올 수 있고 예전 일과는 돌아오지 않는다")
  void e16_rejoinAfterLeaving() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member b = newMember(true);
    guardianshipService.createOwnProfile(b);
    call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + issue(a, pA.getId()) + "\"}", 200);
    newRoutine(pA, b, "B의 옛 일과");

    call(delete("/api/profiles/" + pA.getId() + "/guardians/me"), b, null, 204);
    call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + issue(a, pA.getId()) + "\"}", 200);

    assertThat(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(pA.getId())).hasSize(2);
    assertThat(routineRepository.findAllByProfileId(pA.getId())).isEmpty();
  }

  // ── E3: 같은 코드를 동시에 ──

  @Test
  @DisplayName("E3 같은 코드를 여섯 사람이 동시에 넣어도 한 명만 합류하고 나머지는 '맞지 않아요'(404)다 — 실제 행 잠금")
  void e3_sameCodeConcurrently_onlyOneJoins() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    String code = issue(a, pA.getId());
    List<Member> racers = new ArrayList<>();
    for (int i = 0; i < 6; i++) {
      Member racer = newMember(true);
      guardianshipService.createOwnProfile(racer);
      racers.add(racer);
    }

    List<Integer> statuses = race(racers.stream()
      .<java.util.concurrent.Callable<Integer>>map(racer -> () -> statusOf(post("/api/profile-invites/redeem"), racer,
        "{\"code\":\"" + code + "\"}"))
      .toList());

    assertThat(statuses).as("상태=" + statuses).filteredOn(s -> s == 200).hasSize(1);
    assertThat(statuses).filteredOn(s -> s == 404).hasSize(5);
    // A + 합류한 한 명
    assertThat(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(pA.getId())).hasSize(2);
    ProfileInvite row = inviteRow(code, pA.getId());
    assertThat(row.getRedeemedBy()).isNotNull();
  }

  // ── E15: 마지막 두 보호자가 동시에 나간다 ──

  @Test
  @DisplayName("E15 마지막 두 보호자가 동시에 나가도 둘 다 204 이고 보호자 0명인 이룸이가 남지 않는다 (다섯 번 반복)")
  void e15_lastTwoLeaveConcurrently_noOrphanProfile() throws Exception {
    for (int round = 0; round < 5; round++) {
      Member a = newMember(true);
      Profile p = guardianshipService.createOwnProfile(a);
      Member b = newMember(true);
      guardianshipService.createOwnProfile(b);
      call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + issue(a, p.getId()) + "\"}", 200);
      newRoutine(p, a, "A");
      newRoutine(p, b, "B");

      List<Integer> statuses = race(List.of(
        () -> statusOf(delete("/api/profiles/" + p.getId() + "/guardians/me"), a, null),
        () -> statusOf(delete("/api/profiles/" + p.getId() + "/guardians/me"), b, null)));

      assertThat(statuses).as("round %d 상태=%s".formatted(round, statuses)).containsExactly(204, 204);
      assertThat(profileRepository.findById(p.getId())).as("이룸이가 남지 않았다").isEmpty();
      assertThat(profileGuardianRepository.findAllByProfileIdOrderByJoinedAtAsc(p.getId())).isEmpty();
      assertThat(routineRepository.findAllByProfileId(p.getId())).isEmpty();
    }
  }

  // ── E5: 입력하는 사이에 이룸이가 지워진다 ──

  @Test
  @DisplayName("E5 마지막 보호자가 나가 이룸이가 지워진 뒤에 넣으면 합류하지 않는다 (코드 행도 함께 사라져 404)")
  void e5_profileDeletedBeforeRedeem() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member b = newMember(true);
    guardianshipService.createOwnProfile(b);
    String code = issue(a, pA.getId());

    call(delete("/api/profiles/" + pA.getId() + "/guardians/me"), a, null, 204);

    String error = call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + code + "\"}", 404);
    assertThat(error).contains("PROFILE_INVITE_NOT_FOUND");
    assertThat(profileInviteRepository.findProfileIdsByCodeHash(CodeDigest.sha256(code))).isEmpty();
  }

  // ── E4: 코드를 낸 사람이 쓰이기 전에 나간다 ──

  @Test
  @DisplayName("E4 코드를 낸 사람이 쓰이기 전에 나가면 그 코드는 폐기돼 입력하면 '맞지 않아요'다")
  void e4_issuerLeavesBeforeCodeIsUsed() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member c = newMember(true);
    guardianshipService.createOwnProfile(c);
    // B 가 먼저 합류해 이룸이가 남는다
    Member b = newMember(true);
    guardianshipService.createOwnProfile(b);
    call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + issue(a, pA.getId()) + "\"}", 200);
    String codeFromA = issue(a, pA.getId());

    call(delete("/api/profiles/" + pA.getId() + "/guardians/me"), a, null, 204);

    String error = call(post("/api/profile-invites/redeem"), c, "{\"code\":\"" + codeFromA + "\"}", 404);
    assertThat(error).contains("PROFILE_INVITE_NOT_FOUND");
    assertThat(profileGuardianRepository.existsByProfileIdAndMemberId(pA.getId(), c.getId())).isFalse();
  }

  // ── E1·E2 · E8 · E10 · E6 ──

  @Test
  @DisplayName("E1·E2 자기가 낸 코드나 이미 함께하는 사람의 코드 입력은 409 이고 코드는 쓰이지 않고 남는다")
  void e1e2_alreadyGuardian_conflictAndCodeStaysUsable() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    String code = issue(a, pA.getId());

    String error = call(post("/api/profile-invites/redeem"), a, "{\"code\":\"" + code + "\"}", 409);

    assertThat(error).contains("PROFILE_ALREADY_GUARDIAN");
    ProfileInvite row = inviteRow(code, pA.getId());
    assertThat(row.getRedeemedAt()).isNull();
    assertThat(row.getRevokedAt()).isNull();
  }

  @Test
  @DisplayName("E8 이미 쓴 코드를 다섯 번 두드리면 횟수가 실패 응답과 함께 저장돼 그 코드는 막힌다 (롤백되지 않는다)")
  void e8_failedAttemptsArePersistedAcrossFailures() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member b = newMember(true);
    guardianshipService.createOwnProfile(b);
    String code = issue(a, pA.getId());
    call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + code + "\"}", 200);
    Member c = newMember(true);
    guardianshipService.createOwnProfile(c);

    for (int i = 0; i < CodeDigest.MAX_FAILED_ATTEMPTS; i++) {
      call(post("/api/profile-invites/redeem"), c, "{\"code\":\"" + code + "\"}", 404);
    }

    ProfileInvite row = inviteRow(code, pA.getId());
    assertThat(row.getFailedAttempts()).as("실패 응답과 함께 저장됐다").isEqualTo(CodeDigest.MAX_FAILED_ATTEMPTS);
    assertThat(row.getRevokedAt()).isNotNull();
    String error = call(post("/api/profile-invites/redeem"), c, "{\"code\":\"" + code + "\"}", 429);
    assertThat(error).contains("PROFILE_INVITE_TOO_MANY_ATTEMPTS");
  }

  @Test
  @DisplayName("E10 한 계정이 10분에 11번째로 넣으면 코드와 상관없이 429 — 없는 코드를 찍어도 센다")
  void e10_accountRateLimit() throws Exception {
    Member c = newMember(true);
    guardianshipService.createOwnProfile(c);

    for (int i = 0; i < 10; i++) {
      call(post("/api/profile-invites/redeem"), c, "{\"code\":\"" + randomCode() + "\"}", 404);
    }
    String error = call(post("/api/profile-invites/redeem"), c, "{\"code\":\"" + randomCode() + "\"}", 429);

    assertThat(error).contains("PROFILE_INVITE_TOO_MANY_ATTEMPTS");
  }

  @Test
  @DisplayName("E8 만료된 코드는 410 이다")
  void e8_expired() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member b = newMember(true);
    guardianshipService.createOwnProfile(b);
    String code = issue(a, pA.getId());
    ProfileInvite row = inviteRow(code, pA.getId());
    row.setExpiresAt(LocalDateTime.now().minusSeconds(1));
    profileInviteRepository.save(row);

    String error = call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + code + "\"}", 410);

    assertThat(error).contains("PROFILE_INVITE_EXPIRED");
  }

  @Test
  @DisplayName("E9 다시 발급하면 이전 코드는 쓸 수 없다 — 화면에 보이는 코드만 통한다")
  void e9_reissueRevokesPrevious() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member b = newMember(true);
    guardianshipService.createOwnProfile(b);
    String first = issue(a, pA.getId());
    String second = issue(a, pA.getId());

    call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + first + "\"}", 404);
    call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + second + "\"}", 200);
  }

  @Test
  @DisplayName("E6 약관에 동의하지 않은 계정은 합류할 수 없다(403) — 코드는 쓰이지 않는다")
  void e6_consentRequired() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member noConsent = newMember(false);
    guardianshipService.createOwnProfile(noConsent);
    String code = issue(a, pA.getId());

    String error = call(post("/api/profile-invites/redeem"), noConsent, "{\"code\":\"" + code + "\"}", 403);

    assertThat(error).contains("CONSENT_REQUIRED");
    assertThat(profileGuardianRepository.existsByProfileIdAndMemberId(pA.getId(), noConsent.getId())).isFalse();
  }

  // ── E7: 이룸이 휴대폰 토큰은 전부 403 (실제 보안 체인) ──

  @Test
  @DisplayName("E7 이룸이 휴대폰 토큰은 발급·입력·목록·고치기·나가기가 전부 403 이다 — 합류도 쫓겨남도 일어나지 않는다")
  void e7_elumiTokenForbiddenEverywhere() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    DeviceLink link = new DeviceLink();
    link.setMemberId(a.getId());
    link.setProfileId(pA.getId());
    link.setCodeHash(CodeDigest.sha256("ELUMI1"));
    link.setExpiresAt(LocalDateTime.now().plusMinutes(10));
    link.setRedeemedAt(LocalDateTime.now());
    deviceLinkRepository.save(link);
    link.setLinkedDeviceId(ElumiDeviceId.of(link.getId()));
    deviceLinkRepository.save(link);
    String elumiToken = jwtProvider.createAccessToken(a.getId(), a.getUsername(), LinkRole.ELUMI, link.getId());

    String base = "/api/profiles/" + pA.getId();
    assertThat(statusWith(post(base + "/invites"), elumiToken, null)).isEqualTo(403);
    assertThat(statusWith(post("/api/profile-invites/redeem"), elumiToken, "{\"code\":\"" + randomCode() + "\"}"))
      .isEqualTo(403);
    assertThat(statusWith(get(base + "/guardians"), elumiToken, null)).isEqualTo(403);
    assertThat(statusWith(patch(base + "/guardians/me"), elumiToken, "{\"displayName\":\"x\"}")).isEqualTo(403);
    assertThat(statusWith(delete(base + "/guardians/me"), elumiToken, null)).isEqualTo(403);
    assertThat(profileGuardianRepository.existsByProfileIdAndMemberId(pA.getId(), a.getId())).isTrue();
  }

  @Test
  @DisplayName("연결되지 않은 보호자는 발급·목록·고치기·나가기가 403 이다 — 없는 이룸이도 같은 403 이다")
  void notConnectedGuardianIsForbidden() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member stranger = newMember(true);
    guardianshipService.createOwnProfile(stranger);

    for (String profileId : List.of(pA.getId(), "no-such-profile")) {
      String base = "/api/profiles/" + profileId;
      assertThat(statusOf(post(base + "/invites"), stranger, null)).as(base).isEqualTo(403);
      assertThat(statusOf(get(base + "/guardians"), stranger, null)).as(base).isEqualTo(403);
      assertThat(statusOf(patch(base + "/guardians/me"), stranger, "{\"displayName\":\"x\"}")).as(base).isEqualTo(403);
      assertThat(statusOf(delete(base + "/guardians/me"), stranger, null)).as(base).isEqualTo(403);
    }
    assertThat(profileGuardianRepository.existsByProfileIdAndMemberId(pA.getId(), a.getId())).isTrue();
  }

  @Test
  @DisplayName("내 이름·표시는 고칠 수 있고 남의 것은 고치는 길이 없다")
  void updateMyGuardian() throws Exception {
    Member a = newMember(true);
    Profile pA = guardianshipService.createOwnProfile(a);
    Member b = newMember(true);
    guardianshipService.createOwnProfile(b);
    call(post("/api/profile-invites/redeem"), b, "{\"code\":\"" + issue(a, pA.getId()) + "\"}", 200);

    call(patch("/api/profiles/" + pA.getId() + "/guardians/me"), b,
      "{\"kind\":\"CAREGIVER\",\"displayName\":\"센터 선생님\"}", 200);

    String listBody = call(get("/api/profiles/" + pA.getId() + "/guardians"), a, null, 200);
    assertThat(JsonPath.<List<String>>read(listBody, "$.guardians[*].displayName")).containsExactly(null, "센터 선생님");
    assertThat(JsonPath.<List<String>>read(listBody, "$.guardians[*].kind")).containsExactly("GUARDIAN", "CAREGIVER");
  }

  // ── 도우미 ──

  private Member newMember(boolean consents) {
    Member member = new Member();
    member.setUsername("it361_" + UUID.randomUUID());
    member.setPassword("x");
    if (consents) {
      member.setTermsAgreed(true);
      member.setPrivacyAgreed(true);
      member.setOverseasTransferAgreed(true);
      member.setGuardianConfirmed(true);
    }
    return memberRepository.save(member);
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

  private String issue(Member issuer, String profileId) throws Exception {
    String body = call(post("/api/profiles/" + profileId + "/invites"), issuer, null, 200);
    return JsonPath.read(body, "$.code");
  }

  /** 잠그지 않고 읽는다 — 이 테스트는 트랜잭션 밖이다. */
  private ProfileInvite inviteRow(String code, String profileId) {
    return profileInviteRepository.findAll().stream()
      .filter(i -> i.getCodeHash().equals(CodeDigest.sha256(code)) && i.getProfileId().equals(profileId))
      .findFirst().orElseThrow();
  }

  private static String randomCode() {
    // 우리 알파벳으로만 만든 여섯 글자 — 모양은 맞고 존재하지 않는 값이다
    String alphabet = "23456789ABCDEFGHJKMNPQRSTVWXYZ";
    StringBuilder sb = new StringBuilder();
    java.util.Random random = new java.util.Random();
    for (int i = 0; i < 6; i++) {
      sb.append(alphabet.charAt(random.nextInt(alphabet.length())));
    }
    return sb.toString();
  }

  private String call(MockHttpServletRequestBuilder request, Member as, String body, int expectedStatus)
    throws Exception {
    MvcResult result = perform(request, tokenOf(as), body);
    assertThat(result.getResponse().getStatus())
      .as(request.toString() + " → " + result.getResponse().getContentAsString())
      .isEqualTo(expectedStatus);
    return result.getResponse().getContentAsString();
  }

  private int statusOf(MockHttpServletRequestBuilder request, Member as, String body) throws Exception {
    return perform(request, tokenOf(as), body).getResponse().getStatus();
  }

  private int statusWith(MockHttpServletRequestBuilder request, String token, String body) throws Exception {
    return perform(request, token, body).getResponse().getStatus();
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
  private <T> List<T> race(List<java.util.concurrent.Callable<T>> tasks) throws Exception {
    ExecutorService pool = Executors.newFixedThreadPool(tasks.size());
    CountDownLatch ready = new CountDownLatch(tasks.size());
    CountDownLatch go = new CountDownLatch(1);
    List<Future<T>> futures = new ArrayList<>();
    for (java.util.concurrent.Callable<T> task : tasks) {
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
