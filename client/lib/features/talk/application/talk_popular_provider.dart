import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/talk_repository.dart';
import '../domain/talk_post.dart';

/// 이번 주 많이 가져간 글 (최대 10개): 인자는 분류 서버 값, 전체는 null
/// 실패해도 피드를 막지 않는다. 화면이 에러를 숨긴다
final talkPopularProvider = FutureProvider.autoDispose
    .family<List<TalkPostSummary>, String?>(
      (ref, category) =>
          ref.watch(talkRepositoryProvider).fetchPopular(category: category),
    );
