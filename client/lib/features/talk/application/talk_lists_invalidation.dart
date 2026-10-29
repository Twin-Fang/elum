import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'talk_feed_controller.dart';
import 'talk_my_posts_controller.dart';
import 'talk_my_shared_posts_provider.dart';
import 'talk_popular_provider.dart';

/// 이야기 목록 전부 다시 받게 하기: 피드(분류별 전부), 인기 줄, 내가 쓴 글 목록, 내가 올린 글 맵
/// 올리기·내리기·숨기기·숨김 해제·가져오기 뒤에 이 함수 하나만 부른다
void invalidateTalkLists(Ref ref) {
  ref
    ..invalidate(talkFeedControllerProvider)
    ..invalidate(talkPopularProvider)
    ..invalidate(talkMyPostsControllerProvider)
    ..invalidate(talkMySharedPostsProvider);
}
