import 'package:flutter/material.dart';

import '../../../../core/widgets/elum_toast.dart';
import '../../domain/talk_post.dart';
import 'talk_step_image.dart';

/// 가져오기 완료 토스트: 공통 토스트 + 첫 카드 그림 + `보러 가기` 동작 (모양은 공통 토스트 한 곳이 정한다)
/// 화면을 옮기기 전에 잡아 둔 [messenger] 로 띄운다. 그릴 그림이 없는 글은 글자만
void showTalkImportDoneToast(
  ScaffoldMessengerState? messenger, {
  required String message,
  required String actionLabel,
  required VoidCallback onAction,
  required String postId,
  TalkStep? firstStep,
}) => showElumToastOn(
  messenger,
  message,
  actionLabel: actionLabel,
  onAction: onAction,
  picture: _hasPicture(firstStep) ? TalkStepImage(postId: postId, step: firstStep!) : null,
);

/// 올린 그림·예시 그림·픽토그램 중 하나라도 있는 카드인가
bool _hasPicture(TalkStep? step) =>
    step != null && (step.hasImage || step.pictogramId != null || step.exampleImageId != null);
