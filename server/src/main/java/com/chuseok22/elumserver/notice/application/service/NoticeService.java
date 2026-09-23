package com.chuseok22.elumserver.notice.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.notice.application.dto.request.NoticeInput;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticeResponse;
import com.chuseok22.elumserver.notice.application.dto.response.AppNoticesResponse;
import com.chuseok22.elumserver.notice.core.NoticeEmphasis;
import com.chuseok22.elumserver.notice.core.NoticeImageType;
import com.chuseok22.elumserver.notice.core.NoticePlatform;
import com.chuseok22.elumserver.notice.core.NoticeStatus;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import com.chuseok22.elumserver.notice.infrastructure.repository.AppNoticeRepository;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage;
import com.chuseok22.elumserver.notice.infrastructure.storage.NoticeImageStorage.ImageContent;
import com.chuseok22.elumserver.systemconfig.application.service.SystemConfigService;
import com.chuseok22.elumserver.systemconfig.core.ConfigKey;
import java.io.IOException;
import java.net.URI;
import java.net.URISyntaxException;
import java.time.Clock;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;
import java.util.Comparator;
import java.util.List;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

/**
 * 보호자 홈 공지 팝업 (이슈 #370).
 *
 * <p>게시 판단(켜짐·기간·플랫폼·순서)과 저장 검증을 전부 여기서 한다. 관리자 목록 배지와
 * 앱 API 가 같은 판단을 써야 둘이 어긋나지 않는다.
 */
@Slf4j
@Service
@Transactional(readOnly = true)
public class NoticeService {

  /** 관리자가 한국 시각으로 적는다. 서버 JVM 시간대와 무관하게 이 시간대로 판단한다. */
  public static final ZoneId ZONE = ZoneId.of("Asia/Seoul");

  /** 한 팝업에 넣는 최대 장수 (N24). 넘기면 보호자가 슬라이드를 끝까지 넘기지 않는다. */
  public static final int MAX_SLIDES = 5;

  /** 이미지 한도. 앱이 홈에 들어올 때 받으므로 크면 팝업이 늦게 뜬다. */
  public static final long IMAGE_MAX_BYTES = 2L * 1024 * 1024;

  private static final int HIDE_DAYS_MIN = 1;
  private static final int HIDE_DAYS_MAX = 30;
  private static final String HTTPS_PREFIX = "https://";

  /** 슬라이드 순서 — 우선순위가 큰 것 먼저, 같으면 시작이 늦은 것 먼저. 마지막은 순서를 고정하려는 것이다. */
  static final Comparator<AppNotice> SLIDE_ORDER = Comparator
    .comparingInt(AppNotice::getPriority).reversed()
    .thenComparing(AppNotice::getStartsAt, Comparator.reverseOrder())
    .thenComparing(AppNotice::getId, Comparator.nullsLast(Comparator.naturalOrder()));

  private final AppNoticeRepository appNoticeRepository;
  private final SystemConfigService systemConfigService;
  private final NoticeImageStorage noticeImageStorage;
  private final Clock clock;

  @Autowired
  public NoticeService(
    AppNoticeRepository appNoticeRepository,
    SystemConfigService systemConfigService,
    NoticeImageStorage noticeImageStorage
  ) {
    this(appNoticeRepository, systemConfigService, noticeImageStorage, Clock.system(ZONE));
  }

  /** 테스트가 시계를 고정할 수 있게 둔다. */
  NoticeService(
    AppNoticeRepository appNoticeRepository,
    SystemConfigService systemConfigService,
    NoticeImageStorage noticeImageStorage,
    Clock clock
  ) {
    this.appNoticeRepository = appNoticeRepository;
    this.systemConfigService = systemConfigService;
    this.noticeImageStorage = noticeImageStorage;
    this.clock = clock;
  }

  // ── 앱 ──────────────────────────────────────────────

  /** 서버 시계의 한국 시각. 시계가 어느 시간대로 만들어졌든 한국 시각으로 바꾼다. */
  public LocalDateTime now() {
    return LocalDateTime.ofInstant(clock.instant(), ZONE);
  }

  /**
   * 앱에 줄 공지. 게시 중이고 이 플랫폼에 닿는 것을 순서대로 최대 5개.
   *
   * <p>숨김은 기기에 있으므로 서버는 거르지 않는다 — 앱이 숨긴 것을 빼고 남은 것을 보여준다.
   */
  public AppNoticesResponse publishedFor(String platform) {
    NoticePlatform requested = NoticePlatform.parse(platform);
    List<AppNoticeResponse> notices = liveInSlideOrder().stream()
      .filter(notice -> notice.getPlatform().reaches(requested))
      .limit(MAX_SLIDES)
      .map(AppNoticeResponse::from)
      .toList();
    return new AppNoticesResponse(hideDays(), notices);
  }

