import 'package:flutter/foundation.dart';

import 'talk_json.dart';

/// 댓글 1건 (서버 `TalkCommentResponse`)
@immutable
class TalkComment {
  const TalkComment({
    required this.id,
    required this.body,
    required this.isMine,
    required this.createdAt,
    this.authorNickname,
    this.isHidden = false,
  });

  final String id;

  /// 닉네임이 없는 계정은 null
  final String? authorNickname;
  final bool isMine;

  /// 가린 댓글은 빈 문자열
  final String body;
  final DateTime createdAt;

  /// 운영 정책으로 가려진 내 댓글 (서버는 쓴 사람 본인에게만 내려준다)
  final bool isHidden;

  /// id·내용·쓴 시각이 깨졌으면 null (그 댓글만 버린다)
  static TalkComment? fromJson(Map<String, dynamic> json) {
    final id = TalkJson.nonEmptyText(json['id']);
    final body = TalkJson.text(json['body']);
    final createdAt = TalkJson.time(json['createdAt']);
    if (id == null || body == null || createdAt == null) return null;
    return TalkComment(
      id: id,
      authorNickname: TalkJson.text(json['authorNickname']),
      isMine: TalkJson.flag(json['isMine']),
      body: body,
      createdAt: createdAt,
      isHidden: TalkJson.flag(json['isHidden']),
    );
  }
}

/// 댓글 한 쪽 (오래된 순). [nextCursor] 가 null 이면 마지막 쪽
@immutable
class TalkCommentPage {
  const TalkCommentPage({required this.items, this.nextCursor});

  final List<TalkComment> items;
  final String? nextCursor;

  static TalkCommentPage fromJson(Map<String, dynamic> json) => TalkCommentPage(
    items: TalkJson.list(json['items'], TalkComment.fromJson),
    nextCursor: TalkJson.text(json['nextCursor']),
  );
}
