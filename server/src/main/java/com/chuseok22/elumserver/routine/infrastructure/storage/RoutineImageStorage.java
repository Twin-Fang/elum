package com.chuseok22.elumserver.routine.infrastructure.storage;

import com.chuseok22.elumserver.ai.core.GeneratedImage;

/**
 * 카드 삽화를 담아 두는 곳.
 *
 * <p><b>저장 결과로 경로가 아니라 열쇠를 돌려준다.</b> 경로를 그대로 DB에 넣으면 저장
 * 위치를 옮기는 순간 그 값이 전부 죽는다 — 과거 카드의 그림이 통째로 사라진다는 뜻이다.
 * 열쇠만 두면 파일을 옮기고 구현체를 갈아끼우는 것으로 끝난다.
 *
 * <pre>
 *   경로 저장   data/routine-images/abc/1.png   ← 저장소가 바뀌면 죽는 값
 *   열쇠 저장   abc/1.png                        ← 어디에 두든 그대로 유효
 * </pre>
 *
 * <p>지금 구현은 서버의 로컬 디스크를 쓴다. 서버가 여러 대가 되면 한 대가 저장한 그림을
 * 다른 대가 읽지 못하므로 공유 저장소 구현체로 바꿔야 한다. 그때 이 인터페이스를 쓰는
 * 쪽은 바뀌지 않는다.
 */
public interface RoutineImageStorage {

  /**
   * 그림을 담고 <b>열쇠</b>를 돌려준다.
   *
   * @param batchId 한 번의 생성에서 만든 그림들을 묶는 값
   */
  String save(String batchId, Integer stepOrder, GeneratedImage image);

  /**
   * 한 번의 생성에서 만든 그림을 통째로 지운다 (이슈 #215).
   *
   * <p>그림은 엔티티를 저장하기 <b>전에</b> 기록된다. 저장이 실패하면 아무도 참조하지
   * 않는 그림이 남아 용량이 계속 불어난다. 실패 경로에서 불러 방금 만든 것만 되돌린다.
   *
   * <p>지우다 실패해도 예외를 밖으로 내지 않는다 — 이미 다른 실패를 처리하는 중이라,
   * 여기서 예외를 던지면 진짜 원인이 가려진다.
   */
  void deleteBatch(String batchId);

  ImageContent read(String key);

  record ImageContent(byte[] bytes, String contentType) {

  }
}
