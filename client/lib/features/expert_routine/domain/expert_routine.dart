import 'package:flutter/foundation.dart';

import '../../guardian/domain/routine_template.dart';
import '../../talk/domain/talk_json.dart';

/// 전문가 일과 목록 1건 (`GET /api/expert-routines`)
@immutable
class ExpertRoutineSummary {
  const ExpertRoutineSummary({
    required this.id,
    required this.title,
    required this.stepCount,
    this.summary,
    this.category,
    this.rewardText,
    this.coverPictogramId,
    this.coverExampleImageId,
  });

  final String id;
  final String title;
  final int stepCount;

  /// 한 줄 설명. 없으면 null
  final String? summary;

  /// 모르는 분류(새 서버 값)면 null — 목록에는 그대로 보인다
  final RoutineTemplateCategory? category;

  /// 보상 제안. 없으면 null
  final String? rewardText;

  /// 첫 카드 그림 (목록 칸)
  final String? coverPictogramId;
  final String? coverExampleImageId;

  /// 서버 JSON > 목록 칸. id·제목이 없으면 null (그 줄만 건너뜀)
  static ExpertRoutineSummary? fromJson(Map<String, dynamic> json) {
    final id = TalkJson.nonEmptyText(json['id']);
    final title = TalkJson.nonEmptyText(json['title']);
    if (id == null || title == null) return null;
    return ExpertRoutineSummary(
      id: id,
      title: title,
      stepCount: TalkJson.count(json['stepCount']),
      summary: TalkJson.nonEmptyText(json['summary']),
      category: RoutineTemplateCategory.fromServer(TalkJson.text(json['category'])),
      rewardText: TalkJson.nonEmptyText(json['rewardText']),
      coverPictogramId: TalkJson.nonEmptyText(json['coverPictogramId']),
      coverExampleImageId: TalkJson.nonEmptyText(json['coverExampleImageId']),
    );
  }
}

/// 전문가 일과 카드 1장
@immutable
class ExpertRoutineStep {
  const ExpertRoutineStep({
    required this.stepOrder,
    required this.text,
    this.pictogramId,
    this.exampleImageId,
  });

  final int stepOrder;
  final String text;
  final String? pictogramId;
  final String? exampleImageId;

  static ExpertRoutineStep? fromJson(Map<String, dynamic> json) {
    final text = TalkJson.nonEmptyText(json['text']);
    if (text == null) return null;
    return ExpertRoutineStep(
      stepOrder: TalkJson.count(json['stepOrder']),
      text: text,
      pictogramId: TalkJson.nonEmptyText(json['pictogramId']),
      exampleImageId: TalkJson.nonEmptyText(json['exampleImageId']),
    );
  }
}

/// 전문가 일과 미리 보기 (`GET /api/expert-routines/{id}`)
@immutable
class ExpertRoutineDetail {
  const ExpertRoutineDetail({
    required this.id,
    required this.title,
    required this.language,
    required this.steps,
    this.summary,
    this.rewardText,
  });

  final String id;
  final String title;

  /// 카드 글의 언어 코드 (카드 글은 이 언어 글꼴로 그린다)
  final String language;
  final List<ExpertRoutineStep> steps;
  final String? summary;
  final String? rewardText;

  /// 서버 JSON > 미리 보기. id·제목이 없으면 null (형식 오류로 본다)
  static ExpertRoutineDetail? fromJson(Map<String, dynamic> json) {
    final id = TalkJson.nonEmptyText(json['id']);
    final title = TalkJson.nonEmptyText(json['title']);
    if (id == null || title == null) return null;
    return ExpertRoutineDetail(
      id: id,
      title: title,
      language: TalkJson.nonEmptyText(json['language']) ?? 'ko',
      steps: TalkJson.list(json['steps'], ExpertRoutineStep.fromJson),
      summary: TalkJson.nonEmptyText(json['summary']),
      rewardText: TalkJson.nonEmptyText(json['rewardText']),
    );
  }
}

/// 가져오기 결과: 새 일과 id · 들어간 이룸이 id
typedef ExpertRoutineImportResult = ({String routineId, String profileId});

/// 화면별 추적 코드: 서버 코드가 없는 실패에 붙는다 (목록 001, 미리 보기 002, 가져오기 020, 이룸이 없음 021)
class ExpertRoutineScreenCodes {
  const ExpertRoutineScreenCodes._();

  static const list = 'E-EXR-001';
  static const detail = 'E-EXR-002';
  static const importToLibrary = 'E-EXR-020';
  static const noElumi = 'E-EXR-021';
}