  /**
   * 지금 게시 중인 공지 전부(플랫폼 무관)를 슬라이드 순서로. 관리자 "전체 미리보기"가 이것을 받아
   * 플랫폼별로 걸러 보여준다 — 앱 API 와 같은 판단·같은 순서를 써야 미리보기가 앱과 같다.
   */
  public List<AppNotice> liveInSlideOrder() {
    LocalDateTime now = now();
    return appNoticeRepository.findAll().stream()
      .filter(notice -> notice.statusAt(now).isLive())
      .sorted(SLIDE_ORDER)
      .toList();
  }

  /**
   * 보지 않기 일수. 관리자 화면은 1~30 만 받지만 DB 를 손으로 고치면 벗어날 수 있다 —
   * 0 이면 숨겨도 바로 다시 뜨고, 너무 크면 사실상 영영 안 뜬다. 가까운 끝으로 맞춘다.
   */
  public int hideDays() {
    int configured = systemConfigService.getInt(ConfigKey.NOTICE_HIDE_DAYS);
    return Math.clamp(configured, HIDE_DAYS_MIN, HIDE_DAYS_MAX);
  }

  /**
   * 앱에 내보낼 이미지. <b>게시 중이 아니면 404</b> — 끝난 공지의 이미지를 주소만 알면 계속
   * 받아 갈 수 있으면 안 된다. 없는 공지와 게시 전 공지를 같은 404 로 돌려 존재를 흘리지 않는다.
   */
  public ImageContent liveImage(String id) {
    AppNotice notice = appNoticeRepository.findById(id)
      .filter(found -> found.statusAt(now()).isLive())
      .filter(found -> found.getImageKey() != null)
      .orElseThrow(() -> new CustomException(ErrorCode.NOTICE_IMAGE_NOT_FOUND));
    return noticeImageStorage.read(notice.getImageKey());
  }

  // ── 관리자 ──────────────────────────────────────────

  /** 목록 순서 — 게시 중, 예약, 꺼짐, 끝남 순. 같은 상태 안에서는 앱 슬라이드 순서다. */
  public List<AppNotice> getAll() {
    LocalDateTime now = now();
    return appNoticeRepository.findAll().stream()
      .sorted(Comparator.<AppNotice>comparingInt(notice -> listRank(notice.statusAt(now)))
        .thenComparing(SLIDE_ORDER))
      .toList();
  }

  public NoticeStatus statusOf(AppNotice notice) {
    return notice.statusAt(now());
  }

  public AppNotice get(String id) {
    return appNoticeRepository.findById(id)
      .orElseThrow(() -> new CustomException(ErrorCode.NOTICE_NOT_FOUND));
  }

  /** 관리자 편집 화면 미리보기. 게시 전 공지의 이미지도 본다. */
  public ImageContent adminImage(String id) {
    AppNotice notice = get(id);
    if (notice.getImageKey() == null) {
      throw new CustomException(ErrorCode.NOTICE_IMAGE_NOT_FOUND);
    }
    return noticeImageStorage.read(notice.getImageKey());
  }

  /**
   * 새로 만든다. <b>모든 칸과 이미지를 먼저 검사하고</b> 그다음에 쓴다 — 이미지가 걸렸는데
   * 글만 저장되는 반쪽 공지가 생기지 않게.
   */
  @Transactional
  public AppNotice create(NoticeInput input, MultipartFile image, String adminId) {
    Draft draft = validate(input);
    PreparedImage prepared = prepareImage(image);

    AppNotice notice = new AppNotice();
    draft.applyTo(notice);
    notice.setRevision(1);
    notice.setCreatedBy(actor(adminId));
    notice.setUpdatedBy(actor(adminId));
    // UUID 는 저장할 때 붙는다. 이미지 열쇠가 공지 아이디로 시작하므로 먼저 저장한다.
    AppNotice saved = appNoticeRepository.save(notice);
    if (prepared != null) {
      saved.setImageKey(storeImage(saved.getId(), prepared));
    }
    return saved;
  }

  /**
   * 고친다.
   *
   * @param bumpRevision "다시 보이게" — 켜면 판이 올라 숨긴 사람에게도 다시 뜬다
   * @param removeImage  새 그림 없이 켜면 그림을 지운다. 새 그림이 있으면 새 그림이 이긴다
   */
  @Transactional
  public AppNotice update(
    String id, NoticeInput input, boolean bumpRevision, MultipartFile image, boolean removeImage,
    String adminId
  ) {
    AppNotice notice = get(id);
    Draft draft = validate(input);
    PreparedImage prepared = prepareImage(image);

    draft.applyTo(notice);
    if (bumpRevision) {
      notice.setRevision(notice.getRevision() + 1);
    }
    notice.setUpdatedBy(actor(adminId));

    String oldKey = notice.getImageKey();
    if (prepared != null) {
      notice.setImageKey(storeImage(notice.getId(), prepared));
      deleteImageAfterCommit(oldKey);
    } else if (removeImage && oldKey != null) {
      notice.setImageKey(null);
      deleteImageAfterCommit(oldKey);
    }
    return appNoticeRepository.save(notice);
  }

