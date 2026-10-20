import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../guardian/application/routine_providers.dart';
import '../data/talk_repository.dart';
import '../domain/talk_post.dart';
import 'talk_detail_controller.dart';

final talkImportControllerProvider = Provider<TalkImportController>(
  (ref) => TalkImportController(ref),
);

/// 이야기 글을 일과관리로 가져오기: 서버 요청 > 일과 목록 다시 받기 > 열려 있는 상세의 "넣었어요" 표시
/// 실패는 [AppFailure] 로 던지고 안내는 화면이 한다
class TalkImportController {
  TalkImportController(this._ref);

  final Ref _ref;

  /// [groupId] 가 없으면 묶음 밖 맨 앞, 있으면 그 묶음의 맨 뒤에 들어간다
  Future<TalkImportResult> importToLibrary(
    String postId, {
    required String profileId,
    String? groupId,
  }) async {
    final result = await _ref
        .read(talkRepositoryProvider)
        .importToLibrary(postId, profileId: profileId, groupId: groupId);
    _ref.refreshRoutines();
    // 상세가 열려 있을 때만 (없는 상세를 새로 만들어 받지 않는다)
    final detailProvider = talkDetailControllerProvider(postId);
    if (_ref.exists(detailProvider)) {
      _ref.read(detailProvider.notifier).markImportedByMe();
    }
    return result;
  }
}
