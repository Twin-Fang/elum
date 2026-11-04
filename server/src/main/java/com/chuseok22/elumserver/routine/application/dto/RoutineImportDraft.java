package com.chuseok22.elumserver.routine.application.dto;

import com.chuseok22.elumserver.common.locale.AppLocale;
import com.chuseok22.elumserver.routine.infrastructure.storage.RoutineImageStorage.ImageContent;
import java.util.List;

/**
 * 일과관리로 가져올 일과 초안: 이야기 글 id(전문가 일과면 null), 제목, 언어, 카드 목록, 보상 제안(없으면 null)
 * 카드 그림은 보내는 쪽에서 읽어 넘기며(없으면 null) 일과 쪽이 새 열쇠로 저장
 */
public record RoutineImportDraft(
  String talkPostId,
  String title,
  AppLocale language,
  List<DraftStep> steps,
  String rewardText,
  String rewardPresetKey
) {

  /// 보상 없이 가져오는 초안 (이야기 글은 보상을 싣지 않음)
  public RoutineImportDraft(String talkPostId, String title, AppLocale language, List<DraftStep> steps) {
    this(talkPostId, title, language, steps, null, null);
  }

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
