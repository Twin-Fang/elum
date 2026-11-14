package com.chuseok22.elumserver.admin.application.service;

import com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleBundleStatus;
import com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleConsentVersion;
import com.chuseok22.elumserver.admin.application.dto.response.AdminLocaleStatusRow;
import com.chuseok22.elumserver.admin.application.dto.response.AdminPushMessageCompareRow;
import com.chuseok22.elumserver.admin.application.dto.response.PromptLocaleView;
import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.ClasspathLocaleBundle;
import com.chuseok22.elumserver.consent.application.service.ConsentDocumentService;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.notice.application.service.NoticeAdminSearch;
import com.chuseok22.elumserver.notice.application.service.NoticeService;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.routine.infrastructure.constant.RoutinePhrases;
import com.chuseok22.elumserver.systemconfig.application.service.EnabledLocales;
import java.util.Arrays;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.function.BiFunction;
import java.util.stream.Collectors;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Pageable;
import org.springframework.stereotype.Service;

/**
 * 관리자 언어 현황: 언어별 문구 파일 3종·프롬프트 행·약관 버전·공지 수·켜짐 여부 모으기, 푸시 문구 나란히 보기
 * 읽기 전용. DB 칸은 조회 실패해도 화면이 뜨도록 칸별로 null 처리
 */
@Slf4j
@Service
public class AdminLocaleStatusService {

  // 클래스패스 문구 파일 (%s 언어 코드): 에러 문구, 일과 문구, 푸시 문구
  static final String ERROR_MESSAGES_RESOURCE = "i18n/messages_%s.properties";
  static final String ROUTINE_PHRASES_RESOURCE = "i18n/routine-phrases_%s.properties";
  static final String PUSH_MESSAGES_RESOURCE = "i18n/push-messages_%s.properties";

  private final AdminPromptService adminPromptService;
  private final ConsentDocumentService consentDocumentService;
  private final NoticeService noticeService;
  private final EnabledLocales enabledLocales;
  private final BiFunction<String, AppLocale, Map<String, String>> bundleLoader;

  @Autowired
  public AdminLocaleStatusService(AdminPromptService adminPromptService,
    ConsentDocumentService consentDocumentService, NoticeService noticeService, EnabledLocales enabledLocales) {
    this(adminPromptService, consentDocumentService, noticeService, enabledLocales, ClasspathLocaleBundle::load);
  }

  // 테스트용: 문구 파일 대신 가짜 맵
  AdminLocaleStatusService(AdminPromptService adminPromptService, ConsentDocumentService consentDocumentService,
    NoticeService noticeService, EnabledLocales enabledLocales,
    BiFunction<String, AppLocale, Map<String, String>> bundleLoader) {
    this.adminPromptService = adminPromptService;
    this.consentDocumentService = consentDocumentService;
    this.noticeService = noticeService;
    this.enabledLocales = enabledLocales;
    this.bundleLoader = bundleLoader;
  }

  /** 언어 5개 > 표 줄 (AppLocale 선언 순서) */
  public List<AdminLocaleStatusRow> getLocaleStatusRows() {
    Set<AppLocale> enabled = enabledLocales.current();
    List<AppNotice> notices = loadAllNotices();
    return Arrays.stream(AppLocale.values())
      .map(locale -> toLocaleStatusRow(locale, enabled.contains(locale), notices))
      .toList();
  }

  /** 푸시 문구: ko 키 이름순 > ko 문구 <-> 고른 언어 문구 */
  public List<AdminPushMessageCompareRow> getPushMessageCompareRows(AppLocale selected) {
    Map<String, String> koTextByKey = bundleLoader.apply(PUSH_MESSAGES_RESOURCE, AppLocale.KO);
    Map<String, String> selectedTextByKey = bundleLoader.apply(PUSH_MESSAGES_RESOURCE, selected);
    return koTextByKey.keySet().stream()
      .sorted()
      .map(key -> new AdminPushMessageCompareRow(key, koTextByKey.get(key), selectedTextByKey.get(key)))
      .toList();
  }

