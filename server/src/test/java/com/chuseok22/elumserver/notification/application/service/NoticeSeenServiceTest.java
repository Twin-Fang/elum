package com.chuseok22.elumserver.notification.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.ArgumentCaptor.forClass;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.notification.infrastructure.entity.NoticeSeen;
import com.chuseok22.elumserver.notification.infrastructure.repository.NoticeSeenRepository;
import java.time.LocalDateTime;
import java.util.Optional;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.ArgumentCaptor;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/** 공지 읽음 기록: 처음이면 만들고, 두 번째부터는 같은 행의 시각만 갱신한다 */
@ExtendWith(MockitoExtension.class)
class NoticeSeenServiceTest {

  private static final String MEMBER_ID = "guardian-1";

  @Mock
  private NoticeSeenRepository noticeSeenRepository;
  @InjectMocks
  private NoticeSeenService service;

  @Test
  @DisplayName("처음 읽으면 행을 만든다")
  void firstMarkSeen_createsRow() {
    when(noticeSeenRepository.findById(MEMBER_ID)).thenReturn(Optional.empty());
    LocalDateTime seenAt = LocalDateTime.of(2026, 10, 19, 12, 0);

    service.markSeen(MEMBER_ID, seenAt);

    ArgumentCaptor<NoticeSeen> saved = forClass(NoticeSeen.class);
    verify(noticeSeenRepository).save(saved.capture());
    assertThat(saved.getValue().getMemberId()).isEqualTo(MEMBER_ID);
    assertThat(saved.getValue().getSeenAt()).isEqualTo(seenAt);
  }

  @Test
  @DisplayName("다시 읽으면 있는 행의 시각을 갱신한다")
  void secondMarkSeen_updatesExistingRow() {
    NoticeSeen existing = new NoticeSeen();
    existing.setMemberId(MEMBER_ID);
    existing.setSeenAt(LocalDateTime.of(2026, 10, 1, 9, 0));
    when(noticeSeenRepository.findById(MEMBER_ID)).thenReturn(Optional.of(existing));
    LocalDateTime later = LocalDateTime.of(2026, 10, 19, 12, 0);

    service.markSeen(MEMBER_ID, later);

    verify(noticeSeenRepository, times(1)).save(existing);
    assertThat(existing.getSeenAt()).isEqualTo(later);
  }
}
