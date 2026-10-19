import 'package:flutter/material.dart';

import '../../../../core/widgets/elum_state_body.dart';

/// 공지사항 탭 본문 (Task 4 가 공지 목록으로 채운다. 지금은 빈 자리만 둔다)
class NoticeHistoryTab extends StatelessWidget {
  const NoticeHistoryTab({super.key});

  @override
  Widget build(BuildContext context) {
    return const ElumStateBody(child: SizedBox.shrink());
  }
}