  private AdminLocaleStatusRow toLocaleStatusRow(AppLocale locale, boolean isContentEnabled,
    List<AppNotice> notices) {
    List<AdminLocaleConsentVersion> consentVersions = loadConsentVersions(locale);
    return new AdminLocaleStatusRow(
      locale.code(),
      PromptLocaleView.of(locale, isContentEnabled, 0).label(),
      isContentEnabled,
      compareBundle(ERROR_MESSAGES_RESOURCE, locale),
      routinePhrasesStatus(locale),
      compareBundle(PUSH_MESSAGES_RESOURCE, locale),
      countPromptRows(locale),
      adminPromptService.requiredKeys(locale).size(),
      consentVersions,
      consentVersions == null ? null : isConsentServedInLocale(locale),
      notices == null ? null : countNotices(notices, locale, false),
      notices == null ? null : countNotices(notices, locale, true));
  }

  AdminLocaleBundleStatus compareBundle(String resourcePattern, AppLocale locale) {
    return AdminLocaleBundleStatus.compareWithKo(
      bundleLoader.apply(resourcePattern, AppLocale.KO), bundleLoader.apply(resourcePattern, locale));
  }

  // 빈 키는 서버 판정(RoutinePhrases: ko 키 + 필수 구조 키)을 그대로 씀 > 관리자 언어 켜기 가드와 같은 기준
  private AdminLocaleBundleStatus routinePhrasesStatus(AppLocale locale) {
    AdminLocaleBundleStatus fileStatus = compareBundle(ROUTINE_PHRASES_RESOURCE, locale);
    return new AdminLocaleBundleStatus(fileStatus.keyCount(), RoutinePhrases.standard().missingKeys(locale));
  }

  private Integer countPromptRows(AppLocale locale) {
    try {
      return adminPromptService.requiredKeys(locale).size() - adminPromptService.missingKeys(locale).size();
    } catch (RuntimeException exception) {
      log.warn("[admin locale status] prompt rows unreadable : locale={}", locale.code(), exception);
      return null;
    }
  }

  // 약관 종류별 버전 (ConsentKey 선언 순서, 그 언어 행 없으면 버전 null)
  private List<AdminLocaleConsentVersion> loadConsentVersions(AppLocale locale) {
    try {
      Map<ConsentKey, String> versionByKey = consentDocumentService.getAll(locale).stream()
        .collect(Collectors.toMap(ConsentDocument::getConsentKey, ConsentDocument::getVersion, (first, second) -> first));
      return Arrays.stream(ConsentKey.values())
        .map(key -> new AdminLocaleConsentVersion(key.getLabel(), versionByKey.get(key)))
        .toList();
    } catch (RuntimeException exception) {
      log.warn("[admin locale status] consent documents unreadable : locale={}", locale.code(), exception);
      return null;
    }
  }

  private Boolean isConsentServedInLocale(AppLocale locale) {
    try {
      return consentDocumentService.resolvePublishedLocale(locale) == locale;
    } catch (RuntimeException exception) {
      log.warn("[admin locale status] consent locale unresolved : locale={}", locale.code(), exception);
      return null;
    }
  }

  // 공지는 손으로 올리는 몇십 건 > 한 번 전부 읽어 언어별로 셈
  private List<AppNotice> loadAllNotices() {
    try {
      return noticeService.search(NoticeAdminSearch.none(), Pageable.unpaged()).getContent();
    } catch (RuntimeException exception) {
      log.warn("[admin locale status] notices unreadable", exception);
      return null;
    }
  }

  private int countNotices(List<AppNotice> notices, AppLocale locale, boolean isLiveOnly) {
    return (int) notices.stream()
      .filter(notice -> notice.getLocale() == locale)
      .filter(notice -> !isLiveOnly || noticeService.statusOf(notice).isLive())
      .count();
  }
}
