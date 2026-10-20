import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../core/l10n/l10n_context.dart';
import '../../../../core/theme/theme_context_ext.dart';
import '../../domain/talk_text_limits.dart';

/// 한마디 입력칸 아래 캡션: 왼쪽 안내(이름·연락처 금지), 오른쪽 글자 수 카운터
/// 입력하면 placeholder 가 사라지므로 안내를 칸 안이 아닌 아래에 둔다
class TalkNoteCaption extends StatelessWidget {
  const TalkNoteCaption({super.key, required this.noteLength});

  final int noteLength;

  @override
  Widget build(BuildContext context) {
    final style = context.typo.caption.copyWith(
      color: context.colors.textSecondary,
    );
    return Padding(
      padding: EdgeInsets.only(top: context.space.xs.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(context.l10n.talkNoteGuide, style: style)),
          SizedBox(width: context.space.xs.w),
          Text('$noteLength/${TalkTextLimits.maxNoteLength}', style: style),
        ],
      ),
    );
  }
}
