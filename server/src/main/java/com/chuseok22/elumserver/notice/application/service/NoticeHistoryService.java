package com.chuseok22.elumserver.notice.application.service;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.common.locale.CurrentLocale;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryItemResponse;
import com.chuseok22.elumserver.notice.application.dto.response.NoticeHistoryPageResponse;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notification.infrastructure.entity.NoticeSeen;
import com.chuseok22.elumserver.notification.infrastructure.repository.NoticeSeenRepository;
import java.time.Clock;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 공지 탭: 지난 공지 목록, 공지 읽음 기록, 안 읽은 공지 여부
 * 목록 조건 6개(켜짐, 시작됨, 최근 90일, 언어, 플랫폼, 종료된 것 포함) > 올라온 시각 최신순
 */
@Service
@Transactional(readOnly = true)
public class NoticeHistoryService {

  /** 공지 탭에 남겨 두는 기간 (일) */
  static final int HISTORY_DAYS = 90;
  static final int DEFAULT_PAGE_SIZE = 20;
  static final int MAX_PAGE_SIZE = 50;

  /** 올라온 시각 최신순, 같으면 id 큰 순 (cursor 가 id 라 순서를 고정) */
  private static final Comparator<AppNotice> HISTORY_ORDER = Comparator
    .comparing(AppNotice::visibleSince, Comparator.reverseOrder())
    .thenComparing(AppNotice::getId, Comparator.reverseOrder());

  private final AppNoticeRepository appNoticeRepository;
  private final NoticeSeenRepository noticeSeenRepository;
  private final Clock clock;

  @Autowired
  public NoticeHistoryService(AppNoticeRepository appNoticeRepository, NoticeSeenRepository noticeSeenRepository) {
    this(appNoticeRepository, noticeSeenRepository, Clock.system(NoticeService.ZONE));
  }

  /** 테스트가 시계를 고정할 수 있게 둔다. */
  NoticeHistoryService(
    AppNoticeRepository appNoticeRepository, NoticeSeenRepository noticeSeenRepository, Clock clock
  ) {
    this.appNoticeRepository = appNoticeRepository;
    this.noticeSeenRepository = noticeSeenRepository;
    this.clock = clock;
  }

  /**
   * 공지 탭 한 쪽: 조건 확인 > 최신순 정렬 > cursor 뒤에서 size 개
   * cursor 공지가 목록에서 사라졌으면 빈 쪽
   */
  public NoticeHistoryPageResponse history(String platform, String cursor, Integer size) {
    int pageSize = size == null || size < 1 ? DEFAULT_PAGE_SIZE : Math.min(size, MAX_PAGE_SIZE);
    List<AppNotice> sorted = historyNotices(NoticePlatform.parse(platform), CurrentLocale.get());

    int startIndex = 0;
    if (cursor != null && !cursor.isBlank()) {
      int cursorIndex = indexOfId(sorted, cursor);
      if (cursorIndex < 0) {
        return new NoticeHistoryPageResponse(List.of(), null);
      }
      startIndex = cursorIndex + 1;
    }

    int endIndex = Math.min(startIndex + pageSize, sorted.size());
    List<AppNotice> page = sorted.subList(startIndex, endIndex);
    boolean hasNext = endIndex < sorted.size();
    String nextCursor = hasNext ? page.get(page.size() - 1).getId() : null;
    return new NoticeHistoryPageResponse(page.stream().map(NoticeHistoryItemResponse::from).toList(), nextCursor);
  }

  /** 공지 탭을 봤다고 기록: 읽은 시각 = 지금 (없으면 만들고 있으면 갱신) */
  @Transactional
  public void markSeen(String memberId) {
    NoticeSeen seen = noticeSeenRepository.findById(memberId).orElseGet(() -> {
      NoticeSeen created = new NoticeSeen();
      created.setMemberId(memberId);
      return created;
    });
    seen.setSeenAt(now());
    noticeSeenRepository.save(seen);
  }

  /** 마지막으로 본 뒤에 올라오거나 고친 공지가 있는가 (본 기록이 없으면 공지가 하나라도 있으면 true) */
  public boolean hasUnseenNotice(String memberId, String platform) {
    List<AppNotice> notices = historyNotices(NoticePlatform.parse(platform), CurrentLocale.get());
    LocalDateTime seenAt = noticeSeenRepository.findById(memberId).map(NoticeSeen::getSeenAt).orElse(null);
    return notices.stream().anyMatch(notice -> seenAt == null || notice.visibleSince().isAfter(seenAt));
  }

  // 공지는 관리자가 올리는 몇십 건이라 NoticeService 처럼 전부 읽어 자바에서 거른다
  private List<AppNotice> historyNotices(NoticePlatform requested, AppLocale requestedLocale) {
    LocalDateTime now = now();
    LocalDateTime oldestVisibleSince = now.minusDays(HISTORY_DAYS);
    return appNoticeRepository.findAll().stream()
      .filter(AppNotice::isEnabled)
      .filter(notice -> !notice.getStartsAt().isAfter(now))
      .filter(notice -> !notice.visibleSince().isBefore(oldestVisibleSince))
      .filter(notice -> notice.getLocale() == requestedLocale)
      .filter(notice -> notice.getPlatform().reaches(requested))
      .sorted(HISTORY_ORDER)
      .toList();
  }

  private static int indexOfId(List<AppNotice> notices, String id) {
    for (int index = 0; index < notices.size(); index++) {
      if (id.equals(notices.get(index).getId())) {
        return index;
      }
    }
    return -1;
  }

  private LocalDateTime now() {
    return LocalDateTime.ofInstant(clock.instant(), NoticeService.ZONE);
  }
}
