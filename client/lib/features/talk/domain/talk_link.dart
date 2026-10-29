import 'package:flutter/foundation.dart';

import 'talk_json.dart';

/// 링크 만들기 결과 (서버 `TalkLinkResponse`): 링크 글 id, 이미 켜진 링크를 돌려받았는가
@immutable
class TalkLinkCreated {
  const TalkLinkCreated({required this.postId, required this.isReused});

  final String postId;

  /// true 면 이번에 고른 흐리게 선택은 쓰이지 않았다 (처음 보낼 때 모습 그대로)
  final bool isReused;

  /// 글 id 가 없으면 null
  static TalkLinkCreated? fromJson(Map<String, dynamic> json) {
    final postId = TalkJson.nonEmptyText(json['postId']);
    if (postId == null) return null;
    return TalkLinkCreated(
      postId: postId,
      isReused: TalkJson.flag(json['isReused']),
    );
  }
}
