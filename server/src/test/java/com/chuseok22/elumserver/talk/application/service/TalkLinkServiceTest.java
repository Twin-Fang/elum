package com.chuseok22.elumserver.talk.application.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.member.application.service.Caller;
import com.chuseok22.elumserver.routine.application.dto.RoutineShareSnapshot;
import com.chuseok22.elumserver.routine.application.service.RoutineShareService;
import com.chuseok22.elumserver.talk.application.dto.request.TalkLinkCreateRequest;
import com.chuseok22.elumserver.talk.application.dto.response.TalkLinkResponse;
import com.chuseok22.elumserver.talk.core.TalkPostStatus;
import com.chuseok22.elumserver.talk.core.TalkPostVisibility;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostRepository;
import java.util.List;
import java.util.Optional;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

/// 링크로 보내기: 같은 일과를 다시 보내면 링크가 하나 더 생겨, 하나를 꺼도 다른 링크로 계속 보이는 것을 막는다.
@ExtendWith(MockitoExtension.class)
class TalkLinkServiceTest {

  private static final Caller GUARDIAN = Caller.guardian("member-1");

  @Mock
  private TalkPostRepository talkPostRepository;
  @Mock
  private TalkPostService talkPostService;
  @Mock
  private RoutineShareService routineShareService;

  private TalkLinkService talkLinkService;

  @BeforeEach
  void setUp() {
    talkLinkService = new TalkLinkService(talkPostRepository, talkPostService, routineShareService);
  }

  @Test
  @DisplayName("켜진 링크가 있는 일과를 다시 보내면 새 글 없이 그 링크를 돌려준다")
  void create_activeLinkExists_reusesSameLink() {
    when(routineShareService.snapshotForLinkShare(GUARDIAN, "copy-1")).thenReturn(snapshotOf("original-1"));
    TalkPost activeLink = new TalkPost();
    activeLink.setId("link-1");
    when(talkPostRepository.findFirstBySourceRoutineIdAndStatusAndVisibility(
      "original-1", TalkPostStatus.VISIBLE, TalkPostVisibility.LINK_ONLY)).thenReturn(Optional.of(activeLink));

    TalkLinkResponse response = talkLinkService.create(GUARDIAN, new TalkLinkCreateRequest("copy-1", List.of()));

    assertThat(response.postId()).isEqualTo("link-1");
    assertThat(response.isReused()).isTrue();
    verifyNoInteractions(talkPostService);
  }

  private static RoutineShareSnapshot snapshotOf(String originalRoutineId) {
    return new RoutineShareSnapshot(originalRoutineId, "버스 타기", AppLocale.KO, "하늘이", List.of());
  }
}
