package com.chuseok22.elumserver.license.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionHistoryAction;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionHistoryRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDateTime;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.mockito.junit.jupiter.MockitoSettings;
import org.mockito.quality.Strictness;

/**
 * 요금제 부여·회수는 상태가 바뀔 때마다 이력이 같이 쌓인다
 * 이력 없이 상태만 바뀌면 "누가 왜 Pro로 바꿨는지"를 DB 를 열어야 알게 된다
 */
// 공통 준비(setUp)의 목은 테스트마다 일부만 쓴다
@ExtendWith(MockitoExtension.class)
@MockitoSettings(strictness = Strictness.LENIENT)
class SubscriptionServiceHistoryTest {

  private static final String MEMBER_ID = "m1";

  @Mock private SubscriptionRepository subscriptionRepository;
  @Mock private SubscriptionHistoryRepository subscriptionHistoryRepository;
  @Mock private MemberRepository memberRepository;

  private SubscriptionService subscriptionService;
  private Subscription storedSubscription;
  private final List<SubscriptionHistory> savedHistories = new ArrayList<>();

  @BeforeEach
  void setUp() {
    subscriptionService = new SubscriptionService(subscriptionRepository, subscriptionHistoryRepository, memberRepository);
    storedSubscription = null;
    savedHistories.clear();
    Member member = new Member();
    member.setId(MEMBER_ID);
    when(memberRepository.findById(MEMBER_ID)).thenReturn(Optional.of(member));
    when(subscriptionRepository.findByMemberId(MEMBER_ID)).thenAnswer(call -> Optional.ofNullable(storedSubscription));
    when(subscriptionRepository.save(any(Subscription.class))).thenAnswer(call -> {
      storedSubscription = call.getArgument(0);
      return storedSubscription;
    });
    when(subscriptionHistoryRepository.save(any(SubscriptionHistory.class))).thenAnswer(call -> {
      savedHistories.add(call.getArgument(0));
      return call.getArgument(0);
    });
  }

  @Test
  @DisplayName("연속 두 번 부여하면 이력이 2건이고 마지막 상태가 두 번째 값이다")
  void grantTwice_recordsTwoHistoriesAndLastState() {
    subscriptionService.grantPro(MEMBER_ID, 30, "베타 테스터", "admin1");
    subscriptionService.grantPro(MEMBER_ID, null, "정식 파트너", "admin2");

    assertThat(savedHistories).hasSize(2);
    SubscriptionHistory first = savedHistories.get(0);
    assertThat(first.getAction()).isEqualTo(SubscriptionHistoryAction.GRANT);
    assertThat(first.getBeforePlan()).isEqualTo(PlanType.FREE);
    assertThat(first.getAfterPlan()).isEqualTo(PlanType.PRO);
    assertThat(first.getDurationDays()).isEqualTo(30);
    assertThat(first.getAfterExpiresAt()).isNotNull();
    assertThat(first.getReason()).isEqualTo("베타 테스터");
    assertThat(first.getChangedBy()).isEqualTo("admin1");
    assertThat(first.getChangedAt()).isNotNull();

    SubscriptionHistory second = savedHistories.get(1);
    assertThat(second.getBeforePlan()).isEqualTo(PlanType.PRO);
    assertThat(second.getAfterPlan()).isEqualTo(PlanType.PRO);
    assertThat(second.getBeforeExpiresAt()).isEqualTo(first.getAfterExpiresAt());
    assertThat(second.getDurationDays()).isNull();
    assertThat(second.getAfterExpiresAt()).isNull();
    assertThat(second.getChangedBy()).isEqualTo("admin2");

    assertThat(storedSubscription.getPlan()).isEqualTo(PlanType.PRO);
    assertThat(storedSubscription.getExpiresAt()).isNull();
    assertThat(storedSubscription.getMemo()).isEqualTo("정식 파트너");
  }

