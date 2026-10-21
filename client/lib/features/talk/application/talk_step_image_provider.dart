import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/talk_image_repository.dart';

/// 글 카드 한 장의 올린 그림 (없거나 실패면 null, 던지지 않음)
final talkStepImageProvider = FutureProvider.autoDispose
    .family<Uint8List?, ({String postId, int stepOrder})>(
      (ref, key) => ref
          .watch(talkImageRepositoryProvider)
          .fetch(key.postId, key.stepOrder),
    );
