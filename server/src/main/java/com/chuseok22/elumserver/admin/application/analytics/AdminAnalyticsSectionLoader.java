package com.chuseok22.elumserver.admin.application.analytics;

import com.chuseok22.elumserver.admin.application.stats.AdminStatsCache;
import java.util.function.LongSupplier;
import java.util.function.Supplier;
import lombok.extern.slf4j.Slf4j;

/**
 * 사용 분석 칸 불러오기: 60초 캐시(AdminStatsCache) > 실패하면 그 칸만 에러 코드 + 로그 (나머지 칸은 그대로)
 */
@Slf4j
public class AdminAnalyticsSectionLoader {

  private final AdminStatsCache<Object> cache;

  public AdminAnalyticsSectionLoader(LongSupplier currentMilliseconds) {
    this.cache = new AdminStatsCache<>(currentMilliseconds);
  }

  /** 캐시 키(칸 이름|cacheKey)로 60초 재사용 */
  @SuppressWarnings("unchecked")
  public <T> AdminAnalyticsSection<T> loadCached(AdminAnalyticsSectionName section, String cacheKey, Supplier<T> loader) {
    return load(section, () -> (T) cache.getOrLoad(section.name() + "|" + cacheKey, loader::get));
  }

  /** 매번 새로 (관리자 버튼으로 바로 바뀌는 칸: 분류 제안) */
  public <T> AdminAnalyticsSection<T> load(AdminAnalyticsSectionName section, Supplier<T> loader) {
    try {
      return AdminAnalyticsSection.loaded(loader.get());
    } catch (RuntimeException e) {
      log.warn("[admin analytics] section failed : section={}, errorCode={}", section, section.errorCode(), e);
      return AdminAnalyticsSection.failed(section.errorCode());
    }
  }
}
