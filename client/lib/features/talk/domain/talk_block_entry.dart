import 'package:flutter/foundation.dart';

import 'talk_json.dart';

/// 차단한 보호자 1명 (서버 `TalkBlockResponse`): 해제에 쓰는 blockId, 닉네임
@immutable
class TalkBlockEntry {
  const TalkBlockEntry({
    required this.blockId,
    required this.createdAt,
    this.nickname,
  });

  final String blockId;

  /// 닉네임이 없는 계정은 null
  final String? nickname;
  final DateTime createdAt;

  /// blockId·차단 시각이 깨졌으면 null
  static TalkBlockEntry? fromJson(Map<String, dynamic> json) {
    final blockId = TalkJson.nonEmptyText(json['blockId']);
    final createdAt = TalkJson.time(json['createdAt']);
    if (blockId == null || createdAt == null) return null;
    return TalkBlockEntry(
      blockId: blockId,
      nickname: TalkJson.text(json['nickname']),
      createdAt: createdAt,
    );
  }
}
