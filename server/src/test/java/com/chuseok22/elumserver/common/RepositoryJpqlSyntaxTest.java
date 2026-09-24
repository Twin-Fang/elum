package com.chuseok22.elumserver.common;

import static org.assertj.core.api.Assertions.assertThat;

import jakarta.persistence.EntityManager;
import java.lang.reflect.Method;
import java.util.ArrayList;
import java.util.List;
import org.junit.jupiter.api.AfterAll;
import org.junit.jupiter.api.BeforeAll;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.springframework.core.type.filter.AssignableTypeFilter;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.Repository;

/**
 * 저장소의 {@code @Query} JPQL 이 엔티티와 맞는지 DB 없이 해석해 본다 (#407).
 *
 * <p>JPQL 에 없는 필드·오타가 있으면 저장소 빈을 만들다 <b>서버 기동이 통째로 실패한다.</b> 이 저장소는
 * 스프링 컨텍스트를 띄우는 테스트가 없어 컴파일·단위 테스트가 모두 통과한 채 배포될 수 있다
 * (AiDailyBudgetGuard 주석이 같은 걱정을 적어 두었다). 관리자 크레딧 화면이 집계 JPQL 을 여럿 더해서 둔다.
 *
 * <p>네이티브 쿼리는 SQL 이라 해석하지 않는다. 메서드 이름으로 만드는 파생 쿼리도 보지 않는다.
 */
class RepositoryJpqlSyntaxTest {

  private static OfflineHibernate hibernate;

  @BeforeAll
  static void boot() {
    hibernate = OfflineHibernate.open();
  }

  @AfterAll
  static void close() {
    hibernate.close();
  }

  @Test
  @DisplayName("저장소의 JPQL 은 모두 엔티티 모델로 해석돼야 한다")
  void everyJpqlParses() {
    List<String> broken = new ArrayList<>();
    int checked = 0;
    try (EntityManager em = hibernate.sessionFactory().createEntityManager()) {
      for (Class<?> repository : OfflineHibernate.scan(new AssignableTypeFilter(Repository.class))) {
        for (Method method : repository.getDeclaredMethods()) {
          Query query = method.getAnnotation(Query.class);
          if (query == null || query.nativeQuery() || query.value().isBlank()) {
            continue;
          }
          checked++;
          try {
            // 만들기만 한다(실행하지 않는다) — 이때 구문·의미 분석이 끝난다.
            em.createQuery(query.value());
          } catch (RuntimeException e) {
            broken.add("%s#%s — %s".formatted(repository.getSimpleName(), method.getName(), e.getMessage()));
          }
        }
      }
    }
    assertThat(checked).as("검사가 헛돌지 않도록 — JPQL 이 하나도 안 잡히면 스캔 경로가 바뀐 것이다").isPositive();
    assertThat(broken).as("JPQL 오류는 서버 기동 실패로 이어진다").isEmpty();
  }
}
