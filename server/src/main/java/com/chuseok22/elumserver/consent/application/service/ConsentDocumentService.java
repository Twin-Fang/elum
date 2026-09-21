package com.chuseok22.elumserver.consent.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentHistoryRepository;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.format.DateTimeParseException;
import java.util.Comparator;
import java.util.List;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ConsentDocumentService {

  /** DB 컬럼(VARCHAR 255) 한도. 넘기면 저장 순간 500이 난다. */
  public static final int TEXT_FIELD_MAX_LENGTH = 255;

  /** 버전은 날짜 하나다. 문자열 비교가 곧 날짜 비교가 되도록 형식을 고정한다. */
  private static final Pattern VERSION_FORMAT = Pattern.compile("\\d{4}-\\d{2}-\\d{2}");

  private final ConsentDocumentRepository consentDocumentRepository;
  private final ConsentDocumentHistoryRepository consentDocumentHistoryRepository;

  /** 저장이 실제로 무엇을 했는지. 안내 문구는 체크박스가 아니라 이 결과를 보고 만든다. */
  public enum UpdateResult {
    /** 바뀐 것이 없어 저장하지 않았다. */
    UNCHANGED,
    /** 내용만 바꿨다. 버전은 그대로다. */
    SAVED,
    /** 내용을 바꾸고 버전도 올렸다. */
    SAVED_AND_BUMPED,
  }

  /** ConsentKey 선언 순서대로 준다. 앱 동의 화면의 항목 순서가 이 순서다. */
  public List<ConsentDocument> getAll() {
    return consentDocumentRepository.findAll().stream()
      .sorted(Comparator.comparing(document -> document.getConsentKey().ordinal()))
      .toList();
  }

  public ConsentDocument get(ConsentKey key) {
    return consentDocumentRepository.findByConsentKey(key)
      .orElseThrow(() -> new CustomException(ErrorCode.CONSENT_DOCUMENT_NOT_FOUND));
  }

  public List<ConsentDocumentHistory> getHistory(ConsentKey key) {
    return consentDocumentHistoryRepository.findTop50ByConsentKeyOrderByCreatedAtDesc(key);
  }

  /**
   * 회원이 동의했다고 기록할 <b>묶음 버전</b>.
   *
   * <p><b>필수 문서만 센다.</b> 나중에 재동의를 판정할 때 이 값과 회원 기록을 견주게
   * 되는데, 선택 항목(소식 받기)까지 세면 동의할 의무가 없는 항목이 바뀐 것만으로
   * 전원을 다시 막아 세우게 된다.
   *
   * <p>버전은 {@link #VERSION_FORMAT} 날짜만 받으므로 문자열 순서가 곧 시간 순서다.
   * 전에는 형식을 보지 않아 {@code v2} 한 번에 묶음 버전이 영영 고정됐다 (#278 QA).
   *
   * <p>⚠️ 지금은 기록에만 쓴다. 재동의 판정({@code Member#hasRequiredConsents})은
   * 아직 버전을 보지 않는다.
   */
  public String bundleVersion() {
    return getAll().stream()
      .filter(document -> document.getConsentKey().isRequired())
      .map(ConsentDocument::getVersion)
      .max(Comparator.naturalOrder())
      // 문서가 하나도 없으면(초기화 실패) 빈 문자열이다. 앱은 이때 번들 기본값을 쓴다.
      .orElse("");
  }

  /**
   * 약관을 고친다. <b>고치기 직전 내용을 먼저 이력으로 남긴다</b> — 같은 트랜잭션이라
   * 이력 없는 덮어쓰기가 생길 수 없다.
   *
   * <p>필수 여부는 받지 않는다. 법이 정한 값이라 {@link ConsentKey#isRequired()} 를 따른다.
   *
   * @param bumpVersion 켰을 때만 버전을 올린다. 오타를 고칠 때마다 올리면 회원마다 어떤
   *                    문구에 동의했는지 가리기 어려워지므로 관리자가 고르게 둔다.
   * @return 실제로 한 일. 호출부는 이것으로 안내 문구를 만든다.
   */
  @Transactional
  public UpdateResult update(
    ConsentKey key,
    String label,
    String summary,
    String body,
    boolean bumpVersion,
    String newVersion,
    String changedBy,
    String reason
  ) {
    // 약관은 법적 문서라 "왜 바꿨는지"가 곧 근거다. 화면이 막더라도 요청을 직접 보내면
    // 뚫리므로 여기서 다시 막는다.
    if (reason == null || reason.isBlank()) {
      throw new CustomException(ErrorCode.CONSENT_REASON_REQUIRED);
    }

    // 브라우저 textarea 는 줄바꿈을 CRLF 로 제출한다. 정규화하지 않으면 저장만 눌러도
    // 바이트가 달라져 가짜 이력이 쌓이고, 앱 화면에 CR 이 섞여 들어간다.
    String normalizedBody = body == null ? "" : body.replace("\r\n", "\n").strip();
    String normalizedLabel = label == null ? "" : label.strip();
    String normalizedSummary = summary == null ? "" : summary.strip();

    // 공백만 있는 값은 비어 있는 것이다. 브라우저의 required 는 공백을 통과시킨다.
    // 한 항목이라도 비면 앱이 서버 약관 전체를 버리고 기본값으로 떨어지는데, 관리자는
    // "저장했습니다"를 보고 반영된 줄 안다 (#278 QA).
    if (normalizedBody.isEmpty() || normalizedLabel.isEmpty() || normalizedSummary.isEmpty()) {
      throw new CustomException(ErrorCode.CONSENT_FIELD_BLANK);
    }
    if (normalizedLabel.length() > TEXT_FIELD_MAX_LENGTH
      || normalizedSummary.length() > TEXT_FIELD_MAX_LENGTH) {
      throw new CustomException(ErrorCode.CONSENT_FIELD_TOO_LONG);
    }

    ConsentDocument document = get(key);
    String bumpTo = bumpVersion ? validateNewVersion(document.getVersion(), newVersion) : null;

    boolean contentChanged = !normalizedBody.equals(document.getBody())
      || !normalizedLabel.equals(document.getLabel())
      || !normalizedSummary.equals(document.getSummary());

    if (!contentChanged && bumpTo == null) {
      return UpdateResult.UNCHANGED;
    }

    consentDocumentHistoryRepository.save(snapshotOf(document, changedBy, reason));

    document.setLabel(normalizedLabel);
    document.setSummary(normalizedSummary);
    document.setBody(normalizedBody);
    document.setRequired(key.isRequired());
    if (bumpTo == null) {
      return UpdateResult.SAVED;
    }
    document.setVersion(bumpTo);
    document.setPublishedAt(LocalDateTime.now());
    return UpdateResult.SAVED_AND_BUMPED;
  }

  /**
   * 버전을 올리기로 했을 때의 새 값을 검사한다.
   *
   * <p>전에는 칸을 비워도, 지금과 같아도, 날짜가 아니어도 받았다. 그러고는 체크박스만 보고
   * "버전을 올렸습니다"라고 안내했다 (#278 QA).
   */
  private String validateNewVersion(String current, String newVersion) {
    String candidate = newVersion == null ? "" : newVersion.strip();
    if (candidate.isEmpty()) {
      throw new CustomException(ErrorCode.CONSENT_VERSION_REQUIRED);
    }
    if (!VERSION_FORMAT.matcher(candidate).matches()) {
      throw new CustomException(ErrorCode.CONSENT_VERSION_INVALID);
    }
    try {
      LocalDate.parse(candidate); // 2026-02-30 같은 없는 날짜를 거른다
    } catch (DateTimeParseException e) {
      throw new CustomException(ErrorCode.CONSENT_VERSION_INVALID);
    }
    // 과거로 되돌리면 "그 사람이 어떤 문구에 동의했나"의 순서가 뒤집힌다.
    if (candidate.compareTo(current) <= 0) {
      throw new CustomException(ErrorCode.CONSENT_VERSION_NOT_NEWER);
    }
    return candidate;
  }

  /** 바뀌기 직전 상태를 그대로 떠낸다. */
  private ConsentDocumentHistory snapshotOf(
    ConsentDocument document, String changedBy, String reason
  ) {
    ConsentDocumentHistory history = new ConsentDocumentHistory();
    history.setConsentKey(document.getConsentKey());
    history.setVersion(document.getVersion());
    history.setLabel(document.getLabel());
    history.setSummary(document.getSummary());
    history.setBody(document.getBody());
    history.setRequired(document.isRequired());
    history.setChangedBy(changedBy == null || changedBy.isBlank() ? "알 수 없음" : changedBy);
    history.setReason(reason.strip());
    return history;
  }
}
