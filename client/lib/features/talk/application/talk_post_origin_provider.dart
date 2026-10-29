import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logger/app_logger.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/server_error_code.dart';
import '../data/talk_repository.dart';

/// 가져온 일과의 원래 글: 일과 상세 머리 안내가 쓴다
/// 글이 내려갔거나 받지 못했으면 [isPostAvailable] 이 false 이고 닉네임·한마디는 없다
@immutable
class TalkPostOrigin {
  const TalkPostOrigin({
    required this.isPostAvailable,
    this.authorNickname,
    this.note,
  });

  /// 원래 글 보기 링크를 보일 수 있는가
  final bool isPostAvailable;
  final String? authorNickname;
  final String? note;
}

/// 가져온 일과의 원래 글 (인자는 글 id). 실패해도 던지지 않아 일과 상세가 깨지지 않는다
final talkPostOriginProvider = FutureProvider.autoDispose
    .family<TalkPostOrigin, String>((ref, postId) async {
      try {
        final detail = await ref
            .watch(talkRepositoryProvider)
            .fetchDetail(postId);
        return TalkPostOrigin(
          isPostAvailable: true,
          authorNickname: detail.authorNickname,
          note: detail.note,
        );
      } catch (e, stack) {
        // 404(내려간 글)는 정상 경로, 그 밖의 실패만 기록
        final isPostGone =
            AppFailure.of(e).server?.code == ServerErrorCode.talkPostNotFound;
        if (!isPostGone) {
          AppLogger.error('talk', e, stack, {'step': 'fetchPostOrigin'});
        }
        return const TalkPostOrigin(isPostAvailable: false);
      }
    });
