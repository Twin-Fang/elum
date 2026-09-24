package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import com.chuseok22.elumserver.member.infrastructure.entity.Profile;
import com.chuseok22.elumserver.member.infrastructure.repository.ProfileRepository;
import java.io.IOException;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.List;
import java.util.stream.Stream;
import org.hibernate.annotations.DynamicUpdate;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.jpa.repository.Modifying;
import org.springframework.data.jpa.repository.Query;

/**
 * 별은 원자적 쿼리로만 바뀐다 (다중 보호자 E25).
 *
 * <p>DB 없이 도는 단위 테스트는 동시 요청의 사라진 별을 볼 수 없다. 대신 "엔티티 값을 읽어 더하는
 * 코드가 다시 생기지 않았나"를 글로 본다. 실제 동시성은 운영 사본 리허설에서 본다.
 */
class ProfileStarsAtomicTest {

  @Test
  @DisplayName("E25 서비스 코드는 별을 setter 로 고치지 않는다 — 두 기기가 동시에 체크하면 하나가 사라진다")
  void noServiceSetsTotalStars() throws IOException {
    try (Stream<Path> files = Files.walk(Path.of("src/main/java"))) {
      List<String> offenders = files.filter(p -> p.toString().endsWith(".java"))
        .filter(p -> {
          try {
            return Files.readString(p).contains("setTotalStars(");
          } catch (IOException e) {
            throw new IllegalStateException(e);
          }
        })
        .map(p -> p.getFileName().toString())
        .toList();
      assertThat(offenders).as("별은 ProfileRepository.addStars 로만 바꾼다").isEmpty();
    }
  }

  @Test
  @DisplayName("E25 별을 빼도 0 아래로 내려가지 않는다 — 쿼리가 막는다")
  void addStarsClampsAtZero() throws NoSuchMethodException {
    String jpql = ProfileRepository.class.getMethod("addStars", String.class, int.class)
      .getAnnotation(Query.class).value();
    assertThat(jpql).contains("p.totalStars + :delta").contains("< 0 then 0");
  }

  @Test
  @DisplayName("별 쿼리는 앞선 변경을 먼저 flush 하지 않는다 — 나가기와 잠금 순서(이룸이 → 단계)가 같아야 교착이 없다")
  void addStarsKeepsLockOrder() throws NoSuchMethodException {
    Modifying modifying = ProfileRepository.class.getMethod("addStars", String.class, int.class)
      .getAnnotation(Modifying.class);
    assertThat(modifying).isNotNull();
    assertThat(modifying.flushAutomatically()).isFalse();
    assertThat(modifying.clearAutomatically()).isFalse();
  }

  @Test
  @DisplayName("E23 이룸이 정보를 고쳐도 별 컬럼을 덮어쓰지 않는다 — 바뀐 컬럼만 UPDATE")
  void profileUsesDynamicUpdate() {
    assertThat(Profile.class.isAnnotationPresent(DynamicUpdate.class)).isTrue();
  }
}
