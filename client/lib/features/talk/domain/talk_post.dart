import 'package:flutter/foundation.dart';

import '../../guardian/domain/routine_template.dart';
import 'talk_json.dart';

/// 글 카드 1장의 그림 정보 (서버 `StepThumb`·`DetailStep`)
/// 그림 우선순위: 올린 그림(hasImage) > 예시 이미지 > 픽토그램. 목록 미리보기에는 제목·설명이 없다
@immutable
class TalkStep {
  const TalkStep({
    required this.stepOrder,
    required this.hasImage,
    required this.isBlurred,
    this.title,
    this.description = '',
    this.pictogramId,
    this.exampleImageId,
  });

  /// 카드 순서 (0부터)
  final int stepOrder;
  final String? title;
  final String description;

  /// true 면 글 전용 그림을 `TalkImageRepository` 로 받는다
  final bool hasImage;
  final String? pictogramId;
  final String? exampleImageId;

  /// 그림을 흐리게 보여줄 것인가
  final bool isBlurred;

  /// 순서가 없으면 null (그 카드만 버린다)
  static TalkStep? fromJson(Map<String, dynamic> json) {
    final order = json['stepOrder'];
    if (order is! num) return null;
    return TalkStep(
      stepOrder: order.toInt(),
      title: TalkJson.text(json['title']),
      description: TalkJson.text(json['description']) ?? '',
      hasImage: TalkJson.flag(json['hasImage']),
      pictogramId: TalkJson.text(json['pictogramId']),
      exampleImageId: TalkJson.text(json['exampleImageId']),
      isBlurred: TalkJson.flag(json['isBlurred']),
    );
  }
}

/// 피드·인기 목록의 글 1건 (서버 `TalkPostSummaryResponse`)
@immutable
class TalkPostSummary {
  const TalkPostSummary({
    required this.id,
    required this.title,
    required this.stepCount,
    required this.previewSteps,
    required this.helpfulCount,
    required this.commentCount,
    required this.importCount,
    required this.isMine,
    required this.createdAt,
    this.authorNickname,
    this.category,
    this.note,
  });

  final String id;

  /// 닉네임이 없는 계정은 null
  final String? authorNickname;
  final bool isMine;
  final String title;

  /// 모르는 분류 값이면 null
  final RoutineTemplateCategory? category;
  final int stepCount;

  /// 앞 4장 카드
  final List<TalkStep> previewSteps;
  final String? note;
  final int helpfulCount;
  final int commentCount;
  final int importCount;
  final DateTime createdAt;

  /// id·제목·올린 시각이 깨졌으면 null (그 글만 버린다)
  static TalkPostSummary? fromJson(Map<String, dynamic> json) {
    final id = TalkJson.nonEmptyText(json['id']);
    final title = TalkJson.text(json['title']);
    final createdAt = TalkJson.time(json['createdAt']);
    if (id == null || title == null || createdAt == null) return null;
    return TalkPostSummary(
      id: id,
      authorNickname: TalkJson.text(json['authorNickname']),
      isMine: TalkJson.flag(json['isMine']),
      title: title,
      category: RoutineTemplateCategory.fromServer(
        TalkJson.text(json['category']),
      ),
      stepCount: TalkJson.count(json['stepCount']),
      previewSteps: TalkJson.list(json['previewSteps'], TalkStep.fromJson),
      note: TalkJson.text(json['note']),
      helpfulCount: TalkJson.count(json['helpfulCount']),
      commentCount: TalkJson.count(json['commentCount']),
      importCount: TalkJson.count(json['importCount']),
      createdAt: createdAt,
    );
  }
}

/// 글 상세 (서버 `TalkPostDetailResponse`)
@immutable
class TalkPostDetail {
  const TalkPostDetail({
    required this.id,
    required this.title,
    required this.stepCount,
    required this.steps,
    required this.helpfulCount,
    required this.commentCount,
    required this.importCount,
    required this.isMine,
    required this.isHelpfulByMe,
    required this.isImportedByMe,
    required this.createdAt,
    this.authorNickname,
    this.category,
    this.note,
  });

  final String id;
  final String? authorNickname;
  final bool isMine;
  final String title;
  final RoutineTemplateCategory? category;
  final int stepCount;
  final String? note;
  final int helpfulCount;
  final int commentCount;
  final int importCount;
  final DateTime createdAt;

  /// 카드 목록 (순서대로)
  final List<TalkStep> steps;

  /// 내가 도움이 됐어요를 눌렀는가
  final bool isHelpfulByMe;

  /// 내가 일과관리로 가져갔는가
  final bool isImportedByMe;

  /// 값을 바꾼 복사본: 도움이 됐어요 토글 직후 화면 갱신용
  TalkPostDetail copyWith({
    bool? isHelpfulByMe,
    int? helpfulCount,
    String? note,
  }) => TalkPostDetail(
    id: id,
    authorNickname: authorNickname,
    isMine: isMine,
    title: title,
    category: category,
    stepCount: stepCount,
    note: note ?? this.note,
    helpfulCount: helpfulCount ?? this.helpfulCount,
    commentCount: commentCount,
    importCount: importCount,
    createdAt: createdAt,
    steps: steps,
    isHelpfulByMe: isHelpfulByMe ?? this.isHelpfulByMe,
    isImportedByMe: isImportedByMe,
  );

  /// id·제목·올린 시각이 깨졌으면 null
  static TalkPostDetail? fromJson(Map<String, dynamic> json) {
    final id = TalkJson.nonEmptyText(json['id']);
    final title = TalkJson.text(json['title']);
    final createdAt = TalkJson.time(json['createdAt']);
    if (id == null || title == null || createdAt == null) return null;
    return TalkPostDetail(
      id: id,
      authorNickname: TalkJson.text(json['authorNickname']),
      isMine: TalkJson.flag(json['isMine']),
      title: title,
      category: RoutineTemplateCategory.fromServer(
        TalkJson.text(json['category']),
      ),
      stepCount: TalkJson.count(json['stepCount']),
      note: TalkJson.text(json['note']),
      helpfulCount: TalkJson.count(json['helpfulCount']),
      commentCount: TalkJson.count(json['commentCount']),
      importCount: TalkJson.count(json['importCount']),
      createdAt: createdAt,
      steps: TalkJson.list(json['steps'], TalkStep.fromJson),
      isHelpfulByMe: TalkJson.flag(json['isHelpfulByMe']),
      isImportedByMe: TalkJson.flag(json['isImportedByMe']),
    );
  }
}

/// 피드 한 쪽. [nextCursor] 가 null 이면 마지막 쪽
@immutable
class TalkFeedPage {
  const TalkFeedPage({required this.items, this.nextCursor});

  final List<TalkPostSummary> items;
  final String? nextCursor;

  static TalkFeedPage fromJson(Map<String, dynamic> json) => TalkFeedPage(
    items: TalkJson.list(json['items'], TalkPostSummary.fromJson),
    nextCursor: TalkJson.text(json['nextCursor']),
  );
}

/// 일과관리로 가져온 결과 (서버 `TalkImportResponse`)
@immutable
class TalkImportResult {
  const TalkImportResult({required this.routineId, required this.profileId});

  /// 만들어진 일과관리 일과 id
  final String routineId;

  /// 일과가 들어간 이룸이 id
  final String profileId;

  static TalkImportResult? fromJson(Map<String, dynamic> json) {
    final routineId = TalkJson.nonEmptyText(json['routineId']);
    final profileId = TalkJson.nonEmptyText(json['profileId']);
    if (routineId == null || profileId == null) return null;
    return TalkImportResult(routineId: routineId, profileId: profileId);
  }
}