  @Transactional
  public AppNotice setEnabled(String id, boolean enabled, String adminId) {
    AppNotice notice = get(id);
    notice.setEnabled(enabled);
    notice.setUpdatedBy(actor(adminId));
    return appNoticeRepository.save(notice);
  }

  /** 지운다. 이미지 파일도 함께 지운다 (N17). */
  @Transactional
  public void delete(String id) {
    AppNotice notice = get(id);
    String imageKey = notice.getImageKey();
    appNoticeRepository.delete(notice);
    deleteImageAfterCommit(imageKey);
  }

  // ── 검증 ────────────────────────────────────────────

  /** 검증을 통과한, 다듬은 값. 이것만 엔티티에 들어간다. */
  private record Draft(
    String title, String body, String buttonLabel, String buttonUrl, NoticePlatform platform,
    int priority, LocalDateTime startsAt, LocalDateTime endsAt, boolean enabled
  ) {

    void applyTo(AppNotice notice) {
      notice.setTitle(title);
      notice.setBody(body);
      notice.setButtonLabel(buttonLabel);
      notice.setButtonUrl(buttonUrl);
      notice.setPlatform(platform);
      notice.setPriority(priority);
      notice.setStartsAt(startsAt);
      notice.setEndsAt(endsAt);
      notice.setEnabled(enabled);
    }
  }

  private Draft validate(NoticeInput input) {
    // 제목은 한 줄 칸이지만 요청을 직접 보내면 줄바꿈이 들어올 수 있다. 앱 제목 줄이 깨지지 않게 편다.
    String title = trim(input.title()).replaceAll("[\\r\\n]+", " ");
    // 공백만, 표기만(****) 있는 제목은 저장하면 앱에 빈 제목이 뜬다. 브라우저 required 는 공백을 통과시킨다.
    if (NoticeEmphasis.visibleText(title).isBlank()) {
      throw new CustomException(ErrorCode.NOTICE_TITLE_BLANK);
    }
    if (title.length() > AppNotice.TITLE_MAX_LENGTH) {
      throw new CustomException(ErrorCode.NOTICE_TITLE_TOO_LONG);
    }
    if (!NoticeEmphasis.isPaired(title)) {
      throw new CustomException(ErrorCode.NOTICE_TITLE_EMPHASIS_UNPAIRED);
    }

    // 브라우저 textarea 는 줄바꿈을 CRLF 로 보낸다. LF 로 맞춰야 앱에 CR 이 섞이지 않고,
    // 글자 수도 줄마다 1자씩 부풀지 않는다.
    String body = trim(input.body() == null ? null : input.body().replace("\r\n", "\n"));
    if (body.isEmpty()) {
      throw new CustomException(ErrorCode.NOTICE_BODY_BLANK);
    }
    if (body.length() > AppNotice.BODY_MAX_LENGTH) {
      throw new CustomException(ErrorCode.NOTICE_BODY_TOO_LONG);
    }

    String buttonLabel = trim(input.buttonLabel());
    String buttonUrl = trim(input.buttonUrl());
    if (buttonLabel.isEmpty() != buttonUrl.isEmpty()) {
      throw new CustomException(ErrorCode.NOTICE_BUTTON_INCOMPLETE);
    }
    if (buttonLabel.length() > AppNotice.BUTTON_LABEL_MAX_LENGTH) {
      throw new CustomException(ErrorCode.NOTICE_BUTTON_LABEL_TOO_LONG);
    }
    if (!buttonUrl.isEmpty() && !isHttpsUrl(buttonUrl)) {
      throw new CustomException(ErrorCode.NOTICE_BUTTON_URL_INVALID);
    }

    NoticePlatform platform = NoticePlatform.parse(input.platform());
    int priority = parsePriority(input.priority());
    LocalDateTime startsAt = parseDateTime(input.startsAt());
    if (startsAt == null) {
      throw new CustomException(ErrorCode.NOTICE_PERIOD_INVALID);
    }
    LocalDateTime endsAt = parseDateTime(input.endsAt());
    if (endsAt != null && !startsAt.isBefore(endsAt)) {
      throw new CustomException(ErrorCode.NOTICE_PERIOD_INVALID);
    }

    return new Draft(title, body, emptyToNull(buttonLabel), emptyToNull(buttonUrl), platform,
      priority, startsAt, endsAt, input.enabled());
  }

