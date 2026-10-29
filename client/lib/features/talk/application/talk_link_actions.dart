import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/talk_link_repository.dart';
import '../data/talk_repository.dart';
import '../domain/talk_link.dart';
import 'talk_my_links_provider.dart';

/// 링크 만들기·끄기 > 내 켜진 링크 맵 다시 받기. 실패는 저장소가 던진 AppFailure 그대로
/// 끄기는 글 내리기와 같은 요청 (서버가 본문·그림 사본을 지운다)
class TalkLinkActions {
  TalkLinkActions(this._ref);

  final Ref _ref;

  Future<TalkLinkCreated> create({
    required String routineId,
    required List<String> blurredStepIds,
  }) async {
    final created = await _ref
        .read(talkLinkRepositoryProvider)
        .create(routineId: routineId, blurredStepIds: blurredStepIds);
    _ref.invalidate(talkMyLinksProvider);
    return created;
  }

  Future<void> turnOff(String postId) async {
    await _ref.read(talkRepositoryProvider).delete(postId);
    _ref.invalidate(talkMyLinksProvider);
  }
}

final talkLinkActionsProvider = Provider<TalkLinkActions>(TalkLinkActions.new);
