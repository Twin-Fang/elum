package com.chuseok22.elumserver.routine.application.dto;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import java.util.List;

/**
 * 이야기에서 일과관리로 가져올 일과 초안: 글 id, 제목, 언어, 카드 목록
 * 카드 그림은 글 쪽에서 읽어 넘기며(없으면 null) 일과 쪽이 새 열쇠로 저장
 */
public record RoutineImportDraft(
  String talkPostId,
  String title,
  AppLocale language,
  List<DraftStep> steps
) {

  /// 카드 1장: stepOrder 는 0부터, image 는 글에 담긴 그림 사본(없거나 읽지 못하면 null)
  public record DraftStep(
    int stepOrder,
    String title,
    String description,
    String pictogramId,
    String exampleImageId,
    ImageContent image
  ) {

  }
}
