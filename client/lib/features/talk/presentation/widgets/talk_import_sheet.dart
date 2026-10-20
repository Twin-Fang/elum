import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/talk_post.dart';

/// "내 일과로": 글을 내 일과관리로 가져오는 시트 입구
/// 피드·상세가 이 함수만 부른다. 시트 본문은 아직 연결 전이라 지금은 아무것도 열지 않는다
Future<void> showTalkImportSheet(
  BuildContext context,
  WidgetRef ref,
  TalkPostSummary post,
) async {}
