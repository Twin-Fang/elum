package com.chuseok22.elumserver.member.infrastructure.scheduler;

import com.chuseok22.elumserver.member.application.service.WithdrawnMemberService;
import java.util.List;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

/**
 * 보관 기간이 지난 탈퇴 계정을 매일 완전히 지운다 (이슈 #372).
 *
 * <p>계정마다 따로 지운다({@link WithdrawnMemberService#purge} 가 계정 하나씩 트랜잭션을 연다).
 * 한 계정이 실패해도 나머지는 지우고, 실패한 계정은 행이 그대로 남아 다음 정리 때 다시 대상이 된다 (S7).
 * 실패를 기억해 건너뛰지 않는다 — 건너뛰면 보관 기간을 넘겨 남는다.
 *
 * <p>트랜잭션을 이 클래스에 두지 않는다. 여기서 열면 모든 계정이 한 트랜잭션에 묶여 하나만 실패해도
 * 전부 되돌아간다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class WithdrawnMemberPurgeScheduler {

  private final WithdrawnMemberService withdrawnMemberService;

  // 새벽 4시 반(한국 시각). 사용이 가장 적은 때라 지우는 동안 로그인과 겹칠 일이 적다.
  // 설정으로 바꿀 수 있게 열어 둔다 — 로컬에서 짧게 돌려 실제 DB 로 확인할 때 쓴다.
  @Scheduled(cron = "${elum.member.withdrawn-purge-cron:0 30 4 * * *}", zone = "Asia/Seoul")
  public void run() {
    purgeExpired();
  }

  /** 한 번 정리한다. 몇 건을 지웠고 몇 건이 실패했는지 돌려준다. */
  public PurgeResult purgeExpired() {
    List<String> expiredIds;
    try {
      expiredIds = withdrawnMemberService.findExpiredIds();
    } catch (Exception e) {
      // 밖으로 던져도 스케줄러가 삼킨다. 여기서 원인과 함께 남겨야 추적된다. 다음 정리 때 다시 돈다.
      log.error("보관 기간이 지난 탈퇴 계정을 고르지 못했습니다 — 다음 정리 때 다시 시도합니다", e);
      return new PurgeResult(0, 0);
    }

    int purged = 0;
    int failed = 0;
    for (String memberId : expiredIds) {
      try {
        withdrawnMemberService.purge(memberId);
        purged++;
      } catch (Exception e) {
        failed++;
        log.error("탈퇴 계정 완전 삭제에 실패했습니다 — 다음 정리 때 다시 시도합니다: memberId={}", memberId, e);
      }
    }

    if (!expiredIds.isEmpty()) {
      log.info("보관 기간이 지난 탈퇴 계정 정리: 대상={}, 지움={}, 실패={}", expiredIds.size(), purged, failed);
    }
    return new PurgeResult(purged, failed);
  }

  public record PurgeResult(int purged, int failed) {

  }
}
