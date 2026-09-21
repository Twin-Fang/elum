package com.chuseok22.elumserver.consent.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.consent.core.ConsentKey;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocument;
import com.chuseok22.elumserver.consent.infrastructure.entity.ConsentDocumentHistory;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentHistoryRepository;
import com.chuseok22.elumserver.consent.infrastructure.repository.ConsentDocumentRepository;
import java.time.LocalDateTime;
import java.util.Comparator;
import java.util.List;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class ConsentDocumentService {

  private final ConsentDocumentRepository consentDocumentRepository;
  private final ConsentDocumentHistoryRepository consentDocumentHistoryRepository;

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
   * <p><b>필수 문서만 센다.</b> 선택 항목(소식 받기)이 바뀌었다고 전원에게 재동의를
   * 요구하면, 동의할 의무가 없는 항목 때문에 서비스가 막히는 셈이 된다.
   *
   * <p>버전은 날짜 문자열이라 사전순 비교가 곧 시간순 비교다.
   */
  public String bundleVersion() {
    return getAll().stream()
      .filter(ConsentDocument::isRequired)
      .map(ConsentDocument::getVersion)
      .max(Comparator.naturalOrder())
      // 문서가 하나도 없으면(초기화 실패) 빈 문자열이다. 앱은 이때 번들 기본값을 쓴다.
      .orElse("");
  }

  /**
   * 약관을 고친다. <b>고치기 직전 내용을 먼저 이력으로 남긴다</b> — 같은 트랜잭션이라
   * 이력 없는 덮어쓰기가 생길 수 없다.
   *
   * @param newVersion 비어 있으면 버전을 올리지 않는다. 오타 수정까지 재동의를 받으면
   *                   사용자가 지치므로 <b>올릴지 말지를 관리자가 고른다</b>.
   */
  @Transactional
  public void update(
    ConsentKey key,
    String label,
    String summary,
    String body,
    boolean required,
    String newVersion,
    String changedBy,
    String reason
  ) {
    ConsentDocument document = get(key);

    // 브라우저 textarea 는 줄바꿈을 CRLF 로 제출한다. 정규화하지 않으면 저장만 눌러도
    // 바이트가 달라져 가짜 이력이 쌓이고, 앱 화면에 CR 이 섞여 들어간다.
    String normalizedBody = body == null ? "" : body.replace("\r\n", "\n").strip();
    String normalizedLabel = label == null ? "" : label.strip();
    String normalizedSummary = summary == null ? "" : summary.strip();
    String bumpTo = newVersion == null ? "" : newVersion.strip();

    boolean contentChanged = !normalizedBody.equals(document.getBody())
      || !normalizedLabel.equals(document.getLabel())
      || !normalizedSummary.equals(document.getSummary())
      || required != document.isRequired();
    boolean versionChanged = !bumpTo.isEmpty() && !bumpTo.equals(document.getVersion());

    if (!contentChanged && !versionChanged) {
      return;
    }

    consentDocumentHistoryRepository.save(snapshotOf(document, changedBy, reason));

    document.setLabel(normalizedLabel);
    document.setSummary(normalizedSummary);
    document.setBody(normalizedBody);
    document.setRequired(required);
    if (versionChanged) {
      document.setVersion(bumpTo);
      document.setPublishedAt(LocalDateTime.now());
    }
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
    history.setReason(reason == null || reason.isBlank() ? "(사유 없음)" : reason.strip());
    return history;
  }
}
