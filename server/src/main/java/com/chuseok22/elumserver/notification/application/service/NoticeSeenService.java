package com.chuseok22.elumserver.notification.application.service;

import com.chuseok22.elumserver.notification.infrastructure.entity.NoticeSeen;
import com.chuseok22.elumserver.notification.infrastructure.repository.NoticeSeenRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/** 공지 탭 읽은 시각: 조회, 기록(없으면 만들고 있으면 갱신). 공지 도메인은 repository 대신 이 서비스를 거친다 */
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class NoticeSeenService {

  private final NoticeSeenRepository noticeSeenRepository;

  public Optional<LocalDateTime> findSeenAt(String memberId) {
    return noticeSeenRepository.findById(memberId).map(NoticeSeen::getSeenAt);
  }

  @Transactional
  public void markSeen(String memberId, LocalDateTime seenAt) {
    NoticeSeen seen = noticeSeenRepository.findById(memberId).orElseGet(() -> {
      NoticeSeen created = new NoticeSeen();
      created.setMemberId(memberId);
      return created;
    });
    seen.setSeenAt(seenAt);
    noticeSeenRepository.save(seen);
  }
}
