package com.chuseok22.elumserver.common;

import jakarta.persistence.Entity;
import java.util.ArrayList;
import java.util.List;
import org.hibernate.boot.MetadataSources;
import org.hibernate.boot.registry.StandardServiceRegistry;
import org.hibernate.boot.registry.StandardServiceRegistryBuilder;
import org.hibernate.engine.spi.SessionFactoryImplementor;
import org.springframework.beans.factory.annotation.AnnotatedBeanDefinition;
import org.springframework.context.annotation.ClassPathScanningCandidateComponentProvider;
import org.springframework.core.type.filter.AnnotationTypeFilter;
import org.springframework.core.type.filter.TypeFilter;

/**
 * DB 없이 띄운 하이버네이트 — 엔티티 모델만 있다 (#407).
 *
 * <p>JPQL·Criteria 가 엔티티와 맞는지 해석해 보는 데 쓴다. JDBC 메타데이터 접근을 꺼서 연결을 만들지 않는다 —
 * 쿼리를 실행하면 실패한다(해석만 한다).
 */
public final class OfflineHibernate implements AutoCloseable {

  static final String BASE_PACKAGE = "com.chuseok22.elumserver";

  private final StandardServiceRegistry registry;
  private final SessionFactoryImplementor sessionFactory;

  private OfflineHibernate(StandardServiceRegistry registry, SessionFactoryImplementor sessionFactory) {
    this.registry = registry;
    this.sessionFactory = sessionFactory;
  }

  public static OfflineHibernate open() {
    StandardServiceRegistry registry = new StandardServiceRegistryBuilder()
      .applySetting("hibernate.dialect", "org.hibernate.dialect.PostgreSQLDialect")
      .applySetting("hibernate.boot.allow_jdbc_metadata_access", "false")
      .applySetting("hibernate.hbm2ddl.auto", "none")
      .build();
    MetadataSources sources = new MetadataSources(registry);
    for (Class<?> entity : scan(new AnnotationTypeFilter(Entity.class))) {
      sources.addAnnotatedClass(entity);
    }
    SessionFactoryImplementor factory = sources.buildMetadata().buildSessionFactory()
      .unwrap(SessionFactoryImplementor.class);
    return new OfflineHibernate(registry, factory);
  }

  public SessionFactoryImplementor sessionFactory() {
    return sessionFactory;
  }

  @Override
  public void close() {
    sessionFactory.close();
    StandardServiceRegistryBuilder.destroy(registry);
  }

  /// 인터페이스(저장소)도 후보로 받도록 독립 클래스 판정을 푼 스캐너.
  public static List<Class<?>> scan(TypeFilter filter) {
    ClassPathScanningCandidateComponentProvider scanner = new ClassPathScanningCandidateComponentProvider(false) {
      @Override
      protected boolean isCandidateComponent(AnnotatedBeanDefinition definition) {
        return true;
      }
    };
    scanner.addIncludeFilter(filter);
    List<Class<?>> types = new ArrayList<>();
    for (var definition : scanner.findCandidateComponents(BASE_PACKAGE)) {
      try {
        types.add(Class.forName(definition.getBeanClassName()));
      } catch (ClassNotFoundException e) {
        throw new IllegalStateException("스캔한 클래스를 불러오지 못했다: " + definition.getBeanClassName(), e);
      }
    }
    return types;
  }
}
