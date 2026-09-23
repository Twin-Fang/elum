package com.chuseok22.elumserver.routine.infrastructure.repository;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatCode;

import com.chuseok22.elumserver.routine.infrastructure.entity.Routine;
import java.lang.reflect.Method;
import java.util.Arrays;
import java.util.List;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.parser.PartTree;

/// 파생 쿼리 이름이 엔티티 속성과 맞는지 **컨텍스트 없이** 본다.
///
/// 이 저장소에는 스프링 컨텍스트를 띄우는 테스트가 없다. 파생 쿼리 이름에 오타가
/// 있으면 서버가 **뜰 때** 죽는데, 단위 테스트는 저장소를 mock 으로 바꿔 끼우므로
/// 아무것도 잡지 못한다. 스프링 데이터가 이름을 읽는 파서(`PartTree`)를 직접 돌려
/// 같은 검사를 여기서 한다.
class RoutineRepositoryDerivedQueryTest {

  @Test
  @DisplayName("@Query 가 없는 조회 메서드는 모두 Routine 속성으로 풀린다")
  void derivedQueryNamesResolveAgainstRoutine() {
    List<Method> derived = Arrays.stream(RoutineRepository.class.getDeclaredMethods())
      .filter(m -> !m.isAnnotationPresent(Query.class))
      .filter(m -> !m.isDefault())
      .toList();
    assertThat(derived).isNotEmpty();

    for (Method m : derived) {
      assertThatCode(() -> new PartTree(m.getName(), Routine.class))
        .as(m.getName())
        .doesNotThrowAnyException();
    }
  }

  @Test
  @DisplayName("지난 일과 조회는 상태로 거른다 — 임시저장이 지난 일과에 섞이지 않는다 (#387)")
  void pastRoutinesQueryFiltersByStatus() {
    PartTree tree = new PartTree(
      "findAllByProfileIdAndStatusInAndScheduledAtBeforeOrderByScheduledAtDesc", Routine.class);
    List<String> props = tree.getParts().stream()
      .map(p -> p.getProperty().toDotPath() + ":" + p.getType().name())
      .toList();
    assertThat(props).containsExactly(
      "profile.id:SIMPLE_PROPERTY", "status:IN", "scheduledAt:BEFORE");
  }
}
