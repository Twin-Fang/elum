package com.chuseok22.elumserver.notice.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryItemResponse;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryPageResponse;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notification.application.service.NoticeSeenService;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.Comparator;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 공지 탭: 지난 공지 목록, 공지 읽음 기록, 안 읽은 공지 여부
 * 목록 조건 7개(켜짐, 시작됨, 최근 90일, 언어, 플랫폼, 대상 국가, 종료된 것 포함) > 올라온 시각 최신순
 */
@Service
@Transactional(readOnly = true)
public class NoticeHistoryService {

  /** 공지 탭에 남겨 두는 기간 (일) */
  static final int HISTORY_DAYS = 90;
  static final int DEFAULT_PAGE_SIZE = 20;
  static final int MAX_PAGE_SIZE = 50;

  /** cursor 구분자: "{visibleSince ISO-8601}|{id}" */
  private static final String CURSOR_DELIMITER = "|";

  /** 올라온 시각 최신순, 같으면 id 큰 순 (cursor 가 visibleSince|id 라 순서를 고정) */
  private static final Comparator<AppNotice> HISTORY_ORDER = Comparator
    .comparing(AppNotice::visibleSince, Comparator.reverseOrder())
    .thenComparing(AppNotice::getId, Comparator.reverseOrder());

  private final AppNoticeRepository appNoticeRepository;
  private final NoticeSeenService noticeSeenService;
  private final Clock clock;

  @Autowired
  public NoticeHistoryService(AppNoticeRepository appNoticeRepository, NoticeSeenService noticeSeenService) {
    this(appNoticeRepository, noticeSeenService, Clock.system(NoticeService.ZONE));
  }

  /** 테스트가 시계를 고정할 수 있게 둔다. */
  NoticeHistoryService(
    AppNoticeRepository appNoticeRepository, NoticeSeenService noticeSeenService, Clock clock
  ) {
    this.appNoticeRepository = appNoticeRepository;
    this.noticeSeenService = noticeSeenService;
    this.clock = clock;
  }

  /**
   * 공지 탭 한 쪽: 조건 확인 > 최신순 정렬 > cursor 위치 뒤에서 size 개
   * cursor 는 (올라온 시각, id) 위치라 그 공지가 사라져도 이어서 준다. 형식이 틀리면 cursor 없음으로 본다
   * region: 요청 국가 (CurrentRegion.get(), 국가 미상이면 null)
   */
  public NoticeHistoryPageResponse history(String platform, String cursor, Integer size, String region) {
    int pageSize = size == null ? DEFAULT_PAGE_SIZE : Math.clamp(size, 1, MAX_PAGE_SIZE);
    List<AppNotice> sorted = historyNotices(NoticePlatform.parse(platform), CurrentLocale.get(), region);

    CursorPosition position = parseCursor(cursor);
    List<AppNotice> remaining = position == null
      ? sorted
      : sorted.stream().filter(notice -> isAfter(notice, position)).toList();

    List<AppNotice> page = remaining.stream().limit(pageSize).toList();
    boolean hasNext = remaining.size() > page.size();
    String nextCursor = hasNext ? toCursor(page.get(page.size() - 1)) : null;
    return new NoticeHistoryPageResponse(page.stream().map(NoticeHistoryItemResponse::from).toList(), nextCursor);
  }

  /** 공지 탭을 봤다고 기록: 읽은 시각 = 지금 */
  @Transactional
  public void markSeen(String memberId) {
    noticeSeenService.markSeen(memberId, now());
  }

  /**
   * 마지막으로 본 뒤에 올라오거나 고친 공지가 있는가 (본 기록이 없으면 공지가 하나라도 있으면 true)
   * 언어·국가는 호출부가 요청 스레드에서 CurrentLocale·CurrentRegion 으로 정해 넘김 (비동기 스레드에서 부르면 KO·KR 로 흐름)
   */
  public boolean hasUnseenNotice(String memberId, String platform, AppLocale locale, String region) {
    List<AppNotice> notices = historyNotices(NoticePlatform.parse(platform), locale, region);
    LocalDateTime seenAt = noticeSeenService.findSeenAt(memberId).orElse(null);
    return notices.stream().anyMatch(notice -> seenAt == null || notice.visibleSince().isAfter(seenAt));
  }

  private record CursorPosition(LocalDateTime visibleSince, String id) {

  }

  /** "visibleSince|id" > 위치. 비었거나 형식이 틀리면 null */
  private static CursorPosition parseCursor(String cursor) {
    if (cursor == null || cursor.isBlank()) {
      return null;
    }
    int delimiterIndex = cursor.indexOf(CURSOR_DELIMITER);
    if (delimiterIndex <= 0 || delimiterIndex == cursor.length() - 1) {
      return null;
    }
    try {
      return new CursorPosition(
        LocalDateTime.parse(cursor.substring(0, delimiterIndex)), cursor.substring(delimiterIndex + 1));
    } catch (DateTimeParseException e) {
      return null;
    }
  }

  private static String toCursor(AppNotice notice) {
    return notice.visibleSince() + CURSOR_DELIMITER + notice.getId();
  }

  /** 정렬(visibleSince 내림, id 내림)에서 cursor 위치보다 뒤인가 */
  private static boolean isAfter(AppNotice notice, CursorPosition position) {
    int bySince = notice.visibleSince().compareTo(position.visibleSince());
    return bySince < 0 || (bySince == 0 && notice.getId().compareTo(position.id()) < 0);
  }

  // 공지 표는 관리자가 손으로 올리는 수십 건 규모라 NoticeService 처럼 전부 읽어 자바에서 거른다 (수천 건이 되면 쿼리로 옮김)
  private List<AppNotice> historyNotices(NoticePlatform requested, AppLocale requestedLocale, String region) {
    LocalDateTime now = now();
    LocalDateTime oldestVisibleSince = now.minusDays(HISTORY_DAYS);
    return appNoticeRepository.findAll().stream()
      .filter(AppNotice::isEnabled)
      .filter(notice -> !notice.getStartsAt().isAfter(now))
      .filter(notice -> !notice.visibleSince().isBefore(oldestVisibleSince))
      .filter(notice -> notice.getLocale() == requestedLocale)
      .filter(notice -> notice.getPlatform().reaches(requested))
      .filter(notice -> notice.isVisibleInRegion(region))
      .sorted(HISTORY_ORDER)
      .toList();
  }

  private LocalDateTime now() {
    return LocalDateTime.ofInstant(clock.instant(), NoticeService.ZONE);
  }
}
