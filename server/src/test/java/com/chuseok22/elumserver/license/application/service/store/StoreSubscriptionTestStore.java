package com.chuseok22.elumserver.license.application.service.store;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.license.application.service.SubscriptionService;
import com.chuseok22.elumserver.license.core.SubscriptionSource;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchase;
import com.chuseok22.elumserver.license.infrastructure.entity.StorePurchaseEvent;
import com.chuseok22.elumserver.license.infrastructure.entity.Subscription;
import com.chuseok22.elumserver.license.infrastructure.entity.SubscriptionHistory;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseEventRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.StorePurchaseRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionHistoryRepository;
import com.chuseok22.elumserver.license.infrastructure.repository.SubscriptionRepository;
import com.chuseok22.elumserver.member.infrastructure.entity.Member;
import com.chuseok22.elumserver.member.infrastructure.entity.MemberStatus;
import com.chuseok22.elumserver.member.infrastructure.repository.MemberRepository;
import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.UUID;

/**
 * 스토어 반영 시험용 메모리 저장소: 구매·거래 이력·구독·요금제 이력·회원 (repository 는 메모리 맵에 붙인 mock)
 * 반영 로직(StorePurchaseApplier)과 구독 반영(SubscriptionService)은 실제 클래스를 그대로 씀
 */
final class StoreSubscriptionTestStore {

  static final ZoneId ZONE = ZoneId.systemDefault();
  static final LocalDateTime NOW = LocalDateTime.of(2026, 11, 5, 12, 0);

  final Map<String, StorePurchase> purchasesByKey = new HashMap<>();
  final List<StorePurchaseEvent> events = new ArrayList<>();
  final Map<String, Subscription> subscriptionsByMemberId = new HashMap<>();
  final List<SubscriptionHistory> histories = new ArrayList<>();
  final Map<String, Member> membersById = new HashMap<>();

  final StorePurchaseApplier applier;

  StoreSubscriptionTestStore() {
    StorePurchaseRepository purchaseRepository = mock(StorePurchaseRepository.class);
    StorePurchaseEventRepository eventRepository = mock(StorePurchaseEventRepository.class);
    SubscriptionRepository subscriptionRepository = mock(SubscriptionRepository.class);
    SubscriptionHistoryRepository historyRepository = mock(SubscriptionHistoryRepository.class);
    MemberRepository memberRepository = mock(MemberRepository.class);

    lenient().when(purchaseRepository.findForUpdate(any(), anyString()))
      .thenAnswer(call -> Optional.ofNullable(purchasesByKey.get(keyOf(call.getArgument(0), call.getArgument(1)))));
    lenient().when(purchaseRepository.findByMemberId(anyString())).thenAnswer(call -> purchasesByKey.values().stream()
      .filter(purchase -> call.getArgument(0).equals(purchase.getMemberId())).toList());
    lenient().when(purchaseRepository.save(any(StorePurchase.class))).thenAnswer(call -> {
      StorePurchase purchase = call.getArgument(0);
      if (purchase.getId() == null) {
        purchase.setId(UUID.randomUUID().toString());
      }
      purchasesByKey.put(keyOf(purchase.getStore(), purchase.getPurchaseKey()), purchase);
      return purchase;
    });
    lenient().when(eventRepository.save(any(StorePurchaseEvent.class))).thenAnswer(call -> {
      events.add(call.getArgument(0));
      return call.getArgument(0);
    });
    lenient().when(eventRepository.existsByStoreAndExternalEventId(any(), anyString())).thenAnswer(call -> events.stream()
      .anyMatch(event -> event.getStore() == call.getArgument(0) && call.getArgument(1).equals(event.getExternalEventId())));
    lenient().when(subscriptionRepository.findByMemberIdForUpdate(anyString()))
      .thenAnswer(call -> Optional.ofNullable(subscriptionsByMemberId.get((String) call.getArgument(0))));
    lenient().when(subscriptionRepository.save(any(Subscription.class))).thenAnswer(call -> {
      Subscription subscription = call.getArgument(0);
      subscriptionsByMemberId.put(subscription.getMember().getId(), subscription);
      return subscription;
    });
    lenient().when(historyRepository.save(any(SubscriptionHistory.class))).thenAnswer(call -> {
      histories.add(call.getArgument(0));
      return call.getArgument(0);
    });
    lenient().when(memberRepository.findById(anyString()))
      .thenAnswer(call -> Optional.ofNullable(membersById.get((String) call.getArgument(0))));

    SubscriptionService subscriptionService = new SubscriptionService(subscriptionRepository, historyRepository, memberRepository);
    Clock clock = Clock.fixed(Instant.from(NOW.atZone(ZONE)), ZONE);
    applier = new StorePurchaseApplier(purchaseRepository, eventRepository, subscriptionService, clock);
  }

  Member addMember(String memberId, MemberStatus status) {
    Member member = new Member();
    member.setId(memberId);
    member.setStatus(status);
    membersById.put(memberId, member);
    return member;
  }

  StorePurchase purchase(SubscriptionSource store, String purchaseKey) {
    return purchasesByKey.get(keyOf(store, purchaseKey));
  }

  private static String keyOf(Object store, Object purchaseKey) {
    return store + "|" + purchaseKey;
  }
}
