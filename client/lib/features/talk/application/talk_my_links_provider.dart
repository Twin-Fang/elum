import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/talk_link_repository.dart';

/// 내 켜진 링크: 원본 일과 id > 링크 글 id (일과관리 메뉴의 `링크 끄기` 줄 판단)
final talkMyLinksProvider = FutureProvider.autoDispose<Map<String, String>>(
  (ref) => ref.watch(talkLinkRepositoryProvider).fetchMyLinks(),
);
