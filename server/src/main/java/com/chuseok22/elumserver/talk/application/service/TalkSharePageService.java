package com.chuseok22.elumserver.talk.application.service;

import com.chuseok22.elumserver.common.infrastructure.exception.CustomException;
import com.chuseok22.elumserver.common.infrastructure.media.PreviewImageConverter;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import com.chuseok22.elumserver.talk.application.dto.response.TalkSharePage;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPost;
import com.chuseok22.elumserver.talk.infrastructure.entity.TalkPostStep;
import com.chuseok22.elumserver.talk.infrastructure.repository.TalkPostStepRepository;
import com.chuseok22.elumserver.talk.infrastructure.storage.TalkImageStorage;
import java.util.Optional;
import java.util.Set;
import java.util.regex.Pattern;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

/**
 * 앱 밖 공유 링크용 글 조회: 공유 페이지 정보, 미리보기 썸네일
 * 인증 없이 열리므로 공개로 볼 수 있는 글(보이는 글 + 정지 아닌 글쓴이)만 답하고, 그 밖은 전부 빈 결과
 */
@Slf4j
@Service
@RequiredArgsConstructor
@Transactional(readOnly = true)
public class TalkSharePageService {

  // 글 id 모양 (UUID). 다른 모양은 DB 를 보지 않고 빈 결과
  private static final Pattern POST_ID_SHAPE =
    Pattern.compile("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$");
  // 미리보기에 싣는 한마디 최대 글자 수
  private static final int NOTE_PREVIEW_MAX_LENGTH = 120;
  private static final String ELLIPSIS = "…";
  // 카카오톡 미리보기가 그리는 그림 형식 (webp 는 JPEG 로 바꿔 보냄, 못 바꾸면 기본 그림)
  private static final Set<String> PREVIEW_IMAGE_CONTENT_TYPES = Set.of("image/jpeg", "image/png");
  private static final String WEBP_CONTENT_TYPE = "image/webp";
  private static final String JPEG_CONTENT_TYPE = "image/jpeg";

  private final TalkPostAccess talkPostAccess;
  private final TalkPostStepRepository talkPostStepRepository;
  private final TalkImageStorage talkImageStorage;
  private final PreviewImageConverter previewImageConverter;

  /**
   * 공유 페이지 정보: 모양 확인 > 공개로 볼 수 있는 글 확인(링크 글은 원본이 살아 있을 때만) > 분류·제목·한마디 앞부분 (볼 수 없으면 빈 결과)
   */
  public Optional<TalkSharePage> page(String postId) {
    return findPublicPost(postId).map(post -> new TalkSharePage(
      post.getId(), post.getCategory() == null ? null : post.getCategory().getLabel(), post.getTitle(),
      notePreviewOf(post.getNote()), post.getStepCount(), post.isLinkOnly()));
  }

  /**
   * 미리보기 썸네일: 공개 글 > 그림이 있는 첫 카드 > 저장된 사본 (흐림 반영본, webp 는 JPEG 로). 없거나 읽기·변환 실패면 빈 결과
   */
  public Optional<ImageContent> thumbnail(String postId) {
    Optional<String> imageKey = findPublicPost(postId)
      .flatMap(post -> talkPostStepRepository.findByPostIdOrderByStepOrderAsc(post.getId()).stream()
        .map(TalkPostStep::getImageKey)
        .filter(key -> key != null && !key.isBlank())
        .findFirst());
    if (imageKey.isEmpty()) {
      return Optional.empty();
    }
    try {
      return toPreviewImage(talkImageStorage.read(imageKey.get()));
    } catch (CustomException e) {
      // 그림이 지워졌어도 미리보기는 기본 그림으로 이어감
      log.warn("[talk share] thumbnail read failed : {}", e.getErrorCode());
      return Optional.empty();
    }
  }

  // 카카오톡이 그리는 형식으로: jpeg·png 그대로, webp 는 JPEG 로 (AI 카드 그림, #1219), 그 외는 빈 결과
  private Optional<ImageContent> toPreviewImage(ImageContent content) {
    if (PREVIEW_IMAGE_CONTENT_TYPES.contains(content.contentType())) {
      return Optional.of(content);
    }
    if (WEBP_CONTENT_TYPE.equals(content.contentType())) {
      return previewImageConverter.webpToJpeg(content.bytes()).map(jpeg -> new ImageContent(jpeg, JPEG_CONTENT_TYPE));
    }
    return Optional.empty();
  }

  private Optional<TalkPost> findPublicPost(String postId) {
    if (postId == null || !POST_ID_SHAPE.matcher(postId).matches()) {
      return Optional.empty();
    }
    return talkPostAccess.findPubliclyVisiblePost(postId);
  }

  // 한마디 > 앞 120자 (넘치면 말줄임, 비었으면 null)
  private static String notePreviewOf(String note) {
    if (note == null || note.isBlank()) {
      return null;
    }
    String trimmed = note.strip();
    if (trimmed.codePointCount(0, trimmed.length()) <= NOTE_PREVIEW_MAX_LENGTH) {
      return trimmed;
    }
    int end = trimmed.offsetByCodePoints(0, NOTE_PREVIEW_MAX_LENGTH);
    return trimmed.substring(0, end).stripTrailing() + ELLIPSIS;
  }
}
