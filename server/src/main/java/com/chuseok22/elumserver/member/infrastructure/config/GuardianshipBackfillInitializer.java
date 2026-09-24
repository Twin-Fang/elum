package com.chuseok22.elumserver.member.infrastructure.config;

import com.chuseok22.elumserver.member.infrastructure.repository.ProfileGuardianRepository;
import com.chuseok22.elumserver.routine.infrastructure.repository.RoutineRepository;
import java.util.function.IntSupplier;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.boot.ApplicationArguments;
import org.springframework.boot.ApplicationRunner;
import org.springframework.stereotype.Component;

/**
 * 옛 서버로 되돌려 있던 동안 생긴 빈칸을 부팅할 때마다 메운다 (다중 보호자 명세 5장 되돌리기, E38).
 *
 * <p>V25 뒤에 옛 서버 이미지로 되돌리면 옛 코드는 관계 표와 {@code routine.created_by} 를 모른 채
 * 가입·일과 생성을 한다. 그 뒤 새 서버를 다시 올려도 V25 는 이미 적용돼 다시 돌지 않는다. 그 사이
 * 가입한 사람은 관계가 없어 이룸이를 못 찾고(404), 그 사이 만든 일과는 만든 사람이 없어 아무도 고칠 수
 * 없다. 명세는 4단계 마이그레이션(명세의 V23, #364)이 메운다고 했지만 그것은 다음 배포라 그 사이가 빈다.
 *
 * <p>트랜잭션을 여기서 열지 않는다 — 한 문장이 실패해 전체가 롤백 전용이 되면 커밋 때 예외가 나서
 * 부팅이 죽는다. 문장마다 리포지토리가 자기 트랜잭션을 연다.
 */
@Slf4j
@Component
@RequiredArgsConstructor
public class GuardianshipBackfillInitializer implements ApplicationRunner {

  private final ProfileGuardianRepository profileGuardianRepository;
  private final RoutineRepository routineRepository;

  @Override
  public void run(ApplicationArguments args) {
    int guardians = backfill("관계", profileGuardianRepository::backfillFromProfileOwner);
    int creators = backfill("일과 만든 사람", routineRepository::backfillCreatorFromProfileOwner);
    if (guardians > 0 || creators > 0) {
      // 평소에는 0 이다. 0 이 아니면 옛 서버가 돌았다는 뜻이라 눈에 띄게 남긴다.
      log.warn("옛 서버가 남긴 빈칸을 메웠습니다: 관계={}, 일과 만든 사람={}", guardians, creators);
    }
  }

  private int backfill(String what, IntSupplier statement) {
    try {
      return statement.getAsInt();
    } catch (RuntimeException e) {
      // 부팅을 죽이지 않는다. 빈칸이 남으면 그 사람만 이룸이를 못 찾고, 다음 부팅에서 다시 메운다.
      log.error("옛 서버가 남긴 빈칸({})을 메우지 못했습니다 — 다음 부팅에서 다시 시도합니다", what, e);
      return 0;
    }
  }
}
