import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/talk_repository.dart';
import '../domain/talk_post.dart';
import '../domain/talk_report_reason.dart';
import 'talk_feed_controller.dart';
import 'talk_popular_provider.dart';

/// 글 상세: 인자는 글 id
final talkDetailControllerProvider = AsyncNotifierProvider.autoDispose
    .family<TalkDetailController, TalkPostDetail, String>(
      TalkDetailController.new,
    );

/// 이야기 글 상세: 불러오기, 도움돼요 토글(낙관적), 내리기, 고치기
/// 실패는 [AppFailure] 로 던지고 안내는 화면이 한다
class TalkDetailController extends AsyncNotifier<TalkPostDetail> {
  TalkDetailController(this.postId);

  final String postId;

  // 서버 신고 대상 종류
  static const _reportTargetPost = 'POST';

  /// 도움돼요 요청이 진행 중 (연타로 요청이 엇갈리지 않게)
  bool _isTogglingHelpful = false;

  TalkRepository get _repository => ref.read(talkRepositoryProvider);

  @override
  Future<TalkPostDetail> build() => _repository.fetchDetail(postId);

  /// 도움이 됐어요 켜기·끄기: 먼저 화면을 바꾸고, 실패하면 되돌린 뒤 던진다
  Future<void> toggleHelpful() async {
    final current = state.value;
    if (current == null || _isTogglingHelpful) return;
    _isTogglingHelpful = true;

    final willBeHelpful = !current.isHelpfulByMe;
    final countDelta = willBeHelpful ? 1 : -1;
    state = AsyncData(
      current.copyWith(
        isHelpfulByMe: willBeHelpful,
        helpfulCount: math.max(0, current.helpfulCount + countDelta),
      ),
    );
    try {
      if (willBeHelpful) {
        await _repository.markHelpful(postId);
      } else {
        await _repository.unmarkHelpful(postId);
      }
    } catch (_) {
      // 낙관적 갱신 되돌리기 (그 사이 다른 값이 바뀌었어도 두 값만 되돌림)
      if (ref.mounted) {
        final latest = state.value ?? current;
        state = AsyncData(
          latest.copyWith(
            isHelpfulByMe: current.isHelpfulByMe,
            helpfulCount: current.helpfulCount,
          ),
        );
      }
      rethrow;
    } finally {
      _isTogglingHelpful = false;
    }
  }

  /// 내 글 내리기 > 피드·인기 줄 다시 받기
  Future<void> delete() async {
    await _repository.delete(postId);
    _refreshLists();
  }

  /// 한마디·분류 고치기: 서버가 돌려준 글로 화면을 바꾼다 (note 가 빈 문자열이면 한마디 삭제)
  Future<void> updateNoteAndCategory({String? note, String? category}) async {
    final updated = await _repository.update(
      postId,
      note: note,
      category: category,
    );
    if (ref.mounted) state = AsyncData(updated);
    _refreshLists();
  }

  /// 이 글 신고 (중복 신고는 서버가 TALK_REPORT_DUPLICATED 로 거절)
  Future<void> report(TalkReportReason reason) => _repository.report(
    targetType: _reportTargetPost,
    targetId: postId,
    reason: reason.serverValue,
  );

  /// 글쓴이 숨기기 > 피드·인기 줄 다시 받기 (그 보호자 글이 사라진다)
  Future<void> blockAuthor() async {
    await _repository.block(postId: postId);
    _refreshLists();
  }

  /// 댓글 수 맞추기: 댓글을 달거나 지운 직후 (서버 재요청 없이)
  void adjustCommentCount(int delta) {
    final current = state.value;
    if (current == null) return;
    state = AsyncData(
      current.copyWith(commentCount: math.max(0, current.commentCount + delta)),
    );
  }

  /// 피드·인기 줄 목록 무효화 (분류별 전부)
  void _refreshLists() {
    ref.invalidate(talkFeedControllerProvider);
    ref.invalidate(talkPopularProvider);
  }
}
