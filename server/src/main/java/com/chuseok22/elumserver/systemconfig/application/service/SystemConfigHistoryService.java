package com.chuseok22.elumserver.systemconfig.application.service;

import com.chuseok22.elumserver.systemconfig.infrastructure.entity.SystemConfigHistory;
import com.chuseok22.elumserver.systemconfig.infrastructure.repository.SystemConfigHistoryRepository;
import jakarta.persistence.criteria.Predicate;
import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Pageable;
import org.springframework.data.domain.Sort;
import org.springframework.data.jpa.domain.Specification;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 설정 변경 이력 조회: 키별 최신 1줄, 한 키의 이력, 조건 검색 + 페이지
 * 쓰기는 SystemConfigService 가 담당 (여기는 읽기 전용)
 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class SystemConfigHistoryService {

  /** LIKE 검색의 이스케이프 문자 (AdminListQuery.likePattern 과 같은 값) */
  private static final char LIKE_ESCAPE = '\\';
  /** 한 키의 이력 패널에 보여 줄 최대 건수 */
  public static final int KEY_HISTORY_LIMIT = 50;
  private static final String CREATED_AT_FIELD = "createdAt";

  private final SystemConfigHistoryRepository historyRepository;

  /// 키 이름 > 그 키의 최신 이력 (이력 없는 키는 없음). 같은 시각 중복은 먼저 온 것만
  public Map<String, SystemConfigHistory> latestByKey() {
    Map<String, SystemConfigHistory> latest = new LinkedHashMap<>();
    for (SystemConfigHistory history : historyRepository.findLatestPerKey()) {
      latest.putIfAbsent(history.getConfigKey(), history);
    }
    return latest;
  }

  public Optional<SystemConfigHistory> latestOf(String configKey) {
    return historyRepository.findByConfigKeyOrderByCreatedAtDesc(configKey, PageRequest.of(0, 1))
      .stream().findFirst();
  }

  public List<SystemConfigHistory> recentOf(String configKey) {
    return historyRepository.findByConfigKeyOrderByCreatedAtDesc(configKey, PageRequest.of(0, KEY_HISTORY_LIMIT));
  }

  /// 조건 검색 (정렬은 pageable 의 sort)
  public Page<SystemConfigHistory> search(SystemConfigHistoryCondition condition, Pageable pageable) {
    return historyRepository.findAll(toSpecification(condition), pageable);
  }

  /// 이력 화면 정렬 허용 필드 (엔티티 필드명)
  public static Sort sortOf(String field, boolean isAscending) {
    Sort.Direction direction = isAscending ? Sort.Direction.ASC : Sort.Direction.DESC;
    // 같은 값이면 최신이 위로
    Sort primary = Sort.by(direction, field);
    return CREATED_AT_FIELD.equals(field) ? primary : primary.and(Sort.by(Sort.Direction.DESC, CREATED_AT_FIELD));
  }

  private Specification<SystemConfigHistory> toSpecification(SystemConfigHistoryCondition condition) {
    return (root, query, builder) -> {
      List<Predicate> predicates = new ArrayList<>();
      if (condition.configKey() != null) {
        predicates.add(builder.equal(root.get("configKey"), condition.configKey()));
      }
      if (condition.changedBy() != null) {
        predicates.add(builder.equal(root.get("changedBy"), condition.changedBy()));
      }
      if (condition.from() != null) {
        predicates.add(builder.greaterThanOrEqualTo(root.get("createdAt"), condition.from()));
      }
      if (condition.toExclusive() != null) {
        predicates.add(builder.lessThan(root.get("createdAt"), condition.toExclusive()));
      }
      if (condition.likePattern() != null) {
        // 검색어: 키, 이전값, 새 값, 변경자, 사유 중 하나
        String pattern = condition.likePattern().toLowerCase();
        predicates.add(builder.or(
          builder.like(builder.lower(root.get("configKey")), pattern, LIKE_ESCAPE),
          builder.like(builder.lower(builder.coalesce(root.<String>get("oldValue"), "")), pattern, LIKE_ESCAPE),
          builder.like(builder.lower(builder.coalesce(root.<String>get("newValue"), "")), pattern, LIKE_ESCAPE),
          builder.like(builder.lower(builder.coalesce(root.<String>get("changedBy"), "")), pattern, LIKE_ESCAPE),
          builder.like(builder.lower(builder.coalesce(root.<String>get("reason"), "")), pattern, LIKE_ESCAPE)));
      }
      return builder.and(predicates.toArray(new Predicate[0]));
    };
  }
}
