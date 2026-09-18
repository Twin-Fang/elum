package com.chuseok22.elumserver.license.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.core.PlanType;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.core.SubscriptionStatus;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 구독 행을 만들고 바꾼다. 권한을 <b>묻는</b> 것은 {@link EntitlementService}가 한다.
 *
 * <p>결제는 아직 붙이지 않는다 — 앱 스토어 심사 전이라 인앱결제를 쓸 수 없다. 지금은
 * 가입 시 Free를 만들고, 관리자가 Pro를 직접 켜고 끄는 것까지다. 결제가 생기면
 * 영수증 검증 서비스가 {@code source}와 {@code externalRef}를 채워 같은 표에 쓰면 된다.
 */
@Slf4j
@Service
@RequiredArgsConstructor
public class SubscriptionService {

  private final SubscriptionRepository subscriptionRepository;
  private final MemberRepository memberRepository;

  /**
   * 가입한 계정에 Free 구독을 만들어 둔다.
   *
   * <p>행이 없어도 Free로 보긴 하지만, 그래도 만들어 두는 이유는 관리자 화면에서 모든
   * 계정의 구독이 같은 모양으로 보이고 "언제부터 Free였는지"가 남기 때문이다.
   *
   * <p><b>예외를 삼키지 않는다.</b> 가입과 같은 트랜잭션이라 여기서 잡아도 커밋 시점에
   * 롤백된다 — 삼키면 "가입은 계속된다"고 믿게 만들 뿐 실제로는 안 된다. 작동하지 않는
   * 안전장치를 두느니 실패를 드러낸다.
   *
   * <p>그래도 최악의 경우가 안전한 이유는 따로 있다. <b>구독 행이 없어도 Free로
   * 동작</b>하므로, 어떤 이유로든 행이 안 만들어진 계정도 권한 판정에서 문제가 없다.
   */
  @Transactional
  public void createFreeIfAbsent(Member member) {
    if (member == null || member.getId() == null) {
      return;
    }
    if (subscriptionRepository.existsByMemberId(member.getId())) {
      return;
    }
    Subscription subscription = new Subscription();
    subscription.setMember(member);
    subscription.setPlan(PlanType.FREE);
    subscription.setStatus(SubscriptionStatus.ACTIVE);
    subscription.setSource(SubscriptionSource.SIGNUP);
    subscription.setStartedAt(LocalDateTime.now());
    subscriptionRepository.save(subscription);
  }

  @Transactional(readOnly = true)
  public Optional<Subscription> find(String memberId) {
    return subscriptionRepository.findByMemberId(memberId);
  }

  /**
   * 관리자가 Pro를 켠다.
   *
   * @param expiresAt null이면 무기한
   * @param memo      왜 켰는지. 나중에 "이 계정은 왜 Pro지"에 답하려면 있어야 하므로 필수다
   */
  @Transactional
  public Subscription grantPro(String memberId, LocalDateTime expiresAt, String memo) {
    if (memo == null || memo.isBlank()) {
      throw new CustomException(ErrorCode.INVALID_INPUT_VALUE);
    }
    Member member = memberRepository.findById(memberId)
      .orElseThrow(() -> new CustomException(ErrorCode.MEMBER_NOT_FOUND));

    Subscription subscription = subscriptionRepository.findByMemberId(memberId)
      .orElseGet(() -> {
        Subscription created = new Subscription();
        created.setMember(member);
        return created;
      });
    subscription.setPlan(PlanType.PRO);
    subscription.setStatus(SubscriptionStatus.ACTIVE);
    subscription.setSource(SubscriptionSource.MANUAL);
    subscription.setStartedAt(LocalDateTime.now());
    subscription.setExpiresAt(expiresAt);
    subscription.setMemo(memo.trim());
    Subscription saved = subscriptionRepository.save(subscription);
    log.info("관리자가 Pro를 발급했습니다: memberId={}, expiresAt={}, memo={}",
      memberId, expiresAt, memo);
    return saved;
  }

  /**
   * Pro를 거둔다. 행을 지우지 않고 Free로 되돌린다 — 지우면 언제 무엇을 했는지가 사라진다.
   */
  @Transactional
  public void revokePro(String memberId, String memo) {
    subscriptionRepository.findByMemberId(memberId).ifPresent(subscription -> {
      subscription.setPlan(PlanType.FREE);
      subscription.setStatus(SubscriptionStatus.ACTIVE);
      subscription.setSource(SubscriptionSource.MANUAL);
      subscription.setExpiresAt(null);
      subscription.setExternalRef(null);
      subscription.setMemo(memo == null || memo.isBlank() ? "관리자 회수" : memo.trim());
      subscriptionRepository.save(subscription);
      log.info("관리자가 Pro를 회수했습니다: memberId={}", memberId);
    });
  }
}
