package com.chuseok22.elumserver.routine.application.service;

import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Component;

/**
 * AI 맞춤 그림 권한(AI_IMAGE_GENERATION): 새 일과·카드 추가는 건너뜀, 다시 그리기·그림 그리기는 거절
 * 이미 만든 그림 조회는 여기를 거치지 않음 (요금제와 무관하게 계속 보임)
 */
@Component
@RequiredArgsConstructor
public class RoutineAiPicturePolicy {

  private final EntitlementService entitlementService;

  /// 새 카드에 AI 그림을 그리지 않고 픽토그램만 둘 회원인가 (Free + FREE_AI_IMAGE_GENERATION 꺼짐)
  public boolean shouldSkipAiPicture(String memberId) {
    return !entitlementService.isAllowed(memberId, Entitlement.AI_IMAGE_GENERATION);
  }

  /// 다시 그리기·그림 그리기 진입 검사. 권한 없으면 403 AI_IMAGE_NOT_ALLOWED (크레딧 예약 전)
  public void requireAiPicture(String memberId) {
    entitlementService.requireAllowed(memberId, Entitlement.AI_IMAGE_GENERATION);
  }
}
