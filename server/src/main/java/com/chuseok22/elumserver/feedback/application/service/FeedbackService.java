package com.chuseok22.elumserver.feedback.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.exception.ErrorCode;
import com.chuseok22.elumserver.feedback.application.dto.request.FeedbackRequest;
import com.chuseok22.elumserver.feedback.infrastructure.entity.Feedback;
import com.chuseok22.elumserver.feedback.infrastructure.repository.FeedbackRepository;
import java.nio.charset.StandardCharsets;
import java.time.Clock;
import java.time.LocalDateTime;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.data.domain.Page;
import org.springframework.data.domain.PageRequest;
import org.springframework.data.domain.Sort;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 의견 저장과 관리자 조회·삭제. 의견 원문은 로그에 남기지 않는다.
 */
@Service
public class FeedbackService {

  static final int MAX_MESSAGE_LENGTH = 2000;
  static final int MAX_LOG_BYTES = 256 * 1024;
  static final int MAX_VERSION_LENGTH = 32;
  static final int MAX_OS_LENGTH = 64;
  static final int DAILY_LIMIT = 20;
  public static final int ADMIN_PAGE_SIZE = 20;

  private final FeedbackRepository feedbackRepository;
  private final Clock clock;

  // 생성자가 둘이라 스프링이 쓸 것을 명시한다. 이 앱에는 Clock 빈이 없다.
  @Autowired
  public FeedbackService(FeedbackRepository feedbackRepository) {
    this(feedbackRepository, Clock.systemDefaultZone());
  }

  FeedbackService(FeedbackRepository feedbackRepository, Clock clock) {
    this.feedbackRepository = feedbackRepository;
    this.clock = clock;
  }

  /// 의견을 저장하고 id 를 돌려준다. 앱 버전·OS 는 길면 거절하지 않고 잘라 저장한다.
  @Transactional
  public String submit(String memberId, FeedbackRequest request) {
    String message = request.message() == null ? "" : request.message().strip();
    if (message.isEmpty()) {
      throw new CustomException(ErrorCode.FEEDBACK_MESSAGE_EMPTY);
    }
    if (message.length() > MAX_MESSAGE_LENGTH) {
      throw new CustomException(ErrorCode.FEEDBACK_MESSAGE_TOO_LONG);
    }
    String appLog = request.appLog();
    if (appLog != null && appLog.getBytes(StandardCharsets.UTF_8).length > MAX_LOG_BYTES) {
      throw new CustomException(ErrorCode.FEEDBACK_LOG_TOO_LARGE);
    }

    // 하루는 서버 기본 시간대의 0시부터다. 다른 기능의 일일 상한(광고 보상)과 같은 기준이다.
    LocalDateTime todayStart = LocalDateTime.now(clock).toLocalDate().atStartOfDay();
    if (feedbackRepository.countByMemberIdAndCreatedAtGreaterThanEqual(memberId, todayStart) >= DAILY_LIMIT) {
      throw new CustomException(ErrorCode.FEEDBACK_RATE_LIMITED);
    }

    Feedback feedback = new Feedback();
    feedback.setMemberId(memberId);
    feedback.setMessage(message);
    // 빈 기록은 "보내지 않음"과 같게 둔다.
    feedback.setAppLog(appLog == null || appLog.isBlank() ? null : appLog);
    feedback.setAppVersion(truncate(request.appVersion(), MAX_VERSION_LENGTH));
    feedback.setOs(truncate(request.os(), MAX_OS_LENGTH));
    return feedbackRepository.save(feedback).getId();
  }

  /// 관리자 목록. 최신순.
  @Transactional(readOnly = true)
  public Page<Feedback> list(int page) {
    return feedbackRepository.findAll(
      PageRequest.of(Math.max(page, 0), ADMIN_PAGE_SIZE, Sort.by(Sort.Direction.DESC, "createdAt")));
  }

  @Transactional(readOnly = true)
  public Feedback get(String id) {
    return feedbackRepository.findById(id).orElseThrow(() -> new CustomException(ErrorCode.FEEDBACK_NOT_FOUND));
  }

  /// 계정을 탈퇴할 때 그 회원의 의견과 앱 상태 기록을 모두 지운다. 개인 정보가 섞여 있을 수 있어 남기지 않는다.
  @Transactional
  public void deleteAllOf(String memberId) {
    feedbackRepository.deleteAllByMemberId(memberId);
  }

  @Transactional
  public void delete(String id) {
    feedbackRepository.delete(get(id));
  }

  private static String truncate(String value, int max) {
    if (value == null || value.isBlank()) {
      return null;
    }
    String trimmed = value.strip();
    return trimmed.length() <= max ? trimmed : trimmed.substring(0, max);
  }
}
