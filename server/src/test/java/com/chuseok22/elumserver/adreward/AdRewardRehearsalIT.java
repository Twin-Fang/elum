package com.chuseok22.elumserver.adreward;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import com.chuseok22.elumserver.adreward.application.service.AdRewardSessionInfo;
import com.chuseok22.elumserver.adreward.application.service.AdRewardSessionService;
import com.chuseok22.elumserver.adreward.application.service.SsvKeyProvider;
import com.chuseok22.elumserver.adreward.core.AdRewardStatus;
import com.chuseok22.elumserver.adreward.infrastructure.repository.AdRewardSessionRepository;
import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.credit.core.CreditGrantSource;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditAccountRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditGrantRepository;
import com.chuseok22.elumserver.credit.infrastructure.repository.AiCreditLedgerRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.nio.charset.StandardCharsets;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.PublicKey;
import java.security.Signature;
import java.security.spec.ECGenParameterSpec;
import java.time.LocalDate;
import java.util.ArrayList;
import java.util.Base64;
import java.util.List;
import java.util.Optional;
import java.util.UUID;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.concurrent.Future;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.condition.EnabledIfEnvironmentVariable;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Primary;
import org.springframework.test.context.ActiveProfiles;
import org.springframework.test.web.servlet.MockMvc;

/**
 * **실제 Postgres 로 하는 통합 리허설** (#463). 평소 빌드에서는 건너뛴다.
 *
 * <p>이 레포에는 스프링 컨텍스트를 띄우는 테스트가 없어서 빈 연결(예: 없는 Clock 빈)·JPQL·행 잠금·유니크 제약이 운영
 * 배포에서야 드러난다. 돈(크레딧)이 걸린 지급은 그러면 안 되므로, 로컬 DB 로 한 번은 실제로 돌려 본다.
 *
 * <pre>
 * docker run -d --name elum-rehearsal -e POSTGRES_USER=elum -e POSTGRES_PASSWORD=pw -e POSTGRES_DB=elum -p 54630:5432 postgres:17-alpine
 * ELUM_IT_DB_URL=jdbc:postgresql://localhost:54630/elum ./gradlew test --tests '*AdRewardRehearsalIT'
 * </pre>
 *
 * <p>DB 는 dev 프로필의 {@code ddl-auto: update} 가 만든다(Flyway 는 끈다). 서명은 우리가 만든 EC 키로 하고, 그 공개키만
 * 서버가 믿게 바꿔 끼운다 — 나머지(컨트롤러·서명 검증·세션 잠금·계정 잠금·지급)는 실제 코드다.
 */
@SpringBootTest(properties = {
  "spring.flyway.enabled=false",
  "spring.datasource.url=${ELUM_IT_DB_URL:jdbc:postgresql://localhost:5432/elum}",
  "spring.datasource.username=elum",
  "spring.datasource.password=pw",
  // 리허설이 실제 AI 를 부르지 않게 키를 가짜로 덮는다.
  "gemini.api-key=rehearsal-invalid"
})
@ActiveProfiles("dev")
@AutoConfigureMockMvc
@EnabledIfEnvironmentVariable(named = "ELUM_IT_DB_URL", matches = ".+")
class AdRewardRehearsalIT {

  private static final String KEY_ID = "77";
  private static final String AD_UNIT = "6517734434";
  private static final KeyPair GOOGLE = newKeyPair();

  @Autowired
  private MockMvc mockMvc;
  @Autowired
  private AdRewardSessionService sessionService;
  @Autowired
  private AdRewardSessionRepository sessionRepository;
  @Autowired
  private MemberRepository memberRepository;
  @Autowired
  private AiCreditAccountRepository accountRepository;
  @Autowired
  private AiCreditGrantRepository grantRepository;
  @Autowired
  private AiCreditLedgerRepository ledgerRepository;
  @Autowired
  private SystemConfigService config;

  /// 서버가 Google 공개키 대신 우리 공개키를 믿게 한다.
  @TestConfiguration
  static class Keys {

    @Bean
    @Primary
    SsvKeyProvider testKeys() {
      return keyId -> KEY_ID.equals(keyId) ? Optional.of(GOOGLE.getPublic()) : Optional.<PublicKey>empty();
    }
  }

