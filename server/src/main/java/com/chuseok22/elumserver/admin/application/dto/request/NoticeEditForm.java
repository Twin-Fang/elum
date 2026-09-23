package com.chuseok22.elumserver.admin.application.dto.request;

import com.chuseok22.elumserver.notice.application.dto.request.NoticeInput;
import com.chuseok22.elumserver.notice.infrastructure.entity.AppNotice;
import java.time.LocalDateTime;
import java.time.format.DateTimeFormatter;

/**
 * 공지 편집 화면의 입력값 (이슈 #370).
 *
 * <p>검증에 걸렸을 때 <b>관리자가 입력한 값을 그대로 다시 그리기</b> 위해 둔다(약관 편집과 같은
 * 이유 — 리다이렉트하면 DB 값을 다시 읽어 쓰던 본문이 사라진다). 그래서 숫자·날짜도 문자열이다.
 * 체크박스는 체크하지 않으면 값이 오지 않아 {@code null} 이 된다.
 *
 * @param bumpRevision "다시 보이게" — 켜고 저장하면 숨긴 사람에게도 다시 뜬다
 * @param removeImage  지금 이미지를 지운다
 */
public record NoticeEditForm(
  String title,
  String body,
  String buttonLabel,
  String buttonUrl,
  String platform,
  String priority,
  String startsAt,
  String endsAt,
  Boolean enabled,
  Boolean bumpRevision,
  Boolean removeImage
) {

  /** 브라우저 datetime-local 칸이 받는 모양. 초까지 넣으면 칸이 초 단위 입력으로 바뀐다. */
  private static final DateTimeFormatter INPUT_FORMAT = DateTimeFormatter.ofPattern("yyyy-MM-dd'T'HH:mm");

  /**
   * 새 공지. <b>꺼진 채로</b> 지금 시각에 시작한다 — 저장 버튼 한 번에 운영 보호자 전원에게
   * 나가지 않게, 미리보기로 확인하고 켜게 한다.
   */
  public static NoticeEditForm blank(LocalDateTime now) {
    return new NoticeEditForm("", "", "", "", "ALL", "0", now.format(INPUT_FORMAT), "",
      false, false, false);
  }

  public static NoticeEditForm of(AppNotice notice) {
    return new NoticeEditForm(
      notice.getTitle(),
      notice.getBody(),
      nullToEmpty(notice.getButtonLabel()),
      nullToEmpty(notice.getButtonUrl()),
      notice.getPlatform().name(),
      String.valueOf(notice.getPriority()),
      notice.getStartsAt().format(INPUT_FORMAT),
      notice.getEndsAt() == null ? "" : notice.getEndsAt().format(INPUT_FORMAT),
      notice.isEnabled(),
      false,
      false
    );
  }

  public boolean isEnabled() {
    return Boolean.TRUE.equals(enabled);
  }

  public boolean isBumpRevision() {
    return Boolean.TRUE.equals(bumpRevision);
  }

  public boolean isRemoveImage() {
    return Boolean.TRUE.equals(removeImage);
  }

  public NoticeInput toInput() {
    return new NoticeInput(title, body, buttonLabel, buttonUrl, platform, priority, startsAt, endsAt,
      isEnabled());
  }

  private static String nullToEmpty(String value) {
    return value == null ? "" : value;
  }
}
