package com.chuseok22.elumserver.license.application.service.store;

import java.util.function.Predicate;

/**
 * 스토어 구매 > 회원 연결 판정: 이미 묶인 회원, 구매 때 앱이 실은 회원 id, 요청한 회원
 * 앱 검증: 다른 활성 회원이 주인이면 거부, 아니면 요청 회원에 묶음 (탈퇴한 주인의 구매는 다시 묶음)
 * 스토어 알림: 활성 주인 > 앱이 실은 회원 id(활성) > 기존 주인 유지(없으면 미연결)
 */
public final class StorePurchaseBindingPolicy {

  private StorePurchaseBindingPolicy() {
  }

  /**
   * @param currentOwnerMemberId 이 구매(또는 이전 구매 토큰)에 이미 묶인 회원, 없으면 null
   * @param appAccountId         구매 때 앱이 실은 회원 id, 없으면 null
   * @param requesterMemberId    앱 검증 요청 회원, 스토어 알림이면 null
   * @param isActiveMember       회원 id > 탈퇴하지 않은 회원인가
   */
  public static BindingDecision decide(
    String currentOwnerMemberId, String appAccountId, String requesterMemberId, Predicate<String> isActiveMember
  ) {
    if (requesterMemberId != null) {
      return decideForRequester(currentOwnerMemberId, appAccountId, requesterMemberId, isActiveMember);
    }
    if (currentOwnerMemberId != null && isActiveMember.test(currentOwnerMemberId)) {
      return BindingDecision.bindTo(currentOwnerMemberId);
    }
    if (appAccountId != null && isActiveMember.test(appAccountId)) {
      return BindingDecision.bindTo(appAccountId);
    }
    return BindingDecision.bindTo(currentOwnerMemberId);
  }

  private static BindingDecision decideForRequester(
    String currentOwnerMemberId, String appAccountId, String requesterMemberId, Predicate<String> isActiveMember
  ) {
    // 이미 다른 활성 회원에 묶인 구매 (같은 스토어 계정으로 다른 이룸 계정에서 복원 시도)
    if (currentOwnerMemberId != null) {
      boolean isOtherActiveOwner = !isSameMember(currentOwnerMemberId, requesterMemberId)
        && isActiveMember.test(currentOwnerMemberId);
      return isOtherActiveOwner ? BindingDecision.rejected() : BindingDecision.bindTo(requesterMemberId);
    }
    // 아직 안 묶였지만 구매 때 다른 활성 회원 id 를 실음
    if (appAccountId != null && !isSameMember(appAccountId, requesterMemberId) && isActiveMember.test(appAccountId)) {
      return BindingDecision.rejected();
    }
    return BindingDecision.bindTo(requesterMemberId);
  }

  // 회원 id 는 UUID 문자열, Apple appAccountToken 은 소문자 UUID 로 옴
  static boolean isSameMember(String left, String right) {
    return left != null && left.equalsIgnoreCase(right);
  }

  /**
   * 판정 결과: 거부, 또는 묶을 회원 (null 이면 미연결로 상태만 저장)
   */
  public record BindingDecision(boolean isRejected, String ownerMemberId) {

    static BindingDecision bindTo(String ownerMemberId) {
      return new BindingDecision(false, ownerMemberId);
    }

    static BindingDecision rejected() {
      return new BindingDecision(true, null);
    }
  }
}
