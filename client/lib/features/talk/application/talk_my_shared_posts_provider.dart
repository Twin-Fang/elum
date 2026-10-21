import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/talk_repository.dart';

/// 내가 이야기에 올린 글: 원본 일과 id > 글 id (일과관리 목록의 올림 표시·올리기 목록 제외용)
final talkMySharedPostsProvider =
    FutureProvider.autoDispose<Map<String, String>>(
      (ref) => ref.watch(talkRepositoryProvider).fetchMySharedPosts(),
    );
