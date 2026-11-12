package com.chuseok22.elumserver.notification.infrastructure.repository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.CALLS_REAL_METHODS;
import static org.mockito.Mockito.doReturn;
import static org.mockito.Mockito.mock;

import com.chuseok22.elumserver.notification.infrastructure.entity.ScheduledAdminPush;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

class ScheduledAdminPushRepositoryTest {

  @Test
  @DisplayName("탈퇴 회원만 예약 대상에서 빠진다 — id 가 겹치는 다른 회원을 지우면 그 회원이 예약 알림을 못 받는다")
  void deleteMemberFromTargets_removesOnlyExactId() {
    ScheduledAdminPushRepository repository = mock(ScheduledAdminPushRepository.class, CALLS_REAL_METHODS);
    ScheduledAdminPush scheduled = new ScheduledAdminPush();
    scheduled.setMemberIds("member-1, member-10,member-2");
    doReturn(List.of(scheduled)).when(repository).findByMemberIdsContaining("member-1");

    repository.deleteMemberFromTargets("member-1");

    assertThat(scheduled.getMemberIds()).isEqualTo("member-10,member-2");
  }
}
