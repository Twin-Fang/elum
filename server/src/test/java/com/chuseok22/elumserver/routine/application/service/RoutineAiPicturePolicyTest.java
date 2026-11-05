package com.chuseok22.elumserver.routine.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;
import static org.assertj.core.api.Assertions.assertThatThrownBy;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.license.application.service.EntitlementService;
import com.chuseok22.elumserver.license.core.Entitlement;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/**
 * AI 맞춤 그림 권한 판정: 깨지면 Free 가 원가 드는 그림을 받거나, Pro 가 다시 그리기를 못 쓴다
 */
@ExtendWith(MockitoExtension.class)
class RoutineAiPicturePolicyTest {

  @Mock
  private EntitlementService entitlementService;

  @InjectMocks
  private RoutineAiPicturePolicy routineAiPicturePolicy;

  @Test
  @DisplayName("AI_IMAGE_GENERATION 권한이 없으면 건너뛰고, 다시 그리기 진입은 AI_IMAGE_NOT_ALLOWED(403)")
  void withoutEntitlement_skipsAndRejects() {
    when(entitlementService.isAllowed("m1", Entitlement.AI_IMAGE_GENERATION)).thenReturn(false);

    doThrow(new CustomException(Entitlement.AI_IMAGE_GENERATION.rejectionCode())).when(entitlementService)
      .requireAllowed("m1", Entitlement.AI_IMAGE_GENERATION);

    assertThat(routineAiPicturePolicy.shouldSkipAiPicture("m1")).isTrue();
    assertThatThrownBy(() -> routineAiPicturePolicy.requireAiPicture("m1"))
      .hasFieldOrPropertyWithValue("errorCode", ErrorCode.AI_IMAGE_NOT_ALLOWED);
    assertThat(ErrorCode.AI_IMAGE_NOT_ALLOWED.getStatus().value()).isEqualTo(403);
  }

  @Test
  @DisplayName("권한이 있으면 그림을 그리고 진입도 통과한다")
  void withEntitlement_drawsAndPasses() {
    when(entitlementService.isAllowed("m1", Entitlement.AI_IMAGE_GENERATION)).thenReturn(true);

    assertThat(routineAiPicturePolicy.shouldSkipAiPicture("m1")).isFalse();
    assertThatCode(() -> routineAiPicturePolicy.requireAiPicture("m1")).doesNotThrowAnyException();
    verify(entitlementService).requireAllowed("m1", Entitlement.AI_IMAGE_GENERATION);
  }
}