  @BeforeEach
  void turnOn() {
    config.update(ConfigKey.AD_REWARD_ENABLED, "true");
    config.update(ConfigKey.AD_REWARD_CREDITS_PER_VIEW, "2");
    config.update(ConfigKey.AD_REWARD_DAILY_LIMIT, "3");
    config.update(ConfigKey.AD_REWARD_SESSION_TTL_MINUTES, "30");
  }

  @Test
  @DisplayName("정상 시청: 서명이 맞으면 크레딧을 주고 원장·묶음·세션이 서로 맞는다")
  void grantsOnce() throws Exception {
    String memberId = newMember();
    AdRewardSessionInfo session = sessionService.create(memberId);

    mockMvc.perform(get("/api/ads/ssv?" + signed(session.nonce(), "tx-" + UUID.randomUUID())))
      .andExpect(status().isOk());

    var stored = sessionRepository.findByNonce(session.nonce()).orElseThrow();
    assertThat(stored.getStatus()).isEqualTo(AdRewardStatus.GRANTED);
    assertThat(stored.getGrantedCredits()).isEqualTo(2);
    var account = accountRepository.findByMemberId(memberId).orElseThrow();
    var grants = grantRepository.findByAccountIdAndRemainingGreaterThan(account.getId(), 0);
    assertThat(grants).hasSize(1);
    assertThat(grants.get(0).getSource()).isEqualTo(CreditGrantSource.AD_REWARD);
    assertThat(grants.get(0).getRemaining()).isEqualTo(2);
    assertThat(grantRepository.countByAccountIdAndSourceAndValidFromGreaterThanEqual(
      account.getId(), CreditGrantSource.AD_REWARD, LocalDate.now().atStartOfDay())).isEqualTo(1);
    assertThat(ledgerRepository.findAll().stream()
      .filter(l -> account.getId().equals(l.getAccountId()))).hasSize(1);
  }

  @Test
  @DisplayName("같은 콜백을 순서대로 여러 번 보내도 지급은 한 번이다")
  void sameCallbackRepeated() throws Exception {
    String memberId = newMember();
    String query = signed(sessionService.create(memberId).nonce(), "tx-" + UUID.randomUUID());

    for (int i = 0; i < 4; i++) {
      mockMvc.perform(get("/api/ads/ssv?" + query)).andExpect(status().isOk());
    }

    assertThat(adGrants(memberId)).isEqualTo(1);
  }

  @Test
  @DisplayName("같은 콜백이 동시에 8개 와도 지급은 정확히 한 번이다 (실제 행 잠금)")
  void sameCallbackConcurrently() throws Exception {
    String memberId = newMember();
    String query = signed(sessionService.create(memberId).nonce(), "tx-" + UUID.randomUUID());

    int threads = 8;
    ExecutorService pool = Executors.newFixedThreadPool(threads);
    CountDownLatch ready = new CountDownLatch(threads);
    CountDownLatch go = new CountDownLatch(1);
    List<Future<Integer>> results = new ArrayList<>();
    for (int i = 0; i < threads; i++) {
      results.add(pool.submit(() -> {
        ready.countDown();
        go.await();
        return mockMvc.perform(get("/api/ads/ssv?" + query)).andReturn().getResponse().getStatus();
      }));
    }
    ready.await();
    go.countDown();
    for (Future<Integer> result : results) {
      assertThat(result.get()).isEqualTo(200);
    }
    pool.shutdown();

    assertThat(adGrants(memberId)).as("동시 콜백 8개에도 지급 묶음은 1개").isEqualTo(1);
    var account = accountRepository.findByMemberId(memberId).orElseThrow();
    assertThat(ledgerRepository.findAll().stream()
      .filter(l -> account.getId().equals(l.getAccountId()))).as("원장 줄도 1개").hasSize(1);
  }