  @Test
  @DisplayName("부여 기간은 지금부터 일수만큼이고 0 이하면 무기한이다")
  void grant_computesExpiryFromDays() {
    LocalDateTime before = LocalDateTime.now();
    subscriptionService.grantPro(MEMBER_ID, 7, "시연", "admin1");
    LocalDateTime after = LocalDateTime.now();

    assertThat(storedSubscription.getExpiresAt()).isBetween(before.plusDays(7), after.plusDays(7));

    subscriptionService.grantPro(MEMBER_ID, 0, "무기한", "admin1");
    assertThat(storedSubscription.getExpiresAt()).isNull();
    assertThat(savedHistories.get(1).getDurationDays()).isNull();
  }

  @Test
  @DisplayName("회수하면 이력에 전후 요금제가 남고 Free 로 돌아간다")
  void revoke_recordsBeforeAndAfter() {
    subscriptionService.grantPro(MEMBER_ID, 30, "베타 테스터", "admin1");
    LocalDateTime grantedExpiry = storedSubscription.getExpiresAt();

    subscriptionService.revokePro(MEMBER_ID, "기간 오입력", "admin2");

    assertThat(savedHistories).hasSize(2);
    SubscriptionHistory revoke = savedHistories.get(1);
    assertThat(revoke.getAction()).isEqualTo(SubscriptionHistoryAction.REVOKE);
    assertThat(revoke.getBeforePlan()).isEqualTo(PlanType.PRO);
    assertThat(revoke.getAfterPlan()).isEqualTo(PlanType.FREE);
    assertThat(revoke.getBeforeExpiresAt()).isEqualTo(grantedExpiry);
    assertThat(revoke.getAfterExpiresAt()).isNull();
    assertThat(revoke.getReason()).isEqualTo("기간 오입력");
    assertThat(revoke.getChangedBy()).isEqualTo("admin2");
    assertThat(storedSubscription.getPlan()).isEqualTo(PlanType.FREE);
    assertThat(storedSubscription.getExpiresAt()).isNull();
  }

  @Test
  @DisplayName("회수 사유를 비우면 기본 문구로 기록하고, 만료된 Pro 는 이전 요금제를 Free 로 남긴다")
  void revoke_blankReasonUsesDefault_andExpiredProCountsAsFree() {
    subscriptionService.grantPro(MEMBER_ID, 30, "베타", "admin1");
    storedSubscription.setExpiresAt(LocalDateTime.now().minusDays(1));

    subscriptionService.revokePro(MEMBER_ID, "  ", "admin1");

    SubscriptionHistory revoke = savedHistories.get(1);
    assertThat(revoke.getReason()).isEqualTo(SubscriptionService.DEFAULT_REVOKE_REASON);
    assertThat(revoke.getBeforePlan()).isEqualTo(PlanType.FREE);
    assertThat(storedSubscription.getMemo()).isEqualTo(SubscriptionService.DEFAULT_REVOKE_REASON);
  }

  @Test
  @DisplayName("구독 행이 없는 회원을 회수하면 상태가 안 바뀌므로 이력도 만들지 않는다")
  void revoke_withoutSubscription_recordsNothing() {
    subscriptionService.revokePro(MEMBER_ID, "정리", "admin1");

    verify(subscriptionHistoryRepository, never()).save(any());
    verify(subscriptionRepository, never()).save(any());
  }

  @Test
  @DisplayName("사유가 비면 부여를 거부하고 상태도 이력도 바꾸지 않는다")
  void grant_blankReason_rejectsWithoutSideEffects() {
    assertThatThrownBy(() -> subscriptionService.grantPro(MEMBER_ID, 30, " ", "admin1"))
      .isInstanceOf(CustomException.class)
      .satisfies(e -> assertThat(((CustomException) e).getErrorCode()).isEqualTo(ErrorCode.INVALID_INPUT_VALUE));

    verify(subscriptionRepository, never()).save(any());
    verify(subscriptionHistoryRepository, never()).save(any());
  }

  @Test
  @DisplayName("변경자를 못 알아내면 이력에 unknown 으로 남긴다 (이력을 빠뜨리지 않는다)")
  void blankActor_isRecordedAsUnknown() {
    subscriptionService.grantPro(MEMBER_ID, 1, "시연", null);

    assertThat(savedHistories.get(0).getChangedBy()).isEqualTo(SubscriptionService.UNKNOWN_ACTOR);
  }
}