  /**
   * {@code https://} 로 시작하고 호스트가 있는 주소만. 앱은 이 링크를 외부 브라우저로 여는데,
   * {@code http} 나 {@code javascript:} 가 섞이면 보호자를 엉뚱한 곳으로 보낼 수 있다.
   * 앱도 같은 접두어로 한 번 더 거른다 — 대문자 {@code HTTPS://} 를 받으면 앱 쪽 검사와 어긋난다.
   */
  private boolean isHttpsUrl(String url) {
    if (!url.startsWith(HTTPS_PREFIX) || url.length() > AppNotice.BUTTON_URL_MAX_LENGTH
      || url.chars().anyMatch(Character::isWhitespace)) {
      return false;
    }
    try {
      String host = new URI(url).getHost();
      return host != null && !host.isBlank();
    } catch (URISyntaxException e) {
      return false;
    }
  }

  private int parsePriority(String raw) {
    String value = trim(raw);
    if (value.isEmpty()) {
      return 0;
    }
    try {
      return Integer.parseInt(value);
    } catch (NumberFormatException e) {
      throw new CustomException(ErrorCode.NOTICE_PRIORITY_INVALID);
    }
  }

  /** 비었으면 null. 읽을 수 없으면 거부한다 — 틀린 종료일을 "끝없음"으로 바꾸면 공지가 영영 남는다. */
  private LocalDateTime parseDateTime(String raw) {
    String value = trim(raw);
    if (value.isEmpty()) {
      return null;
    }
    try {
      return LocalDateTime.parse(value);
    } catch (DateTimeParseException e) {
      throw new CustomException(ErrorCode.NOTICE_PERIOD_INVALID);
    }
  }

  // ── 이미지 ──────────────────────────────────────────

  private record PreparedImage(byte[] bytes, NoticeImageType type) {

  }

  /**
   * 올린 파일을 검사한다. 쓰기 전에 부른다. 파일 칸을 비워 보내면(빈 파일) 이미지가 없는 것이다.
   *
   * <p>크기는 <b>바이트를 읽기 전에</b> 본다. 서버 전체 업로드 한도는 200MB 라 큰 파일을 통째로
   * 메모리에 올린 뒤 거절하면 그 사이 서버가 버거워진다.
   */
  private PreparedImage prepareImage(MultipartFile image) {
    if (image == null || image.isEmpty()) {
      return null;
    }
    if (image.getSize() > IMAGE_MAX_BYTES) {
      throw new CustomException(ErrorCode.NOTICE_IMAGE_TOO_LARGE);
    }
    byte[] bytes;
    try {
      bytes = image.getBytes();
    } catch (IOException e) {
      log.warn("공지 이미지 읽기 실패: name={}", image.getOriginalFilename(), e);
      throw new CustomException(ErrorCode.NOTICE_IMAGE_INVALID_TYPE);
    }
    NoticeImageType type = NoticeImageType.detect(bytes)
      .orElseThrow(() -> new CustomException(ErrorCode.NOTICE_IMAGE_INVALID_TYPE));
    return new PreparedImage(bytes, type);
  }

  /**
   * 새 그림을 쓴다. 트랜잭션이 되돌려지면 방금 쓴 파일을 지운다 — 아무도 가리키지 않는 파일이
   * 쌓이지 않게.
   */
  private String storeImage(String noticeId, PreparedImage prepared) {
    String key = noticeImageStorage.save(noticeId, prepared.bytes(), prepared.type());
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
        @Override
        public void afterCompletion(int status) {
          if (status == STATUS_ROLLED_BACK) {
            noticeImageStorage.delete(key);
          }
        }
      });
    }
    return key;
  }

  /**
   * 옛 그림은 <b>커밋된 뒤에</b> 지운다. 먼저 지웠는데 트랜잭션이 되돌려지면 DB 는 옛 열쇠를
   * 가리키는데 파일이 없어 그림이 깨진다. 트랜잭션 밖(단위 테스트)에서는 바로 지운다.
   */
  private void deleteImageAfterCommit(String key) {
    if (key == null) {
      return;
    }
    if (TransactionSynchronizationManager.isSynchronizationActive()) {
      TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
        @Override
        public void afterCommit() {
          noticeImageStorage.delete(key);
        }
      });
      return;
    }
    noticeImageStorage.delete(key);
  }

  // ── 도움 ────────────────────────────────────────────

  private static int listRank(NoticeStatus status) {
    return switch (status) {
      case LIVE -> 0;
      case SCHEDULED -> 1;
      case DISABLED -> 2;
      case ENDED -> 3;
    };
  }

  private static String trim(String value) {
    return value == null ? "" : value.strip();
  }

  private static String emptyToNull(String value) {
    return value.isEmpty() ? null : value;
  }

  private static String actor(String adminId) {
    return adminId == null || adminId.isBlank() ? "알 수 없음" : adminId;
  }
}
