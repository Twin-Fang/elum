import 'package:flutter/foundation.dart';

import 'talk_json.dart';

/// 올리기 미리보기: 이름을 가린 뒤의 제목·카드와 보호자 사진 카드 여부 (서버 `TalkPreviewResponse`)
@immutable
class TalkPreview {
  const TalkPreview({
    required this.title,
    required this.steps,
    required this.hasGuardianPhoto,
  });

  final String title;
  final List<TalkPreviewStep> steps;

  /// true 면 흐리게 선택 화면을 보여준다
  final bool hasGuardianPhoto;

  /// 제목이 없으면 null
  static TalkPreview? fromJson(Map<String, dynamic> json) {
    final title = TalkJson.text(json['title']);
    if (title == null) return null;
    return TalkPreview(
      title: title,
      steps: TalkJson.list(json['steps'], TalkPreviewStep.fromJson),
      hasGuardianPhoto: TalkJson.flag(json['hasGuardianPhoto']),
    );
  }
}

/// 미리보기 카드 1장
@immutable
class TalkPreviewStep {
  const TalkPreviewStep({
    required this.stepId,
    required this.stepOrder,
    required this.description,
    required this.isGuardianPhoto,
    this.title,
  });

  /// 원본 카드 id (올리기의 blurredStepIds 에 쓴다)
  final String stepId;

  /// 카드 순서 (1부터, 서버 미리보기 기준)
  final int stepOrder;
  final String? title;
  final String description;

  /// 보호자가 올린 사진인가 (흐리게 선택 대상)
  final bool isGuardianPhoto;

  /// 화면에 보이는 카드 번호 (1부터)
  int get cardNumber => stepOrder;

  static TalkPreviewStep? fromJson(Map<String, dynamic> json) {
    final stepId = TalkJson.nonEmptyText(json['stepId']);
    if (stepId == null) return null;
    return TalkPreviewStep(
      stepId: stepId,
      stepOrder: TalkJson.count(json['stepOrder']),
      title: TalkJson.text(json['title']),
      description: TalkJson.text(json['description']) ?? '',
      isGuardianPhoto: TalkJson.flag(json['isGuardianPhoto']),
    );
  }
}