  @Test
  @DisplayName("같은 transaction_id 를 서로 다른 세션 둘로 동시에 보내도 지급은 한 번이다")
  void sameTransactionOnTwoSessionsConcurrently() throws Exception {
    String tx = "tx-" + UUID.randomUUID();
    String memberA = newMember();
    String memberB = newMember();
    String queryA = signed(sessionService.create(memberA).nonce(), tx);
    String queryB = signed(sessionService.create(memberB).nonce(), tx);

    ExecutorService pool = Executors.newFixedThreadPool(2);
    CountDownLatch go = new CountDownLatch(1);
    List<Future<Integer>> results = new ArrayList<>();
    for (String query : List.of(queryA, queryB)) {
      results.add(pool.submit(() -> {
        go.await();
        return mockMvc.perform(get("/api/ads/ssv?" + query)).andReturn().getResponse().getStatus();
      }));
    }
    go.countDown();
    List<Integer> statuses = new ArrayList<>();
    for (Future<Integer> result : results) {
      statuses.add(result.get());
    }
    pool.shutdown();

    // 한쪽은 200(지급), 다른 쪽은 200(중복) 또는 유니크 제약으로 500(재시도 대상). 어느 쪽이든 지급은 합쳐 한 번이다.
    assertThat(adGrants(memberA) + adGrants(memberB)).as("합쳐서 1번, 상태=" + statuses).isEqualTo(1);
  }

  @Test
  @DisplayName("서명이 틀리면 400 이고 아무것도 지급되지 않는다")
  void badSignature() throws Exception {
    String memberId = newMember();
    String query = signed(sessionService.create(memberId).nonce(), "tx-" + UUID.randomUUID())
      .replace("reward_amount=1", "reward_amount=9");

    mockMvc.perform(get("/api/ads/ssv?" + query)).andExpect(status().isBadRequest());

    assertThat(adGrants(memberId)).isZero();
  }

  @Test
  @DisplayName("하루 상한에 닿으면 세션을 더 만들 수 없고, 상한을 넘는 콜백은 주지 않는다")
  void dailyLimit() throws Exception {
    config.update(ConfigKey.AD_REWARD_DAILY_LIMIT, "2");
    String memberId = newMember();
    for (int i = 0; i < 2; i++) {
      String nonce = sessionService.create(memberId).nonce();
      mockMvc.perform(get("/api/ads/ssv?" + signed(nonce, "tx-" + UUID.randomUUID()))).andExpect(status().isOk());
    }

    assertThat(adGrants(memberId)).isEqualTo(2);
    assertThatThrownBy(() -> sessionService.create(memberId))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.AD_REWARD_DAILY_LIMIT);
  }

  @Test
  @DisplayName("기능을 끄면 세션을 만들 수 없다")
  void disabled() {
    config.update(ConfigKey.AD_REWARD_ENABLED, "false");

    assertThatThrownBy(() -> sessionService.create(newMember()))
      .isInstanceOf(CustomException.class)
      .extracting(e -> ((CustomException) e).getErrorCode())
      .isEqualTo(ErrorCode.AD_REWARD_DISABLED);
  }

  // ---------------------------------------------------------------------------------------------

  private long adGrants(String memberId) {
    var account = accountRepository.findByMemberId(memberId).orElseThrow();
    return grantRepository.countByAccountIdAndSourceAndValidFromGreaterThanEqual(
      account.getId(), CreditGrantSource.AD_REWARD, LocalDate.now().atStartOfDay());
  }

  private String newMember() {
    Member member = new Member();
    member.setUsername("it_" + UUID.randomUUID());
    member.setPassword("x");
    return memberRepository.save(member).getId();
  }

  /// Google 처럼 서명한 콜백 쿼리. 서명 대상은 `&signature=` 앞의 원문 쿼리다.
  private static String signed(String nonce, String transactionId) throws Exception {
    String query = "ad_network=5450213213286189855&ad_unit=" + AD_UNIT + "&custom_data=" + nonce
      + "&reward_amount=1&reward_item=Reward&timestamp=1791000000000&transaction_id=" + transactionId;
    Signature signature = Signature.getInstance("SHA256withECDSA");
    signature.initSign(GOOGLE.getPrivate());
    signature.update(query.getBytes(StandardCharsets.UTF_8));
    String encoded = Base64.getUrlEncoder().withoutPadding().encodeToString(signature.sign());
    return query + "&signature=" + encoded + "&key_id=" + KEY_ID;
  }

  private static KeyPair newKeyPair() {
    try {
      KeyPairGenerator generator = KeyPairGenerator.getInstance("EC");
      generator.initialize(new ECGenParameterSpec("secp256r1"));
      return generator.generateKeyPair();
    } catch (Exception e) {
      throw new IllegalStateException(e);
    }
  }
}
