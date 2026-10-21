package com.chuseok22.elumserver.talk.infrastructure.storage;

import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage;

/**
 * 이야기 글에 붙는 그림 사본 보관소: 저장, 읽기, 글 단위 삭제
 * 열쇠 {postId}/{stepOrder}.{jpg|png|webp} — 경로가 아니라 열쇠만 DB 에 둠
 */
public interface TalkImageStorage {

  /**
   * 그림 사본 저장 > 열쇠
   *
   * @throws com.chuseok22.elumserver.common.infrastructure.exception.CustomException 쓰기 실패 또는 저장 폴더 밖 글 번호
   */
  String save(String postId, int stepOrder, byte[] bytes, String contentType);

  /**
   * @throws com.chuseok22.elumserver.common.infrastructure.exception.CustomException 없으면 {@code TALK_IMAGE_NOT_FOUND}
   */
  RoutineImageStorage.ImageContent read(String key);

  /**
   * 글의 그림 폴더 통째 삭제 (없거나 실패해도 예외 없음)
   */
  void deletePost(String postId);
}
